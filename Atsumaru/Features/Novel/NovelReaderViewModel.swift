import SwiftUI
import Core

@Observable
@MainActor
final class NovelReaderViewModel {
    let mangaId: String
    let chapter: Chapter
    private let novelRepository: any NovelRepository

    var novel: NovelChapter?
    var isLoading = false
    var loadFailed = false

    init(mangaId: String, chapter: Chapter, novelRepository: any NovelRepository) {
        self.mangaId = mangaId
        self.chapter = chapter
        self.novelRepository = novelRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            novel = try await novelRepository.novelChapter(mangaId: mangaId, chapterId: chapter.id)
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}