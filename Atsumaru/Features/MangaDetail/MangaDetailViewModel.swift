import SwiftUI
import Core
import os

@Observable @MainActor
final class MangaDetailViewModel {
    var manga: MangaPage?
    var isLoading = false
    var loadFailed = false
    /// True when the network page failed but downloaded chapters exist, so a
    /// minimal offline detail (title + downloaded chapters) is shown instead.
    var isOfflineFallback = false

    private let mangaId: String
    private let mangaRepository: any MangaRepository
    private let downloadManager: DownloadManager
    private let progressStore: ProgressStore?

    init(mangaId: String, mangaRepository: any MangaRepository, downloadManager: DownloadManager, progressStore: ProgressStore?) {
        self.mangaId = mangaId
        self.mangaRepository = mangaRepository
        self.downloadManager = downloadManager
        self.progressStore = progressStore
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            manga = try await mangaRepository.page(id: mangaId)
            loadFailed = false
            isOfflineFallback = false
            // A stale server response must not revert the instant local
            // refresh (feedback #5): re-apply local progress on top.
            refreshLocalProgress()
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            Logger(subsystem: "dev.atsumaru.app", category: "detail").error("detail load \(self.mangaId, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            // Offline fallback: downloaded chapters remain readable without
            // the network page.
            if let fallback = await Self.offlineFallback(
                mangaId: mangaId, downloadManager: downloadManager
            ) {
                manga = fallback
                loadFailed = false
                isOfflineFallback = true
            } else {
                loadFailed = true
            }
        }
    }

    /// Applies locally-saved reading progress to the chapter list immediately —
    /// called on return from the reader so finished chapters grey out without
    /// waiting for a network refresh. Local progress wins only when it is newer
    /// than (or absent from) the server state.
    func refreshLocalProgress() {
        guard let current = manga else { return }
        let nowChapters = current.chapters.map { chapter -> Chapter in
            guard let local = progressStore?.progress(mangaId: mangaId, chapterId: chapter.id) else {
                return chapter
            }
            let pages = max(chapter.pageCount, local.pageIndex + 1)
            guard pages > 0 else { return chapter }
            let frac = min(max(Double(local.pageIndex + 1) / Double(pages), 0), 1)
            let localTs = Int(local.updatedAt.timeIntervalSince1970 * 1000)
            let localProgress = ChapterProgress(
                mangaId: mangaId,
                page: local.pageIndex,
                pages: pages,
                ts: localTs,
                strip: nil,
                frac: frac
            )
            let serverTs = chapter.progress?.ts ?? 0
            guard chapter.progress == nil || serverTs <= localTs else { return chapter }
            return Chapter(
                id: chapter.id, title: chapter.title, number: chapter.number,
                index: chapter.index, pageCount: chapter.pageCount,
                scanlationMangaId: chapter.scanlationMangaId,
                createdAt: chapter.createdAt, progress: localProgress
            )
        }
        manga = MangaPage(
            id: current.id, title: current.title, type: current.type, medium: current.medium,
            status: current.status, synopsis: current.synopsis, avgRating: current.avgRating,
            poster: current.poster, banner: current.banner, genres: current.genres,
            tags: current.tags, authors: current.authors, scanlators: current.scanlators,
            chapters: nowChapters, recommendations: current.recommendations,
            relations: current.relations, startReading: current.startReading
        )
    }

    private static func offlineFallback(
        mangaId: String, downloadManager: DownloadManager
    ) async -> MangaPage? {
        let records = await downloadManager.listChapters().filter { $0.mangaId == mangaId }
        guard !records.isEmpty else { return nil }
        let chapters = records.map { record in
            Chapter(
                id: record.chapterId,
                title: record.chapterTitle,
                pageCount: record.pageCount
            )
        }
        return MangaPage(
            id: mangaId,
            title: records.first?.mangaTitle ?? "",
            medium: records.first?.kind == "novel" ? "Novel" : "Comic",
            chapters: chapters
        )
    }
}
