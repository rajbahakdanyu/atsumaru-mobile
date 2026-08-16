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
    var error: ApiError?

    var recentlyUpdated: [HomeItem] = []
    var recentlyUpdatedError: ApiError?

    private let browseRepository: any BrowseRepository
    private let homeRepository: any HomeRepository

    init(browseRepository: any BrowseRepository, homeRepository: any HomeRepository) {
        self.browseRepository = browseRepository
        self.homeRepository = homeRepository
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

    func loadRecentlyUpdated() async {
        do {
            let rail = try await homeRepository.rail(.recentlyUpdated)
            recentlyUpdated = rail.items
            recentlyUpdatedError = nil
        } catch {
            recentlyUpdatedError = (error as? ApiError) ?? .decoding
        }
    }

    func search() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await browseRepository.search(query)
            results = result.hits.map(\.document)
            totalFound = result.found
            error = nil
        } catch {
            self.error = (error as? ApiError) ?? .decoding
        }
    }
}