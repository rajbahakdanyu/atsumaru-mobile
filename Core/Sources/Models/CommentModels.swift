import Foundation

public struct Comment: Codable, Identifiable, Sendable {
    public let id: String
    public let content: String?
    public let user: CommentUser?
    public let createdAt: String?
    public let spoiler: Bool?
    public let upvotes: Int?
    public let downvotes: Int?
    public let replies: [Comment]?

    public struct CommentUser: Codable, Sendable {
        public let id: String?
        public let username: String?
        public let usernameSlug: String?
        public let avatarUrl: String?
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, user, createdAt, spoiler, upvotes, downvotes, replies
    }
    private enum WrapperKey: String, CodingKey { case comment }

    public init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: CodingKeys.self)
        if let wrapper = try? decoder.container(keyedBy: WrapperKey.self),
           let nested = try? wrapper.nestedContainer(keyedBy: CodingKeys.self, forKey: .comment),
           let nestedId = try? nested.decodeIfPresent(String.self, forKey: .id) {
            id = nestedId
            content = try? nested.decodeIfPresent(String.self, forKey: .content)
            user = try? nested.decodeIfPresent(CommentUser.self, forKey: .user)
            createdAt = try? nested.decodeIfPresent(String.self, forKey: .createdAt)
            spoiler = try? nested.decodeIfPresent(Bool.self, forKey: .spoiler)
            upvotes = try? nested.decodeIfPresent(Int.self, forKey: .upvotes)
            downvotes = try? nested.decodeIfPresent(Int.self, forKey: .downvotes)
            replies = try? nested.decodeIfPresent([Comment].self, forKey: .replies)
        } else {
            id = try top.decode(String.self, forKey: .id)
            content = try? top.decodeIfPresent(String.self, forKey: .content)
            user = try? top.decodeIfPresent(CommentUser.self, forKey: .user)
            createdAt = try? top.decodeIfPresent(String.self, forKey: .createdAt)
            spoiler = try? top.decodeIfPresent(Bool.self, forKey: .spoiler)
            upvotes = try? top.decodeIfPresent(Int.self, forKey: .upvotes)
            downvotes = try? top.decodeIfPresent(Int.self, forKey: .downvotes)
            replies = try? top.decodeIfPresent([Comment].self, forKey: .replies)
        }
    }

    public init(id: String, content: String?, user: CommentUser?, createdAt: String?,
                spoiler: Bool?, upvotes: Int?, downvotes: Int?, replies: [Comment]?) {
        self.id = id; self.content = content; self.user = user; self.createdAt = createdAt
        self.spoiler = spoiler; self.upvotes = upvotes; self.downvotes = downvotes; self.replies = replies
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