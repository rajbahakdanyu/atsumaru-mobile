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

    var novel: NovelChapter?
    var isLoading = false
    var loadFailed = false
    var currentParagraph: Int = 0

    private var saveTask: Task<Void, Never>?

    init(mangaId: String,
         chapter: Chapter,
         novelRepository: any NovelRepository,
         readRepository: any ReadRepository,
         progressStore: ProgressStore?) {
        self.mangaId = mangaId
        self.chapter = chapter
        self.novelRepository = novelRepository
        self.readRepository = readRepository
        self.progressStore = progressStore
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
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
        } catch {
            loadFailed = true
        }
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
