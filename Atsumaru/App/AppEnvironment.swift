import SwiftUI
import Core

@Observable
@MainActor
final class AppEnvironment {
    let apiClient = APIClient()
    let homeRepository: any HomeRepository
    let browseRepository: any BrowseRepository

    init() {
        homeRepository = LiveHomeRepository(client: apiClient)
        browseRepository = LiveBrowseRepository(client: apiClient)
    }
}