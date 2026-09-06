import Foundation
import BackgroundTasks
import UserNotifications
import os

/// Wraps a non-Sendable reference so it can cross an isolation boundary.
/// `BGTask` instances are safe to call `setTaskCompleted(success:)` on from
/// any queue per Apple's BackgroundTasks sample code; we mark unchecked to
/// satisfy Swift 6 strict concurrency without an actual race.
private struct UnsafeSendableBox<T>: @unchecked Sendable {
    var value: T
}

/// Thread-safe mutable slot so the expiration handler can cancel the work
/// task that is started after the handler is installed.
private final class ExpirableWork: @unchecked Sendable {
    private let lock = NSLock()
    private var work: Task<Bool, Never>?
    func set(_ work: Task<Bool, Never>) {
        lock.lock()
        self.work = work
        lock.unlock()
    }
    func cancel() {
        lock.lock()
        work?.cancel()
        lock.unlock()
    }
}

public final class BackgroundScheduler: Sendable {
    private static let log = Logger(subsystem: "dev.atsumaru.app", category: "background")

    public static let refreshIdentifier = "dev.atsumaru.app.refresh"
    public static let backgroundRefreshKey = "dev.atsumaru.app.backgroundRefresh"
    public static let notificationsKey = "dev.atsumaru.app.newChapterNotifications"

    /// Defaults to enabled when the preference key has never been written.
    private static var refreshEnabled: Bool {
        UserDefaults.standard.object(forKey: backgroundRefreshKey) == nil
            || UserDefaults.standard.bool(forKey: backgroundRefreshKey)
    }

    /// Defaults to enabled when the preference key has never been written.
    private static var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: notificationsKey) == nil
            || UserDefaults.standard.bool(forKey: notificationsKey)
    }

    private let downloadManager: DownloadManager
    private let libraryRepository: any LibraryRepository
    private let mangaRepository: any MangaRepository

    public init(downloadManager: DownloadManager,
                libraryRepository: any LibraryRepository,
                mangaRepository: any MangaRepository) {
        self.downloadManager = downloadManager
        self.libraryRepository = libraryRepository
        self.mangaRepository = mangaRepository
    }

    @discardableResult
    public func registerTasks() -> Bool {
        let refreshOK = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self,
                  let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let box = UnsafeSendableBox(value: refreshTask)
            Task { await self.handleRefresh(task: box.value) }
        }
        return refreshOK
    }

    public func scheduleRefresh() {
        guard Self.refreshEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // best-effort: device may not allow background scheduling right now.
        }
    }

    public func cancelRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
    }

    public func requestNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func handleRefresh(task: BGAppRefreshTask) async {
        // The expiration handler must be installed BEFORE any work starts so
        // an early expiration is never missed (Apple's required pattern).
        let expirable = ExpirableWork()
        task.expirationHandler = {
            Self.log.notice("Background refresh expired")
            expirable.cancel()
        }
        let work = Task { await self.refreshAndDownload() }
        expirable.set(work)
        let success = await work.value
        task.setTaskCompleted(success: success)
        // Reschedule regardless of success so one failure doesn't kill the
        // background cycle; scheduleRefresh() no-ops when the pref is off.
        self.scheduleRefresh()
    }

    @discardableResult
    public func refreshAndDownload() async -> Bool {
        Self.log.info("Background refresh started")
        let bookmarks: [Bookmark]
        do {
            bookmarks = try await libraryRepository.bookmarks(offset: 0, limit: 40)
        } catch {
            Self.log.error("Background refresh could not fetch bookmarks: \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard !bookmarks.isEmpty else {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
            return true
        }
        let snapshots = await downloadManager.listChapters()
        // Only completed records block a re-download; a failed record must be
        // retried instead of being skipped forever.
        let downloadedIds = Set(snapshots.filter { $0.state == "completed" }.map { $0.chapterId })

        var newChaptersEnqueued = 0
        var chapterTitles: [String] = []
        var enqueuedIds: [String] = []
        // Glance through at most 10 bookmarks per refresh to keep the task short.
        for bookmark in bookmarks.prefix(10) where !bookmark.id.isEmpty {
            if Task.isCancelled { return false }
            guard let page = try? await mangaRepository.page(id: bookmark.id) else { continue }
            let home = Self.homeItem(from: bookmark)
            for chapter in page.chapters where !downloadedIds.contains(chapter.id) {
                guard newChaptersEnqueued < 5 else { break }
                await downloadManager.enqueue(manga: home, chapter: chapter)
                enqueuedIds.append(chapter.id)
                newChaptersEnqueued += 1
                chapterTitles.append(chapter.title)
            }
            if newChaptersEnqueued >= 5 { break }
        }
        if Task.isCancelled {
            Self.log.notice("Background refresh cancelled before completion")
            return false
        }
        await downloadManager.awaitCompletion(enqueuedIds)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
        Self.log.info("Background refresh done (\(newChaptersEnqueued, privacy: .public) new chapter(s))")
        if newChaptersEnqueued > 0 && Self.notificationsEnabled {
            let title = newChaptersEnqueued == 1 ? "New chapter downloaded" : "New chapters available"
            let body = chapterTitles.first ?? "\(newChaptersEnqueued) new chapter(s) are now available offline."
            await postNotification(title: title, body: body)
        }
        return true
    }

    public func postNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "atsumaru.refresh.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    public static func lastRefreshDate() -> Date? {
        let ts = UserDefaults.standard.object(forKey: Self.lastRefreshKey) as? Double
        return ts.map { Date(timeIntervalSince1970: $0) }
    }

    private static let lastRefreshKey = "dev.atsumaru.app.lastRefresh"

    private static func homeItem(from bookmark: Bookmark) -> HomeItem {
        HomeItem(id: bookmark.id, title: bookmark.title, image: bookmark.image ?? "",
                 medium: bookmark.medium ?? "Comic")
    }
}