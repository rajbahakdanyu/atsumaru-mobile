import Foundation

public protocol UserRepository: Sendable {
    func privateProfile() async throws -> PrivateProfile
}

public struct LiveUserRepository: UserRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    public func privateProfile() async throws -> PrivateProfile {
        try await client.get("/api/user/privateProfile")
    }
}
