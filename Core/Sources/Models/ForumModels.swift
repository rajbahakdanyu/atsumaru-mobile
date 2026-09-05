import Foundation

public struct ForumChannel: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let description: String?
    public let postCount: Int?
}

public struct ForumPost: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let forumId: String?
    public let title: String?
    public let content: String?
    public let user: ForumUser?
    public let createdAt: Int?      // epoch ms
    public let score: Int?
    public let upvotes: Int?
    public let downvotes: Int?
    public let pinned: Bool?
    public let locked: Bool?
    public let commentCount: Int?

    public var createdAtDate: Date? {
        guard let createdAt else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
    }

    public struct ForumUser: Codable, Sendable, Hashable {
        public let id: String?
        public let username: String?
        public let usernameSlug: String?
        public let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, username, usernameSlug, pfp, avatarUrl, usernameDisplay
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try? c.decodeIfPresent(String.self, forKey: .id)
            username = (try? c.decodeIfPresent(String.self, forKey: .usernameDisplay))
                ?? (try? c.decodeIfPresent(String.self, forKey: .username))
            usernameSlug = try? c.decodeIfPresent(String.self, forKey: .usernameSlug)
            avatarUrl = (try? c.decodeIfPresent(String.self, forKey: .pfp))
                ?? (try? c.decodeIfPresent(String.self, forKey: .avatarUrl))
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try? c.encodeIfPresent(id, forKey: .id)
            try? c.encodeIfPresent(username, forKey: .usernameDisplay)
            try? c.encodeIfPresent(usernameSlug, forKey: .usernameSlug)
            try? c.encodeIfPresent(avatarUrl, forKey: .pfp)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, forumId, title, content, createdAt, score, pinned, locked, commentCount
        case author, user
        case upVotes, upvotes, downVotes, downvotes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        forumId = try? c.decodeIfPresent(String.self, forKey: .forumId)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        content = try? c.decodeIfPresent(String.self, forKey: .content)
        user = (try? c.decodeIfPresent(ForumUser.self, forKey: .author))
            ?? (try? c.decodeIfPresent(ForumUser.self, forKey: .user))
        score = try? c.decodeIfPresent(Int.self, forKey: .score)
        pinned = try? c.decodeIfPresent(Bool.self, forKey: .pinned)
        locked = try? c.decodeIfPresent(Bool.self, forKey: .locked)
        commentCount = try? c.decodeIfPresent(Int.self, forKey: .commentCount)
        upvotes = (try? c.decodeIfPresent(Int.self, forKey: .upVotes))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .upvotes))
        downvotes = (try? c.decodeIfPresent(Int.self, forKey: .downVotes))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .downvotes))
        if let ms = try? c.decodeIfPresent(Int.self, forKey: .createdAt) {
            createdAt = ms
        } else if let str = try? c.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = Comment.epochMs(fromISO8601: str)
        } else {
            createdAt = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try? c.encodeIfPresent(forumId, forKey: .forumId)
        try? c.encodeIfPresent(title, forKey: .title)
        try? c.encodeIfPresent(content, forKey: .content)
        try? c.encodeIfPresent(user, forKey: .author)
        try? c.encodeIfPresent(createdAt, forKey: .createdAt)
        try? c.encodeIfPresent(score, forKey: .score)
        try? c.encodeIfPresent(upvotes, forKey: .upVotes)
        try? c.encodeIfPresent(downvotes, forKey: .downVotes)
        try? c.encodeIfPresent(pinned, forKey: .pinned)
        try? c.encodeIfPresent(locked, forKey: .locked)
        try? c.encodeIfPresent(commentCount, forKey: .commentCount)
    }
}

public struct ForumTag: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String?
}
