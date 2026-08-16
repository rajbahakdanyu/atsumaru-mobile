import SwiftUI
import Core

@Observable
@MainActor
final class ReaderViewModel {
    let mangaId: String
    let chapter: Chapter
    private let readRepository: any ReadRepository
    private let progressStore: ProgressStore?

    var readChapter: ReadChapter?
    var mode: ReaderMode = .paged
    var currentPage: Int = 0
    var isLoading = false
    var loadFailed = false

    private var saveTask: Task<Void, Never>?

    init(mangaId: String, chapter: Chapter, readRepository: any ReadRepository, progressStore: ProgressStore?) {
        self.mangaId = mangaId
        self.chapter = chapter
        self.readRepository = readRepository
        self.progressStore = progressStore
    }

    var pageCount: Int { readChapter?.pages.count ?? 0 }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await readRepository.chapter(mangaId: mangaId, chapterId: chapter.id)
            readChapter = fetched
            if let local = progressStore?.progress(mangaId: mangaId, chapterId: chapter.id),
               fetched.pages.indices.contains(local.pageIndex) {
                currentPage = local.pageIndex
            } else {
                currentPage = 0
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
        guard let readChapter, pageCount > 0 else { return }
        let page = max(0, min(currentPage, pageCount - 1))
        let frac = Double(page + 1) / Double(pageCount)
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let update = ProgressUpdate(
            mangaScanlationId: readChapter.scanlationMangaId,
            mangaId: mangaId,
            chapterId: readChapter.id,
            page: page,
            frac: frac,
            pages: pageCount,
            ts: ts,
            strip: mode == .strip,
            nextChapterId: nil,
            readMs: 0
        )
        try? await readRepository.updateProgress(update)
        try? progressStore?.save(ProgressState(mangaId: mangaId, chapterId: readChapter.id, pageIndex: page, updatedAt: Date()))
    }
}