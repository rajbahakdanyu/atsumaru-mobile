import Foundation

public protocol HomeRepository: Sendable {
    func rail(_ endpoint: HomeEndpoint) async throws -> HomeRail
    func rail(_ endpoint: HomeEndpoint, offset: Int, limit: Int) async throws -> HomeRail
}

public struct LiveHomeRepository: HomeRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    public func rail(_ endpoint: HomeEndpoint) async throws -> HomeRail {
        try await client.get(endpoint.path)
    }

    public func rail(_ endpoint: HomeEndpoint, offset: Int, limit: Int) async throws -> HomeRail {
        var query = ["offset": String(offset), "limit": String(limit)]
        if endpoint == .popular {
            query["timeframe"] = "all"
        }
        return try await client.get(endpoint.path, query: query)
    }
}