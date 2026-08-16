import SwiftUI
import Core

@Observable
@MainActor
final class AppEnvironment {
    let apiClient = APIClient()
    let homeRepository: any HomeRepository
    let browseRepository: any BrowseRepository
    let mangaRepository: any MangaRepository
    let readRepository: any ReadRepository
    let novelRepository: any NovelRepository
    let progressStore: ProgressStore?

    init() {
        homeRepository = LiveHomeRepository(client: apiClient)
        browseRepository = LiveBrowseRepository(client: apiClient)
        mangaRepository = LiveMangaRepository(client: apiClient)
        readRepository = LiveReadRepository(client: apiClient)
        novelRepository = LiveNovelRepository(client: apiClient)
        progressStore = try? ProgressStore()
    }
}