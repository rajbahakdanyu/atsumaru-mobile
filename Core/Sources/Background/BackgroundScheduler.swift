import Foundation
import BackgroundTasks
import UserNotifications

/// Wraps a non-Sendable reference so it can cross an isolation boundary.
/// `BGTask` instances are safe to call `setTaskCompleted(success:)` on from
/// any queue per Apple's BackgroundTasks sample code; we mark unchecked to
/// satisfy Swift 6 strict concurrency without an actual race.
private struct UnsafeSendableBox<T>: @unchecked Sendable {
    let value: T
}

public final class BackgroundScheduler: Sendable {
    public static let refreshIdentifier = "dev.atsumaru.app.refresh"
    public static let processingIdentifier = "dev.atsumaru.app.processing"

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
        let processingOK = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self,
                  let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let box = UnsafeSendableBox(value: processingTask)
            Task { await self.handleProcessing(task: box.value) }
        }
        return refreshOK && processingOK
    }

    public func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // best-effort: device may not allow background scheduling right now.
        }
    }

    public func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.processingIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // best-effort.
        }
    }

    public func requestNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func handleRefresh(task: BGAppRefreshTask) async {
        let work = Task { await self.refreshAndDownload() }
        task.expirationHandler = { work.cancel() }
        let success = await work.value
        task.setTaskCompleted(success: success)
        if success {
            self.scheduleRefresh()
        }
    }

    public func handleProcessing(task: BGProcessingTask) async {
        let work = Task { await self.refreshAndDownload() }
        task.expirationHandler = { work.cancel() }
        let success = await work.value
        task.setTaskCompleted(success: success)
    }

    @discardableResult
    public func refreshAndDownload() async -> Bool {
        let bookmarks: [Bookmark]
        do {
            bookmarks = try await libraryRepository.bookmarks(offset: 0, limit: 40)
        } catch {
            return false
        }
        guard !bookmarks.isEmpty else {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
            return true
        }
        let snapshots = await downloadManager.listChapters()
        let downloadedIds = Set(snapshots.map { $0.chapterId })

        var newChaptersEnqueued = 0
        var chapterTitles: [String] = []
        for bookmark in bookmarks where !bookmark.id.isEmpty {
            guard let page = try? await mangaRepository.page(id: bookmark.id) else { continue }
            let home = Self.homeItem(from: bookmark)
            for chapter in page.chapters where !downloadedIds.contains(chapter.id) {
                guard newChaptersEnqueued < 5 else { break }
                await downloadManager.enqueue(manga: home, chapter: chapter)
                newChaptersEnqueued += 1
                chapterTitles.append(chapter.title)
            }
            if newChaptersEnqueued >= 5 { break }
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
        if newChaptersEnqueued > 0 {
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
                 smallImage: bookmark.smallImage ?? "", mediumImage: bookmark.mediumImage ?? "",
                 largeImage: bookmark.largeImage ?? "", isAdult: bookmark.isAdult ?? false,
                 type: bookmark.type ?? "Manga", medium_: bookmark.medium ?? "Comic",
                 mbRating: 0.0, views: nil, createdAt: nil, updatedAt: nil)
    }
}