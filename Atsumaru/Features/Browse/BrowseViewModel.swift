import SwiftUI
import Core

@Observable @MainActor
final class BrowseViewModel {
    var query = SearchQuery()
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
    private var filteredPage = 0
    var hasActiveFilters: Bool {
        !query.genres.isEmpty || !query.tags.isEmpty || !query.types.isEmpty
            || !query.statuses.isEmpty || !query.mediums.isEmpty
            || query.minChapters != nil || sort != .relevance
            || (!query.q.isEmpty && query.q != "*")
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
        if reset { recentlyUpdatedHasMore = true }
        guard recentlyUpdatedHasMore else { return }
        isLoadingRecentlyUpdated = true
        defer { isLoadingRecentlyUpdated = false }
        do {
            let rail = try await homeRepository.rail(.recentlyUpdated, offset: reset ? 0 : recentlyUpdated.count, limit: pageSize)
            if reset {
                recentlyUpdated = rail.items
                recentlyUpdatedHasMore = rail.items.count == pageSize
            } else {
                let newItems = rail.items.filter { item in !recentlyUpdated.contains(where: { $0.id == item.id }) }
                recentlyUpdated.append(contentsOf: newItems)
                recentlyUpdatedHasMore = rail.items.count == pageSize
            }
            recentlyUpdatedError = nil
        } catch {
            recentlyUpdatedError = (error as? ApiError) ?? .decoding
        }
    }

    func loadPopular(reset: Bool = false) async {
        guard !isLoadingPopular else { return }
        if reset { popularHasMore = true }
        guard popularHasMore else { return }
        isLoadingPopular = true
        defer { isLoadingPopular = false }
        do {
            let rail = try await homeRepository.rail(.popular, offset: reset ? 0 : popular.count, limit: pageSize)
            if reset {
                popular = rail.items
                popularHasMore = rail.items.count == pageSize
            } else {
                let newItems = rail.items.filter { item in !popular.contains(where: { $0.id == item.id }) }
                popular.append(contentsOf: newItems)
                popularHasMore = rail.items.count == pageSize
            }
            popularError = nil
        } catch {
            popularError = (error as? ApiError) ?? .decoding
        }
    }

    func search() async {
        query.q = query.q.trimmingCharacters(in: .whitespacesAndNewlines)
        await reloadFiltered()
    }

    /// Synchronously clears the current filtered results and marks the feed as
    /// loading, so stale results never flash on screen before a reload. Call
    /// this from the main actor immediately before kicking off `reloadFiltered()`.
    func prepareFilteredReload() {
        filteredResults = []
        filteredHasMore = true
        filteredError = nil
    }

    /// Clears and reloads the filtered feed from page 1.
    func reloadFiltered() async {
        guard !isLoadingFiltered else { return }
        isLoadingFiltered = true
        defer { isLoadingFiltered = false }
        filteredPage = 0
        filteredHasMore = true
        filteredResults = []
        filteredError = nil
        await loadMoreFiltered()
    }

    /// Loads the next page of filtered results (infinite scroll).
    func loadMoreFiltered() async {
        guard !isLoadingFiltered else { return }
        guard filteredHasMore else { return }
        filteredPage += 1
        isLoadingFiltered = true
        defer { isLoadingFiltered = false }
        await fetchFilteredPage()
    }

    private func fetchFilteredPage() async {
        var q = query
        if q.q.isEmpty { q.q = "*" }
        q.sortBy = sort.rawValue
        q.page = filteredPage
        q.perPage = pageSize
        do {
            let result = try await browseRepository.search(q)
            let newItems = result.hits.map(\.document).filter { item in
                !filteredResults.contains(where: { $0.id == item.id })
            }
            filteredResults.append(contentsOf: newItems)
            // Base hasMore on the RAW page size (pre-dedup) so repeated/duplicate
            // hits across pages don't silently truncate the result set.
            filteredHasMore = result.hits.count == pageSize
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
        query.q = "*"
        sort = .relevance
    }
}
