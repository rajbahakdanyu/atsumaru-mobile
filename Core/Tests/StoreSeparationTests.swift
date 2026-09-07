import Foundation
import Testing
@testable import Core

/// Regression test: `DownloadStore` and `ProgressStore` previously both opened
/// their container with the unnamed default `ModelConfiguration`, pointing
/// both at the same `Application Support/default.store` file with different
/// schemas. The second container to open failed, and `AppEnvironment` swallowed
/// the failure with `try?`, so persistence silently stopped. Each store's
/// production init must now succeed independently and round-trip its own
/// records through its own named persistent store.
@MainActor
@Suite(.serialized)
struct StoreSeparationTests {
    @Test func productionStoresOpenDistinctPersistentStoresAndRoundTrip() throws {
        let downloads = try DownloadStore()
        let progress = try ProgressStore()
        let suffix = UUID().uuidString
        let chapterId = "sep-ch-\(suffix)"
        let mangaId = "sep-manga-\(suffix)"
        defer {
            try? downloads.delete(chapterId: chapterId)
            try? progress.delete(mangaId: mangaId, chapterId: "sep-c1")
            try? progress.delete(mangaId: mangaId, chapterId: "sep-c2")
        }

        try downloads.save(DownloadedChapterSnapshot(
            chapterId: chapterId, mangaId: mangaId, mangaTitle: "Sep Manga",
            chapterTitle: "Sep Chapter", kind: "manga", pageCount: 3,
            totalBytes: 1024, completedAt: Date(timeIntervalSince1970: 100),
            state: "completed"))
        let savedDownload = try #require(downloads.all().first { $0.chapterId == chapterId })
        #expect(savedDownload.mangaId == mangaId)
        #expect(savedDownload.pageCount == 3)

        try progress.save(ProgressState(
            mangaId: mangaId, chapterId: "sep-c1", pageIndex: 2,
            updatedAt: Date(timeIntervalSince1970: 200)))
        let savedProgress = try #require(progress.progress(mangaId: mangaId, chapterId: "sep-c1"))
        #expect(savedProgress.pageIndex == 2)

        try progress.save(ProgressState(
            mangaId: mangaId, chapterId: "sep-c2", pageIndex: 4,
            updatedAt: Date(timeIntervalSince1970: 300)))
        let indexedProgress = progress.progressByChapter(mangaId: mangaId)
        #expect(indexedProgress["sep-c1"]?.pageIndex == 2)
        #expect(indexedProgress["sep-c2"]?.pageIndex == 4)
        #expect(progress.latestProgress(mangaId: mangaId)?.chapterId == "sep-c2")

    }
}
