import SwiftUI
import Core

@Observable @MainActor
final class HomeViewModel {
    var rails: [(HomeEndpoint, [HomeItem])] = []
    var isLoading = false

    private let homeRepository: any HomeRepository

    init(homeRepository: any HomeRepository) {
        self.homeRepository = homeRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let wanted: [HomeEndpoint] = [.popular, .recommended, .recentlyUpdated]
        var result: [(HomeEndpoint, [HomeItem])] = []
        for endpoint in wanted {
            if let rail = try? await homeRepository.rail(endpoint) {
                result.append((endpoint, rail.items))
            }
        }
        rails = result
    }
}