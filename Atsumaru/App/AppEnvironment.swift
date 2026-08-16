import SwiftUI
import Core

@Observable
@MainActor
final class AppEnvironment {
    let apiClient = APIClient()
    let homeRepository: any HomeRepository

    init() {
        homeRepository = LiveHomeRepository(client: apiClient)
    }
}