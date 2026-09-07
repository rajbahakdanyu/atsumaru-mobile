import SwiftUI
import Core
import os

private let logger = Logger(subsystem: "dev.atsumaru.app", category: "downloads")

@Observable @MainActor
final class DownloadsViewModel {
    struct DownloadRow: Identifiable {
        let chapterId: String
        let mangaId: String
        let mangaTitle: String
        let chapterTitle: String
        let kind: String
        var state: DownloadState
        let pageCount: Int
        var totalBytes: Int64
        var id: String { chapterId }
        var statusText: String {
            switch state {
            case .queued: "Queued"
            case .downloading(let fraction): "Downloading \(Int(fraction * 100))%"
            case .completed: "Ready offline"
            case .failed(let message): "Failed — \(message)"
            }
        }
        var sizeText: String? {
            guard totalBytes > 0 else { return nil }
            return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
    }

    /// The Downloads tab shows one card per SERIES (like the Library tab);
    /// expanding a card reveals its downloaded chapters.
    struct DownloadSection: Identifiable {
        let mangaId: String
        let title: String
        let kind: String
        var chapters: [DownloadRow]
        var id: String { mangaId }
        var totalBytes: Int64 { chapters.reduce(0) { $0 + $1.totalBytes } }
        var chapterCount: Int { chapters.count }
        var inFlightFraction: Double? {
            let inFlight = chapters.filter {
                if case .downloading = $0.state { return true }
                if case .queued = $0.state { return true }
                return false
            }
            guard !inFlight.isEmpty else { return nil }
            let fractions = inFlight.map { row -> Double in
                if case .downloading(let fraction) = row.state { return fraction }
                return 0
            }
            return fractions.reduce(0, +) / Double(inFlight.count)
        }
        var sizeText: String? {
            guard totalBytes > 0 else { return nil }
            return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }
        var failedCount: Int { chapters.filter { $0.state.isFailed }.count }
    }

    var rows: [DownloadRow] = []
    var sections: [DownloadSection] = []

    private let downloadManager: DownloadManager
    private let backgroundScheduler: BackgroundScheduler
    private let mangaRepository: any MangaRepository
    private var eventTask: Task<Void, Never>?
    private var loaded = false
    private var isRefreshing = false
    private var hasPendingRefresh = false

    init(
        downloadManager: DownloadManager, backgroundScheduler: BackgroundScheduler,
        mangaRepository: any MangaRepository
    ) {
        self.downloadManager = downloadManager
        self.backgroundScheduler = backgroundScheduler
        self.mangaRepository = mangaRepository
    }

    func load() async {
        if loaded {
            startEventStream()
            scheduleCoalescedRefresh()
            return
        }
        loaded = true
        await refresh()
        startEventStream()
    }

    func stopEventStream() {
        eventTask?.cancel()
        eventTask = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            // A coalesced refresh that bounced off the guard above stays
            // pending; pick it up now that this refresh is done.
            // flushPendingRefresh clears the flag before refreshing, so this
            // cannot loop.
            if hasPendingRefresh {
                Task { [weak self] in await self?.flushPendingRefresh() }
            }
        }
        let snapshots = await downloadManager.listChapters()
        var updated: [DownloadRow] = []
        for record in snapshots {
            let live = await downloadManager.state(for: record.chapterId)
            let effective = DownloadState.effective(live: live, persisted: record.state)
            updated.append(DownloadRow(
                chapterId: record.chapterId,
                mangaId: record.mangaId,
                mangaTitle: record.mangaTitle,
                chapterTitle: record.chapterTitle,
                kind: record.kind,
                state: effective,
                pageCount: record.pageCount,
                totalBytes: record.totalBytes
            ))
        }
        rows = updated
        rebuildSections(from: updated)
    }

    func delete(mangaId: String) async {
        let chapterIds = rows.filter { $0.mangaId == mangaId }.map(\.chapterId)
        for chapterId in chapterIds {
            await downloadManager.deleteChapter(chapterId)
        }
        await refresh()
    }

