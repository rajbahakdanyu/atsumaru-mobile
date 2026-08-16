import Foundation

public protocol BrowseRepository: Sendable {
    func search(_ query: SearchQuery) async throws -> SearchResult
    func availableFilters() async throws -> AvailableFilters
}

public struct LiveBrowseRepository: BrowseRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    public func search(_ query: SearchQuery) async throws -> SearchResult {
        try await client.get("/collections/manga/documents/search", query: query.toQueryItems())
    }

    public func availableFilters() async throws -> AvailableFilters {
        try await client.get("/api/explore/availableFilters")
    }
}