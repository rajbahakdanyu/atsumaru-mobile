import SwiftUI
import Core

@Observable
@MainActor
final class NovelReaderViewModel {
    let mangaId: String
    let chapter: Chapter
    private let novelRepository: any NovelRepository
    private let readRepository: any ReadRepository
    private let progressStore: ProgressStore?
    private let downloadManager: DownloadManager

    var novel: NovelChapter?
    var isLoading = false
    var loadFailed = false
    var currentParagraph: Int = 0

    private var saveTask: Task<Void, Never>?

    init(mangaId: String,
         chapter: Chapter,
         novelRepository: any NovelRepository,
         readRepository: any ReadRepository,
         progressStore: ProgressStore?,
         downloadManager: DownloadManager) {
        self.mangaId = mangaId
        self.chapter = chapter
        self.novelRepository = novelRepository
        self.readRepository = readRepository
        self.progressStore = progressStore
        self.downloadManager = downloadManager
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        // Offline first: a completed download is read entirely from disk —
        // the network fetch is skipped, so no network is required.
        let local = await downloadManager.localContent(for: chapter.id)
        if case .novelParagraphs(let paragraphs)? = local {
            loadLocalParagraphs(paragraphs)
            return
        }
        do {
            let fetched = try await novelRepository.novelChapter(mangaId: mangaId, chapterId: chapter.id)
            novel = fetched
            if let local = progressStore?.progress(mangaId: mangaId, chapterId: chapter.id),
               fetched.paragraphs.indices.contains(local.pageIndex) {
                currentParagraph = local.pageIndex
            } else {
                currentParagraph = 0
            }
            loadFailed = false
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            loadFailed = true
        }
    }

    private func loadLocalParagraphs(_ paragraphs: [String]) {
        novel = NovelChapter(
            id: chapter.id,
            title: chapter.title,
            number: Int(chapter.number),
            scanlationMangaId: chapter.scanlationMangaId ?? "",
            paragraphs: paragraphs,
            wordCount: paragraphs.reduce(0) { $0 + $1.split(separator: " ").count },
            paragraphComments: nil
        )
        if let local = progressStore?.progress(mangaId: mangaId, chapterId: chapter.id),
           paragraphs.indices.contains(local.pageIndex) {
            currentParagraph = local.pageIndex
        } else {
            currentParagraph = 0
        }
        loadFailed = false
    }

    func scheduleProgressSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            if Task.isCancelled { return }
            await self?.saveProgress()
        }
    }

    func saveProgressNow() {
        saveTask?.cancel()
        saveTask = nil
        Task { await self.saveProgress() }
    }

    @MainActor
    func saveProgress() async {
        guard let novel, !novel.paragraphs.isEmpty else { return }
        let index = max(0, min(currentParagraph, novel.paragraphs.count - 1))
        let frac = Double(index + 1) / Double(novel.paragraphs.count)
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let update = ProgressUpdate(
            mangaScanlationId: novel.scanlationMangaId,
            mangaId: mangaId,
            chapterId: novel.id,
            page: index,
            frac: frac,
            pages: novel.paragraphs.count,
            ts: ts,
            strip: false,
            nextChapterId: nil,
            readMs: 0
        )
        try? progressStore?.save(ProgressState(mangaId: mangaId, chapterId: novel.id, pageIndex: index, updatedAt: Date()))
        try? await readRepository.updateProgress(update)
    }
}
