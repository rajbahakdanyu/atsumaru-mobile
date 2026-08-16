import Foundation

public protocol BrowseRepository: Sendable {
    func search(_ query: SearchQuery) async throws -> SearchResult
}

public struct LiveBrowseRepository: BrowseRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    public func search(_ query: SearchQuery) async throws -> SearchResult {
        try await client.get("/collections/manga/documents/search", query: query.toQueryItems())
    }
}
