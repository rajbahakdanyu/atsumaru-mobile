import Foundation

/// Tolerant private-profile model. All fields optional except where the server
/// is documented to provide them; unknown keys are ignored by the decoder so
/// shape drift won't break decoding.
public struct PrivateProfile: Decodable, Sendable, Equatable {
    public let id: String?
    public let username: String?
    public let usernameSlug: String?
    public let email: String?
    public let premium: Bool?
    public let rep: Int?
    public let avatarUrl: String?
    public let discordUsername: String?
    public let anilistUsername: String?
    public let countMangaRead: Int?
    public let countChaptersRead: Int?
    /// UNVERIFIED key name: following/followers counts were noted in the brief
    /// but the exact field names could not be confirmed from the site client.
    public let countFollowing: Int?
    /// UNVERIFIED key name (see countFollowing).
    public let countFollowers: Int?

    public init(
        id: String? = nil,
        username: String? = nil,
        usernameSlug: String? = nil,
        email: String? = nil,
        premium: Bool? = nil,
        rep: Int? = nil,
        avatarUrl: String? = nil,
        discordUsername: String? = nil,
        anilistUsername: String? = nil,
        countMangaRead: Int? = nil,
        countChaptersRead: Int? = nil,
        countFollowing: Int? = nil,
        countFollowers: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.usernameSlug = usernameSlug
        self.email = email
        self.premium = premium
        self.rep = rep
        self.avatarUrl = avatarUrl
        self.discordUsername = discordUsername
        self.anilistUsername = anilistUsername
        self.countMangaRead = countMangaRead
        self.countChaptersRead = countChaptersRead
        self.countFollowing = countFollowing
        self.countFollowers = countFollowers
    }
}

/// Tolerant notification-preferences model. Exact toggle keys are unverified
/// from the site client, so preferences are decoded generically into a
/// `[String: Bool]`. Non-bool values are dropped (decode never throws on them),
/// keeping the model resilient to shape drift. Round-trips back to the same
/// JSON object shape for the PUT endpoint.
public struct NotificationPreferences: Codable, Sendable, Equatable {
    public var keys: [String: Bool]

    public init(keys: [String: Bool] = [:]) { self.keys = keys }

    private struct TolerantBool: Decodable, Encodable {
        let value: Bool?
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            value = try? c.decode(Bool.self)
        }
        func encode(to e: Encoder) throws {
            var c = e.singleValueContainer()
            if let v = value { try c.encode(v) } else { try c.encodeNil() }
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode([String: TolerantBool].self)
        keys = raw.compactMapValues { $0.value }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(keys)
    }
}

/// Tolerant notification-list item. `id` defaults to "" if the server omits it
/// so the item remains `Identifiable`. `createdAt` accepts either an Int
/// epoch-millis value or an ISO8601 string (converted to epoch millis).
public struct NotificationItem: Decodable, Sendable, Identifiable, Equatable {
    public let id: String
    public let type: String?
    public let title: String?
    public let body: String?
    public let createdAt: Int?
    /// UNVERIFIED key name: read-state field is a best-effort extra for unread
    /// styling. Absent on the server → nil (no special styling).
    public let read: Bool?

    enum CodingKeys: String, CodingKey { case id, type, title, body, createdAt, read }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        read = try c.decodeIfPresent(Bool.self, forKey: .read)
        if let int = try? c.decodeIfPresent(Int.self, forKey: .createdAt) {
            createdAt = int
        } else if let str = try c.decodeIfPresent(String.self, forKey: .createdAt),
                  let ms = Self.epochMs(fromISO8601: str) {
            createdAt = ms
        } else {
            createdAt = nil
        }
    }

    private static func epochMs(fromISO8601 s: String) -> Int? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        return nil
    }
}