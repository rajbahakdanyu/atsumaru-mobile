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
    public let type: String?
    public let title: String?
    public let content: String?
    public let user: ForumUser?
    public let createdAt: String?
    public let upvotes: Int?
    public let downvotes: Int?
    public let pinned: Bool?
    public let locked: Bool?
    public let tagIds: [String]?

    public struct ForumUser: Codable, Sendable, Hashable {
        public let id: String?
        public let username: String?
        public let usernameSlug: String?
    }
}

public struct ForumTag: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String?
}