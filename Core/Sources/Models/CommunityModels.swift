import Foundation

public struct PublicProfile: Codable, Identifiable, Sendable {
    public let id: String
    public let username: String?
    public let usernameSlug: String?
    public let avatarUrl: String?
    public let bio: String?
    public let rep: Int?
    public let isFollowing: Bool?
    public let countMangaRead: Int?
    public let countChaptersRead: Int?
    /// UNVERIFIED key name (best-effort from site client). Absent → nil.
    public let followerCount: Int?
    /// UNVERIFIED key name (best-effort from site client). Absent → nil.
    public let followingCount: Int?
}

public struct UserSummary: Codable, Identifiable, Sendable {
    public let id: String
    public let username: String?
    public let usernameSlug: String?
    public let avatarUrl: String?
}

public struct CommunityGroup: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let tag: String?
    public let type: String?
    public let bio: String?
    /// UNVERIFIED key name (best-effort from site client). Absent → nil.
    public let memberCount: Int?
    /// UNVERIFIED key name (best-effort from site client). Absent → nil.
    public let isMember: Bool?
}

public struct Poll: Codable, Identifiable, Sendable {
    public let id: String
    public let question: String?
    public let options: [PollOption]?

    public struct PollOption: Codable, Identifiable, Sendable {
        public let id: String
        public let text: String?
        public let voteCount: Int?
    }
}