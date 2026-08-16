import SwiftUI
import Core

@Observable @MainActor
final class BrowseViewModel {
    var query = SearchQuery()
    var results: [HomeItem] = []
    var totalFound = 0
    var isLoading = false
    var error: ApiError?

    var recentlyUpdated: [HomeItem] = []
    var popular: [HomeItem] = []
    var recentlyUpdatedError: ApiError?
    var popularError: ApiError?
    var isLoadingRecentlyUpdated = false
    var isLoadingPopular = false
    var recentlyUpdatedHasMore = true
    var popularHasMore = true

    var filters: AvailableFilters?
    var filtersLoadFailed = false
    var sort: BrowseSort = .relevance
    var filteredResults: [HomeItem] = []
    var filteredHasMore = true
    var isLoadingFiltered = false
    var filteredError: ApiError?
    var hasActiveFilters: Bool {
        !query.genres.isEmpty || !query.tags.isEmpty || !query.types.isEmpty
            || !query.statuses.isEmpty || !query.mediums.isEmpty
            || query.minChapters != nil || sort != .relevance
    }

    private let pageSize = 30
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

    func loadRecentlyUpdated(reset: Bool = false) async {
        guard !isLoadingRecentlyUpdated else { return }
        if reset { recentlyUpdatedHasMore = true; recentlyUpdated = [] }
        guard recentlyUpdatedHasMore else { return }
        isLoadingRecentlyUpdated = true
        defer { isLoadingRecentlyUpdated = false }
        do {
            let rail = try await homeRepository.rail(.recentlyUpdated, offset: recentlyUpdated.count, limit: pageSize)
            let newItems = rail.items.filter { item in !recentlyUpdated.contains(where: { $0.id == item.id }) }
            recentlyUpdated.append(contentsOf: newItems)
            recentlyUpdatedHasMore = rail.items.count == pageSize
            recentlyUpdatedError = nil
        } catch {
            recentlyUpdatedError = (error as? ApiError) ?? .decoding
        }
    }

    func loadPopular(reset: Bool = false) async {
        guard !isLoadingPopular else { return }
        if reset { popularHasMore = true; popular = [] }
        guard popularHasMore else { return }
        isLoadingPopular = true
        defer { isLoadingPopular = false }
        do {
            let rail = try await homeRepository.rail(.popular, offset: popular.count, limit: pageSize)
            let newItems = rail.items.filter { item in !popular.contains(where: { $0.id == item.id }) }
            popular.append(contentsOf: newItems)
            popularHasMore = rail.items.count == pageSize
            popularError = nil
        } catch {
            popularError = (error as? ApiError) ?? .decoding
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

    func loadFiltered(reset: Bool = false) async {
        guard !isLoadingFiltered else { return }
        if reset { filteredHasMore = true; filteredResults = [] }
        guard filteredHasMore else { return }
        isLoadingFiltered = true
        defer { isLoadingFiltered = false }
        var q = query
        q.q = "*"
        q.sortBy = sort.rawValue
        q.page = (filteredResults.count / pageSize) + 1
        q.perPage = pageSize
        do {
            let result = try await browseRepository.search(q)
            let newItems = result.hits.map(\.document).filter { item in
                !filteredResults.contains(where: { $0.id == item.id })
            }
            filteredResults.append(contentsOf: newItems)
            filteredHasMore = newItems.count == pageSize
            filteredError = nil
        } catch {
            filteredError = (error as? ApiError) ?? .decoding
        }
    }

    func clearFilters() {
        query.genres = []
        query.tags = []
        query.types = []
        query.statuses = []
        query.mediums = []
        query.minChapters = nil
        sort = .relevance
    }
}
