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
    let progressStore: ProgressStore?

    init() {
        homeRepository = LiveHomeRepository(client: apiClient)
        browseRepository = LiveBrowseRepository(client: apiClient)
        mangaRepository = LiveMangaRepository(client: apiClient)
        readRepository = LiveReadRepository(client: apiClient)
        progressStore = try? ProgressStore()
    }
}