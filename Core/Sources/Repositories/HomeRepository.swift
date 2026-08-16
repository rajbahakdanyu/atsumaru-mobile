import Foundation

public protocol HomeRepository: Sendable {
    func rail(_ endpoint: HomeEndpoint) async throws -> HomeRail
}

public struct LiveHomeRepository: HomeRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    public func rail(_ endpoint: HomeEndpoint) async throws -> HomeRail {
        try await client.get(endpoint.path)
    }
}