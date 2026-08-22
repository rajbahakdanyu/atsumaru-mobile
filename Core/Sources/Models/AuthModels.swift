import Foundation

/// Authenticated user. The live API names the display name `usernameDisplay`
/// and the avatar `pfp`; this model keeps the app-facing `username`/`avatarUrl`
/// fields but decodes them tolerantly from either key.
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

    enum CodingKeys: String, CodingKey {
        case id, username, usernameSlug, email, premium, rep, avatarUrl
        case usernameDisplay, pfp, discordUsername, anilistUsername
    }

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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = (try? c.decodeIfPresent(String.self, forKey: .usernameDisplay))
            ?? (try? c.decodeIfPresent(String.self, forKey: .username))
        usernameSlug = try? c.decodeIfPresent(String.self, forKey: .usernameSlug)
        email = try? c.decodeIfPresent(String.self, forKey: .email)
        premium = try? c.decodeIfPresent(Bool.self, forKey: .premium)
        rep = try? c.decodeIfPresent(Int.self, forKey: .rep)
        avatarUrl = (try? c.decodeIfPresent(String.self, forKey: .pfp))
            ?? (try? c.decodeIfPresent(String.self, forKey: .avatarUrl))
        discordUsername = try? c.decodeIfPresent(String.self, forKey: .discordUsername)
        anilistUsername = try? c.decodeIfPresent(String.self, forKey: .anilistUsername)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(username, forKey: .username)
        try c.encodeIfPresent(usernameSlug, forKey: .usernameSlug)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(premium, forKey: .premium)
        try c.encodeIfPresent(rep, forKey: .rep)
        try c.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try c.encodeIfPresent(discordUsername, forKey: .discordUsername)
        try c.encodeIfPresent(anilistUsername, forKey: .anilistUsername)
    }
}