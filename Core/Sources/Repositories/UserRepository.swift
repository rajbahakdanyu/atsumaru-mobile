import Foundation

public protocol UserRepository: Sendable {
    func privateProfile() async throws -> PrivateProfile
    func changeUsername(_ username: String) async throws
    func changeEmail(email: String, password: String) async throws
    func changePassword(oldPassword: String, newPassword: String) async throws
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
    private struct UsernameBody: Encodable { let username: String }
    private struct EmailBody: Encodable { let email: String; let password: String }
    private struct PasswordBody: Encodable { let oldPassword: String; let newPassword: String }
    private struct AvatarBody: Encodable { let shape: String; let borderColor: String }
    private struct EmptyBody: Encodable {}

    public func privateProfile() async throws -> PrivateProfile {
        try await client.get("/api/user/privateProfile")
    }

    public func changeUsername(_ username: String) async throws {
        try await client.postVoid(
            "/api/user/settings/changeUsername",
            json: UsernameBody(username: username)
        )
    }

    public func changeEmail(email: String, password: String) async throws {
        try await client.postVoid(
            "/api/user/settings/changeEmail",
            json: EmailBody(email: email, password: password)
        )
    }

    public func changePassword(oldPassword: String, newPassword: String) async throws {
        try await client.postVoid(
            "/api/user/settings/changePassword",
            json: PasswordBody(oldPassword: oldPassword, newPassword: newPassword)
        )
    }

    public func changeAvatar(shape: String, borderColor: String) async throws {
        try await client.postVoid(
            "/api/user/settings/changeAvatar",
            json: AvatarBody(shape: shape, borderColor: borderColor)
        )
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
        let page: PageEnvelope = try await client.get("/api/notifications/page")
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