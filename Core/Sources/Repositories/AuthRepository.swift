import Foundation

public protocol AuthRepository: Sendable {
    func me() async throws -> AuthUser?
    func login(identifier: String, password: String) async throws -> AuthUser
    func logout() async throws
    func sendPasswordReset(email: String) async throws
    func resetPassword(token: String, newPassword: String, confirmPassword: String) async throws
}

public struct LiveAuthRepository: AuthRepository {
    public static let storedUserKey = "auth-user"

    private let client: APIClient
    private let keychain: any KeychainStoring

    public init(client: APIClient, keychain: any KeychainStoring) {
        self.client = client
        self.keychain = keychain
    }

    private struct MeResponse: Decodable { let me: AuthUser? }
    private struct LoginResponse: Decodable { let status: String?; let error: String?; let me: AuthUser? }
    private struct EmptyBody: Encodable {}

    public func me() async throws -> AuthUser? {
        let resp: MeResponse = try await client.get("/api/auth/me")
        if let user = resp.me, let data = try? JSONEncoder().encode(user) {
            try? keychain.save(data, key: Self.storedUserKey)
        } else if resp.me == nil {
            try? keychain.delete(key: Self.storedUserKey)
        }
        return resp.me
    }

    public func login(identifier: String, password: String) async throws -> AuthUser {
        let resp: LoginResponse = try await client.postForm(
            "/api/auth/login",
            fields: ["username": identifier, "password": password]
        )
        if resp.status == "success", let user = resp.me {
            if let data = try? JSONEncoder().encode(user) {
                try? keychain.save(data, key: Self.storedUserKey)
            }
            return user
        }
        if resp.status == "error", let message = resp.error, !message.isEmpty {
            throw ApiError.server(message)
        }
        throw ApiError.server("Invalid username or password")
    }

    public func logout() async throws {
        defer { clearLocalSession() }
        try await client.postVoid("/api/auth/logout/self", json: EmptyBody())
    }

    private func clearLocalSession() {
        try? keychain.delete(key: Self.storedUserKey)
        let baseHost = APIClient.baseURL.host?.lowercased() ?? "atsu.moe"
        for cookie in HTTPCookieStorage.shared.cookies ?? []
        where {
            let domain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return domain == baseHost || domain.hasSuffix("." + baseHost)
        }() {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    public func sendPasswordReset(email: String) async throws {
        try await client.postFormVoid(
            "/api/auth/sendPasswordReset/sendPasswordReset",
            fields: ["email": email]
        )
    }

    public func resetPassword(token: String, newPassword: String, confirmPassword: String) async throws {
        try await client.postFormVoid(
            "/api/auth/resetPassword/reset",
            fields: [
                "token": token,
                "newPassword": newPassword,
                "confirmPassword": confirmPassword,
            ]
        )
    }
}