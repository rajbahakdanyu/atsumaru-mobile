import Foundation

public struct Comment: Codable, Identifiable, Sendable {
    public let id: String
    public let content: String?
    public let user: CommentUser?
    public let createdAt: Int?      // epoch ms
    public let spoiler: Bool?
    public let score: Int?
    public let upvotes: Int?
    public let downvotes: Int?
    public let parentId: String?
    public let replies: [Comment]?
    public let descendantCount: Int?

    public struct CommentUser: Codable, Sendable {
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
            try? c.encodeIfPresent(username, forKey: .username)
            try? c.encodeIfPresent(usernameSlug, forKey: .usernameSlug)
            try? c.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        }
    }

    public var createdAtDate: Date? { createdAt?.dateFromEpochMs }

    public var displayScore: Int { score ?? ((upvotes ?? 0) - (downvotes ?? 0)) }

    private enum CodingKeys: String, CodingKey {
        case id, content, user, createdAt, spoiler, score
        case upVotes, upvotes, downVotes, downvotes
        case parentId, replies, descendantCount
    }
    private enum WrapperKey: String, CodingKey { case comment }

    public init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: CodingKeys.self)
        let c: KeyedDecodingContainer<CodingKeys>
        if let wrapper = try? decoder.container(keyedBy: WrapperKey.self),
           let nested = try? wrapper.nestedContainer(keyedBy: CodingKeys.self, forKey: .comment),
           (try? nested.decode(String.self, forKey: .id)) != nil {
            c = nested
        } else {
            c = top
        }
        id = try c.decode(String.self, forKey: .id)
        content = try? c.decodeIfPresent(String.self, forKey: .content)
        user = try? c.decodeIfPresent(CommentUser.self, forKey: .user)
        spoiler = try? c.decodeIfPresent(Bool.self, forKey: .spoiler)
        score = try? c.decodeIfPresent(Int.self, forKey: .score)
        upvotes = (try? c.decodeIfPresent(Int.self, forKey: .upVotes))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .upvotes))
        downvotes = (try? c.decodeIfPresent(Int.self, forKey: .downVotes))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .downvotes))
        createdAt = DateParsing.decodeEpochMs(c, forKey: .createdAt)
        parentId = try? c.decodeIfPresent(String.self, forKey: .parentId)
        replies = c.tolerantArray(Comment.self, forKey: .replies)
        descendantCount = try? c.decodeIfPresent(Int.self, forKey: .descendantCount)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try? c.encodeIfPresent(content, forKey: .content)
        try? c.encodeIfPresent(user, forKey: .user)
        try? c.encodeIfPresent(createdAt, forKey: .createdAt)
        try? c.encodeIfPresent(spoiler, forKey: .spoiler)
        try? c.encodeIfPresent(score, forKey: .score)
        try? c.encodeIfPresent(upvotes, forKey: .upvotes)
        try? c.encodeIfPresent(downvotes, forKey: .downvotes)
        try? c.encodeIfPresent(parentId, forKey: .parentId)
        try? c.encodeIfPresent(replies, forKey: .replies)
        try? c.encodeIfPresent(descendantCount, forKey: .descendantCount)
    }

    public init(id: String, content: String?, user: CommentUser?, createdAt: Int? = nil,
                spoiler: Bool? = nil, score: Int? = nil, upvotes: Int? = nil,
                downvotes: Int? = nil, parentId: String? = nil, replies: [Comment]? = nil,
                descendantCount: Int? = nil) {
        self.id = id; self.content = content; self.user = user; self.createdAt = createdAt
        self.spoiler = spoiler; self.score = score; self.upvotes = upvotes
        self.downvotes = downvotes
        self.parentId = parentId; self.replies = replies
        self.descendantCount = descendantCount
    }
}

public struct CommentSection: Codable, Sendable {
    public let id: String?
    public let comments: [Comment]?
    public let count: Int?

    public init(id: String?, comments: [Comment]?, count: Int?) {
        self.id = id; self.comments = comments; self.count = count
    }
}
