import Foundation

public protocol AuthRepository: Sendable {
    func me() async throws -> AuthUser?
    func login(email: String, password: String) async throws
    func signup(email: String, username: String, password: String) async throws
    func logout() async throws
    func sendVerification() async throws
    func verifyEmail(token: String) async throws
    func sendPasswordReset(email: String) async throws
    func resetPassword(token: String, newPassword: String, confirmPassword: String) async throws
    func oauthURL(provider: String) async throws -> String
    func oauthCallback(provider: String, code: String, state: String) async throws
}

public struct LiveAuthRepository: AuthRepository {
    public static let storedUserKey = "auth-user"

    private let client: APIClient
    private let keychain: KeychainStore

    public init(client: APIClient, keychain: KeychainStore) {
        self.client = client
        self.keychain = keychain
    }

    private struct MeResponse: Decodable { let me: AuthUser? }
    private struct EmptyBody: Encodable {}
    private struct OAuthURLResponse: Decodable { let url: String }

    public func me() async throws -> AuthUser? {
        let resp: MeResponse = try await client.get("/api/auth/me")
        if let user = resp.me, let data = try? JSONEncoder().encode(user) {
            try? keychain.save(data, key: Self.storedUserKey)
        }
        return resp.me
    }

    public func login(email: String, password: String) async throws {
        let _: EmptyResponse = try await client.postForm(
            "/api/auth/login",
            fields: ["email": email, "password": password]
        )
        _ = try? await me()
    }

    public func signup(email: String, username: String, password: String) async throws {
        let _: EmptyResponse = try await client.postForm(
            "/api/auth/signup",
            fields: ["email": email, "username": username, "password": password]
        )
        _ = try? await me()
    }

    public func logout() async throws {
        let _: EmptyResponse = try await client.post("/api/auth/logout/self", json: EmptyBody())
        try? keychain.delete(key: Self.storedUserKey)
    }

    public func sendVerification() async throws {
        let _: EmptyResponse = try await client.post("/api/auth/sendVerification", json: EmptyBody())
    }

    public func verifyEmail(token: String) async throws {
        let _: EmptyResponse = try await client.get("/api/auth/verify", query: ["token": token])
    }

    public func sendPasswordReset(email: String) async throws {
        let _: EmptyResponse = try await client.postForm(
            "/api/auth/sendPasswordReset/sendPasswordReset",
            fields: ["email": email]
        )
    }

    public func resetPassword(token: String, newPassword: String, confirmPassword: String) async throws {
        let _: EmptyResponse = try await client.postForm(
            "/api/auth/resetPassword/reset",
            fields: [
                "token": token,
                "newPassword": newPassword,
                "confirmPassword": confirmPassword,
            ]
        )
    }

    public func oauthURL(provider: String) async throws -> String {
        let resp: OAuthURLResponse = try await client.get("/api/auth/oauth/\(provider)/url")
        return resp.url
    }

    public func oauthCallback(provider: String, code: String, state: String) async throws {
        let _: EmptyResponse = try await client.get(
            "/api/auth/oauth/\(provider)/callback",
            query: ["code": code, "state": state]
        )
    }
}