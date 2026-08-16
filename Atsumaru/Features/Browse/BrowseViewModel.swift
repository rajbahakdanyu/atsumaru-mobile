import SwiftUI
import Core

@Observable @MainActor
final class BrowseViewModel {
    var query = SearchQuery()
    var filters: AvailableFilters?
    var filtersLoadFailed = false
    var results: [HomeItem] = []
    var totalFound = 0
    var isLoading = false

    private let browseRepository: any BrowseRepository

    init(browseRepository: any BrowseRepository) {
        self.browseRepository = browseRepository
    }

    func loadFilters() async {
        guard filters == nil else { return }
        filtersLoadFailed = false
        do {
            filters = try await browseRepository.availableFilters()
        } catch {
            filtersLoadFailed = true
        }
    }

    func search() async {
        isLoading = true
        defer { isLoading = false }
        guard let result = try? await browseRepository.search(query) else {
            return
        }
        results = result.hits.map(\.document)
        totalFound = result.found
    }
}