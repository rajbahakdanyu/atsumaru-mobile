import Foundation

public protocol UserRepository: Sendable {
    func privateProfile() async throws -> PrivateProfile
    func changeUsername(_ username: String, password: String) async throws
    func changeEmail(email: String, password: String) async throws
    func changePassword(oldPassword: String, newPassword: String, confirmPassword: String) async throws
    func changeAvatar(shape: String, borderColor: String) async throws
    func notificationPreferences() async throws -> NotificationPreferences
    func updateNotificationPreferences(_ prefs: NotificationPreferences) async throws
    func notifications() async throws -> [NotificationItem]
    func notificationCount() async throws -> Int
    func markAllNotificationsRead() async throws
}

public struct LiveUserRepository: UserRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct CountBody: Decodable { let count: Int }
    private struct PageEnvelope: Decodable {
        let items: [NotificationItem]?
        let notifications: [NotificationItem]?
    }
    private struct UsernameBody: Encodable { let username: String; let password: String }
    private struct EmailBody: Encodable { let email: String; let password: String }
    private struct PasswordBody: Encodable { let oldPassword: String; let newPassword: String; let confirmPassword: String }
    private struct AvatarBody: Encodable { let shape: String; let borderColor: String }
    private struct EmptyBody: Encodable {}
    private struct MutationEnvelope: Decodable {
        let success: Bool?
        let status: String?
        let error: String?
        enum CodingKeys: String, CodingKey { case success, status, error }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            success = try? c.decodeIfPresent(Bool.self, forKey: .success)
            status = try? c.decodeIfPresent(String.self, forKey: .status)
            // `error` may be a string ("✖ …") or a Zod object; treat object as a
            // generic message so decoding never throws on shape differences.
            if let s = try? c.decodeIfPresent(String.self, forKey: .error) {
                error = s
            } else {
                error = "Request failed"
            }
        }
    }

    public func privateProfile() async throws -> PrivateProfile {
        try await client.get("/api/user/privateProfile")
    }

    public func changeUsername(_ username: String, password: String) async throws {
        let env: MutationEnvelope = try await client.post(
            "/api/user/settings/changeUsername",
            json: UsernameBody(username: username, password: password)
        )
        try checkMutation(env)
    }

    public func changeEmail(email: String, password: String) async throws {
        let env: MutationEnvelope = try await client.post(
            "/api/user/settings/changeEmail",
            json: EmailBody(email: email, password: password)
        )
        try checkMutation(env)
    }

    public func changePassword(oldPassword: String, newPassword: String, confirmPassword: String) async throws {
        let env: MutationEnvelope = try await client.post(
            "/api/user/settings/changePassword",
            json: PasswordBody(oldPassword: oldPassword, newPassword: newPassword, confirmPassword: confirmPassword)
        )
        try checkMutation(env)
    }

    public func changeAvatar(shape: String, borderColor: String) async throws {
        let env: MutationEnvelope = try await client.post(
            "/api/user/settings/changeAvatar",
            json: AvatarBody(shape: shape, borderColor: borderColor)
        )
        try checkMutation(env)
    }

    /// Settings mutations return HTTP 200 even on failure, with `success: false`
    /// (or `status: "error"`) plus an `error` string in the body. This decodes the
    /// envelope and throws on failure so callers see a real error.
    private func checkMutation(_ envelope: MutationEnvelope) throws {
        if envelope.success == false || envelope.status == "error" {
            throw ApiError.server(envelope.error ?? "Request failed")
        }
    }

    public func notificationPreferences() async throws -> NotificationPreferences {
        try await client.get("/api/user/notificationPreferences")
    }

    public func updateNotificationPreferences(_ prefs: NotificationPreferences) async throws {
        try await client.putVoid(
            "/api/user/notificationPreferences",
            json: prefs
        )
    }

    public func notifications() async throws -> [NotificationItem] {
        let page: PageEnvelope = try await client.get("/api/notifications/page", query: ["limit": "50"])
        return page.items ?? page.notifications ?? []
    }

    public func notificationCount() async throws -> Int {
        let body: CountBody = try await client.get("/api/notifications/count")
        return body.count
    }

    public func markAllNotificationsRead() async throws {
        try await client.postVoid(
            "/api/notifications/markAllAsRead",
            json: EmptyBody()
        )
    }
}