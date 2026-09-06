import Foundation

public struct ForumPostDetail: Sendable {
    public let post: ForumPost
    public let sectionId: String?
}

public protocol ForumRepository: Sendable {
    func channels(includeAdult: Bool) async throws -> [ForumChannel]
    func posts(forumId: String, sort: String?, page: Int, tagId: String?) async throws -> [ForumPost]
    func postDetail(postId: String) async throws -> ForumPostDetail
    func createPost(forumId: String, title: String, content: String, spoiler: Bool, tagIds: [String]) async throws
    func editPost(postId: String, title: String, content: String) async throws
    func removePost(postId: String) async throws
    func votePost(postId: String, vote: Int) async throws
    func bookmarkPost(postId: String, bookmarked: Bool) async throws
    func tags(forumId: String) async throws -> [ForumTag]
}

public struct LiveForumRepository: ForumRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct CreatePostBody: Encodable {
        let forumId: String
        let title: String
        let content: String
        let spoiler: Bool
        let tagIds: [String]
    }
    private struct EditPostBody: Encodable {
        let postId: String
        let title: String
        let content: String
    }
    private struct RemovePostBody: Encodable {
        let postId: String
    }
    private struct VotePostBody: Encodable {
        let postId: String
        let vote: String
    }
    private struct BookmarkBody: Encodable {
        let postId: String
        let bookmarked: Bool
    }

    /// Tolerant decode: prefers `{"channels":[...]}` then a bare array `[...]`.
    /// The server's Zod schema only accepts `adult=1` or the param's absence
    /// (`adult=false`/`adult=true` are rejected with 400).
    public func channels(includeAdult: Bool) async throws -> [ForumChannel] {
        var query: [String: String] = [:]
        if includeAdult { query["adult"] = "1" }
        let data = try await client.getData(
            "/api/forum/forums/channels",
            query: query
        )
        return try TolerantDecoding.array(ForumChannel.self, from: data, key: "channels")
    }

    /// Mirrors the website's channel feed: `sort` is one of hot|top|new|old;
    /// `tagId` filters to a single forum tag when set.
    public func posts(forumId: String, sort: String?, page: Int, tagId: String?) async throws -> [ForumPost] {
        var query: [String: String] = ["forumId": forumId, "page": "\(page)"]
        if let sort { query["sort"] = sort }
        if let tagId { query["tagId"] = tagId }
        let data = try await client.getData("/api/forum/posts", query: query)
        return try TolerantDecoding.array(ForumPost.self, from: data, key: "posts")
    }

    /// Tolerant decode: prefers `{"post":{...}, "sectionId": ...}` then a bare
    /// `{...}`. The comment section id may arrive as `sectionId` at the top
    /// level, or as `sectionId`/`commentSectionId` on the post itself.
    public func postDetail(postId: String) async throws -> ForumPostDetail {
        struct Envelope: Decodable { let post: ForumPost; let sectionId: String? }
        let data = try await client.getData("/api/forum/getPost", query: ["postId": postId])
        if let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            let sid = env.sectionId ?? env.post.sectionId ?? env.post.commentSectionId
            return ForumPostDetail(post: env.post, sectionId: sid.flatMap { $0.isEmpty ? nil : $0 })
        }
        if let p = try? JSONDecoder().decode(ForumPost.self, from: data) {
            let sid = p.sectionId ?? p.commentSectionId
            return ForumPostDetail(post: p, sectionId: sid.flatMap { $0.isEmpty ? nil : $0 })
        }
        throw ApiError.decoding
    }

    /// Website parity: the compose form always sends `spoiler` and `tagIds`
    /// (channels may require tags via `tagsRequired`).
    public func createPost(
        forumId: String, title: String, content: String, spoiler: Bool, tagIds: [String]
    ) async throws {
        try await client.postVoid(
            "/api/forum/createPost",
            json: CreatePostBody(
                forumId: forumId, title: title, content: content,
                spoiler: spoiler, tagIds: tagIds
            )
        )
    }

    /// Server requires title >= 3 chars and content >= 2 chars.
    public func editPost(postId: String, title: String, content: String) async throws {
        try await client.postVoid(
            "/api/forum/editPost",
            json: EditPostBody(postId: postId, title: title, content: content)
        )
    }

    public func removePost(postId: String) async throws {
        try await client.postVoid(
            "/api/forum/removePost",
            json: RemovePostBody(postId: postId)
        )
    }

    public func votePost(postId: String, vote: Int) async throws {
        // Server Zod schema requires vote to be one of "up" | "down" | "none".
        let direction: String
        switch vote {
        case ..<0: direction = "down"
        case 0: direction = "none"
        default: direction = "up"
        }
        try await client.postVoid(
            "/api/forum/votePost",
            json: VotePostBody(postId: postId, vote: direction)
        )
    }

    public func bookmarkPost(postId: String, bookmarked: Bool) async throws {
        try await client.postVoid(
            "/api/forum/bookmarkPost",
            json: BookmarkBody(postId: postId, bookmarked: bookmarked)
        )
    }

    /// Tolerant decode: prefers `{"tags":[...]}` then a bare array `[...]`.
    public func tags(forumId: String) async throws -> [ForumTag] {
        let data = try await client.getData("/api/forum/tags", query: ["forumId": forumId])
        return try TolerantDecoding.array(ForumTag.self, from: data, key: "tags")
    }
}