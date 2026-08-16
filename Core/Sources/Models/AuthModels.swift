import Foundation

public struct AuthUser: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let username: String?
    public let usernameSlug: String?
    public let email: String?
    public let premium: Bool?
    public let rep: Int?
    public let avatarUrl: String?
    public let discordUsername: String?
    public let anilistUsername: String?

    public init(
        id: String,
        username: String? = nil,
        usernameSlug: String? = nil,
        email: String? = nil,
        premium: Bool? = nil,
        rep: Int? = nil,
        avatarUrl: String? = nil,
        discordUsername: String? = nil,
        anilistUsername: String? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.usernameSlug = usernameSlug
        self.premium = premium
        self.rep = rep
        self.avatarUrl = avatarUrl
        self.discordUsername = discordUsername
        self.anilistUsername = anilistUsername
    }
}