    func posterPath(for mangaId: String) -> String? {
        UserDefaults.standard.string(forKey: "downloads.poster.\(mangaId)")
    }

    /// Fetches covers for downloads that have no cached poster path (older
    /// downloads predate the enqueue-time cache) and persists them.
    func hydratePosters() async {
        var fetched = false
        for section in sections where (posterPath(for: section.mangaId) ?? "").isEmpty {
            do {
                let page = try await mangaRepository.page(id: section.mangaId)
                if let path = page.poster?.image, !path.isEmpty {
                    UserDefaults.standard.set(path, forKey: "downloads.poster.\(section.mangaId)")
                    fetched = true
                }
            } catch {
                logger.error("poster hydrate failed for \(section.mangaId, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        if fetched { await refresh() }
    }

    /// Groups rows into per-series sections; chapters sort by the number
    /// parsed from the chapter title ("Chapter 112.7" → 112.7), falling back
    /// to insertion order when no number is present.
    private func rebuildSections(from updated: [DownloadRow]) {
        var order: [String] = []
        var grouped: [String: [DownloadRow]] = [:]
        for row in updated {
            if grouped[row.mangaId] == nil { order.append(row.mangaId) }
            grouped[row.mangaId, default: []].append(row)
        }
        sections = order.map { mangaId in
            let chapters = grouped[mangaId]!
            let sorted = chapters.enumerated().sorted { lhs, rhs in
                switch (Self.chapterNumber(lhs.element.chapterTitle), Self.chapterNumber(rhs.element.chapterTitle)) {
                case let (l?, r?) where l != r: return l < r
                default: return lhs.offset < rhs.offset
                }
            }.map(\.element)
            return DownloadSection(
                mangaId: mangaId,
                title: sorted.first?.mangaTitle ?? "",
                kind: sorted.first?.kind ?? "manga",
                chapters: sorted
            )
        }
    }

    private static func chapterNumber(_ title: String) -> Double? {
        guard let match = title.firstMatch(of: /([0-9]+(?:\.[0-9]+)?)/) else { return nil }
        return Double(match.1)
    }

    func deleteAll() async {
        await downloadManager.deleteAll()
        await refresh()
    }

    private func startEventStream() {
        eventTask?.cancel()
        eventTask = Task { [weak self, downloadManager] in
            let stream = await downloadManager.events()
            for await event in stream {
                guard !Task.isCancelled else { break }
                await self?.handle(event: event)
            }
        }
    }

    private func handle(event: DownloadEvent) async {
        switch event {
        case .progress(let chapterId, let fraction):
            updateRow(chapterId: chapterId) { row in
                row.state = .downloading(fraction)
            }
        case .completed(let chapterId):
            await refreshSizes(for: chapterId)
            updateRow(chapterId: chapterId) { row in
                row.state = .completed
            }
        case .failed(let chapterId, let message):
            updateRow(chapterId: chapterId) { row in
                row.state = .failed(message)
            }
        }
    }

    private func refreshSizes(for chapterId: String) async {
        let snapshot = await downloadManager.listChapters()
        if let record = snapshot.first(where: { $0.chapterId == chapterId }) {
            updateRow(chapterId: chapterId) { row in
                row.totalBytes = record.totalBytes
            }
        }
    }

    private func updateRow(chapterId: String, _ updater: (inout DownloadRow) -> Void) {
        guard let index = rows.firstIndex(where: { $0.chapterId == chapterId }) else {
            // Row not loaded yet (e.g. a fresh enqueue); coalesce a refresh.
            scheduleCoalescedRefresh()
            return
        }
        updater(&rows[index])
    }

    private func scheduleCoalescedRefresh() {
        guard !hasPendingRefresh else { return }
        hasPendingRefresh = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            await self?.flushPendingRefresh()
        }
    }

    private func flushPendingRefresh() async {
        guard hasPendingRefresh else { return }
        if isRefreshing {
            // refresh() would bounce and drop the event; leave the flag set
            // and let the in-flight refresh's completion path flush it.
            return
        }
        hasPendingRefresh = false
        await refresh()
    }
}
