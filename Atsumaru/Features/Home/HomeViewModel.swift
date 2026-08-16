import SwiftUI
import Core

@Observable @MainActor
final class HomeViewModel {
    var rails: [(HomeEndpoint, [HomeItem])] = []
    var isLoading = false
    var error: ApiError?

    private let homeRepository: any HomeRepository

    init(homeRepository: any HomeRepository) {
        self.homeRepository = homeRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let wanted: [HomeEndpoint] = [.popular, .recommended, .recentlyUpdated]
        var result: [(HomeEndpoint, [HomeItem])] = []
        var lastError: ApiError?
        for endpoint in wanted {
            do {
                let rail = try await homeRepository.rail(endpoint)
                if !rail.items.isEmpty {
                    result.append((endpoint, rail.items))
                }
            } catch {
                lastError = (error as? ApiError) ?? .decoding
            }
        }
        rails = result
        error = result.isEmpty ? lastError : nil
    }
}