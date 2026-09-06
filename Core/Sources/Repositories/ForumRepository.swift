import Foundation

public protocol ForumRepository: Sendable {
    func channels(includeAdult: Bool) async throws -> [ForumChannel]
    func posts(forumId: String, sort: String?, page: Int) async throws -> [ForumPost]
    func post(postId: String) async throws -> ForumPost
    func createPost(forumId: String, title: String, content: String) async throws
    func votePost(postId: String, vote: Int) async throws
    func bookmarkPost(postId: String, bookmarked: Bool) async throws
    func tags(forumId: String) async throws -> [ForumTag]
}

public struct LiveForumRepository: ForumRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct PostEnvelope: Decodable { let post: ForumPost }

    private struct CreatePostBody: Encodable {
        let forumId: String
        let title: String
        let content: String
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

    /// Tolerant decode: prefers `{"posts":[...]}` then a bare array `[...]`.
    public func posts(forumId: String, sort: String?, page: Int) async throws -> [ForumPost] {
        var query: [String: String] = ["forumId": forumId, "page": "\(page)"]
        if let sort { query["sort"] = sort }
        let data = try await client.getData("/api/forum/posts", query: query)
        return try TolerantDecoding.array(ForumPost.self, from: data, key: "posts")
    }

    /// Tolerant decode: prefers `{"post":{...}}` then a bare object `{...}`.
    public func post(postId: String) async throws -> ForumPost {
        let data = try await client.getData("/api/forum/getPost", query: ["postId": postId])
        if let env = try? JSONDecoder().decode(PostEnvelope.self, from: data) {
            return env.post
        }
        if let p = try? JSONDecoder().decode(ForumPost.self, from: data) {
            return p
        }
        throw ApiError.decoding
    }

    public func createPost(forumId: String, title: String, content: String) async throws {
        try await client.postVoid(
            "/api/forum/createPost",
            json: CreatePostBody(forumId: forumId, title: title, content: content)
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