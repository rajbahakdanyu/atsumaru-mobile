import SwiftUI
import Core

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

    init(mangaId: String, mangaRepository: any MangaRepository, downloadManager: DownloadManager) {
        self.mangaId = mangaId
        self.mangaRepository = mangaRepository
        self.downloadManager = downloadManager
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            manga = try await mangaRepository.page(id: mangaId)
            loadFailed = false
            isOfflineFallback = false
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
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
