import SwiftUI
import Core

@Observable @MainActor
final class DownloadsViewModel {
    struct DownloadRow: Identifiable {
        let chapterId: String
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

    var rows: [DownloadRow] = []
    var storageBytes: Int64 = 0
    var storageText: String? {
        guard storageBytes > 0 else { return nil }
        return "\(ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file)) used"
    }

    private let downloadManager: DownloadManager
    private let backgroundScheduler: BackgroundScheduler
    private var eventTask: Task<Void, Never>?
    private var loaded = false

    init(downloadManager: DownloadManager, backgroundScheduler: BackgroundScheduler) {
        self.downloadManager = downloadManager
        self.backgroundScheduler = backgroundScheduler
    }

    func load() async {
        if loaded { return }
        loaded = true
        await refresh()
        startEventStream()
    }

    func refresh() async {
        let snapshots = await downloadManager.listChapters()
        var updated: [DownloadRow] = []
        for record in snapshots {
            let live = await downloadManager.state(for: record.chapterId)
            let effective = Self.effectiveState(live: live, persisted: record.state)
            updated.append(DownloadRow(
                chapterId: record.chapterId,
                mangaTitle: record.mangaTitle,
                chapterTitle: record.chapterTitle,
                kind: record.kind,
                state: effective,
                pageCount: record.pageCount,
                totalBytes: record.totalBytes
            ))
        }
        rows = updated
        storageBytes = await downloadManager.storageUsed()
    }

    func delete(_ chapterId: String) async {
        await downloadManager.deleteChapter(chapterId)
        await refresh()
    }

    func deleteAll() async {
        await downloadManager.deleteAll()
        await refresh()
    }

    private static func effectiveState(live: DownloadState, persisted: String) -> DownloadState {
        switch live {
        case .queued: return persisted == "completed" ? .completed : .queued
        case .downloading(let fraction): return .downloading(fraction)
        case .completed: return .completed
        case .failed(let message): return .failed(message)
        }
    }

    private func startEventStream() {
        eventTask?.cancel()
        eventTask = Task { [weak self, downloadManager] in
            let stream = await downloadManager.events()
            for await event in stream {
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
            storageBytes = await downloadManager.storageUsed()
            await refreshSizes(for: chapterId)
            updateRow(chapterId: chapterId) { row in
                row.state = .completed
            }
            if !rows.contains(where: { $0.chapterId == chapterId }) {
                await refresh()
            }
        case .failed(let chapterId, let message):
            updateRow(chapterId: chapterId) { row in
                row.state = .failed(message)
            }
            if !rows.contains(where: { $0.chapterId == chapterId }) {
                await refresh()
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
            Task { await refresh() }
            return
        }
        updater(&rows[index])
    }
}