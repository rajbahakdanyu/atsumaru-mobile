import Foundation
import Testing
@testable import Core
@testable import Atsumaru

@Suite
@MainActor
struct ReaderAndDownloadsViewModelTests {
    @Test func progressDebouncerKeepsLatestOperationAndCancelsPendingWork() async throws {
        let count = Box(0)
        let debouncer = ProgressSaveDebouncer(delay: .milliseconds(20))

        debouncer.schedule { count.value += 1 }
        debouncer.schedule { count.value += 1 }
        try await Task.sleep(for: .milliseconds(60))
        #expect(count.value == 1)

        debouncer.schedule { count.value += 1 }
        debouncer.cancel()
        try await Task.sleep(for: .milliseconds(60))
        #expect(count.value == 1)
    }

    @Test func readerLoadsNextChapterInReadingOrderAndClampsProgress() async {
        let updates = Box<[ProgressUpdate]>([])
        let first = Chapter(
            id: "c1", title: "Chapter 1", number: 1, index: 1,
            pageCount: 2, scanlationMangaId: "scan"
        )
        let second = Chapter(
            id: "c2", title: "Chapter 2", number: 2, index: 2,
            pageCount: 2, scanlationMangaId: "scan"
        )
        let readRepository = ReadRepositoryStub(
            chapter: { _, chapterId in
                ReadChapter(
                    id: chapterId, title: "Chapter", scanlationMangaId: "scan",
                    pages: [
                        PageImage(id: "p0", image: "/0.webp", number: 0, width: 100, height: 200, aspectRatio: 0.5),
                        PageImage(id: "p1", image: "/1.webp", number: 1, width: 100, height: 200, aspectRatio: 0.5),
                    ]
                )
            },
            update: { updates.value.append($0) }
        )
        let mangaRepository = MangaRepositoryStub { _ in
            MangaPage(id: "m1", title: "Manga", chapters: [second, first])
        }
        let downloadManager = DownloadManager(readRepository: readRepository)
        let viewModel = ReaderViewModel(
            mangaId: "m1", chapter: first, readRepository: readRepository,
            progressStore: nil, downloadManager: downloadManager,
            mangaRepository: mangaRepository
        )

        await viewModel.load()
        #expect(viewModel.readChapter?.id == "c1")
        #expect(viewModel.nextChapter?.id == "c2")

        viewModel.currentPage = 99
        await viewModel.saveProgress()
        #expect(updates.value.last?.page == 1)
        #expect(updates.value.last?.completed == true)
    }

    @Test func novelReaderLoadsAndSavesFinalParagraph() async {
        let updates = Box<[ProgressUpdate]>([])
        let readRepository = ReadRepositoryStub(
            chapter: { _, _ in throw TestFailure() },
            update: { updates.value.append($0) }
        )
        let novelRepository = NovelRepositoryStub { _, chapterId in
            NovelChapter(
                id: chapterId, title: "Novel", number: 1,
                scanlationMangaId: "scan", paragraphs: ["One", "Two"],
                wordCount: 2, paragraphComments: nil
            )
        }
        let chapter = Chapter(id: "n1", title: "Novel", number: 1, scanlationMangaId: "scan")
        let downloadManager = DownloadManager(readRepository: readRepository, novelRepository: novelRepository)
        let viewModel = NovelReaderViewModel(
            mangaId: "m1", chapter: chapter, novelRepository: novelRepository,
            readRepository: readRepository, progressStore: nil,
            downloadManager: downloadManager
        )

        await viewModel.load()
        viewModel.currentParagraph = 99
        await viewModel.saveProgress()

        #expect(viewModel.novel?.paragraphs == ["One", "Two"])
        #expect(updates.value.last?.page == 1)
        #expect(updates.value.last?.completed == true)
    }

    @Test func mangaDetailPrefersNewerLocalProgress() async throws {
        let progressStore = try await ProgressStore.makeInMemory()
        let localDate = Date(timeIntervalSince1970: 200)
        try progressStore.save(ProgressState(
            mangaId: "m1", chapterId: "c1", pageIndex: 7, updatedAt: localDate
        ))
        let chapter = Chapter(
            id: "c1", title: "Chapter", number: 1, pageCount: 10,
            progress: ChapterProgress(page: 1, pages: 10, ts: 100_000, frac: 0.1)
        )
        let page = MangaPage(id: "m1", title: "Manga", chapters: [chapter])
        let readRepository = ReadRepositoryStub { _, _ in throw TestFailure() }
        let downloadManager = DownloadManager(readRepository: readRepository)
        let viewModel = MangaDetailViewModel(
            mangaId: "m1", mangaRepository: MangaRepositoryStub { _ in page },
            downloadManager: downloadManager, progressStore: progressStore
        )
        viewModel.manga = page

        viewModel.refreshLocalProgress()

        #expect(viewModel.manga?.chapters.first?.progress?.page == 7)
        #expect(viewModel.manga?.chapters.first?.progress?.frac == 0.8)
    }

    @Test func downloadsRefreshGroupsAndSortsChapters() async throws {
        let store = try await DownloadStore.makeInMemory()
        try store.save(DownloadedChapterSnapshot(
            chapterId: "c10", mangaId: "m1", mangaTitle: "Manga", chapterTitle: "Chapter 10",
            kind: "manga", pageCount: 1, totalBytes: 20, completedAt: Date(), state: "completed"
        ))
        try store.save(DownloadedChapterSnapshot(
            chapterId: "c2", mangaId: "m1", mangaTitle: "Manga", chapterTitle: "Chapter 2",
            kind: "manga", pageCount: 1, totalBytes: 10, completedAt: Date(), state: "completed"
        ))
        let readRepository = ReadRepositoryStub { _, _ in throw TestFailure() }
        let manager = DownloadManager(readRepository: readRepository, store: store)
        let mangaRepository = MangaRepositoryStub { _ in throw TestFailure() }
        let scheduler = BackgroundScheduler(
            downloadManager: manager,
            libraryRepository: LibraryRepositoryStub(),
            mangaRepository: mangaRepository
        )
        let viewModel = DownloadsViewModel(
            downloadManager: manager,
            backgroundScheduler: scheduler,
            mangaRepository: mangaRepository
        )

        await viewModel.refresh()

        #expect(viewModel.sections.count == 1)
        #expect(viewModel.sections[0].chapters.map(\.chapterId) == ["c2", "c10"])
        #expect(viewModel.sections[0].totalBytes == 30)
        #expect(viewModel.sections[0].inFlightFraction == nil)
    }
}
