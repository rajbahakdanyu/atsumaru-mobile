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

    private struct ChannelsEnvelope: Decodable { let channels: [ForumChannel] }
    private struct PostsEnvelope: Decodable { let posts: [ForumPost] }
    private struct PostEnvelope: Decodable { let post: ForumPost }
    private struct TagsEnvelope: Decodable { let tags: [ForumTag] }

    private struct CreatePostBody: Encodable {
        let forumId: String
        let title: String
        let content: String
    }
    private struct VotePostBody: Encodable {
        let postId: String
        let vote: Int
    }
    private struct BookmarkBody: Encodable {
        let postId: String
        let bookmarked: Bool
    }

    /// Tolerant decode: prefers `{"channels":[...]}` then a bare array `[...]`.
    public func channels(includeAdult: Bool) async throws -> [ForumChannel] {
        let data = try await client.getData(
            "/api/forum/forums/channels",
            query: ["adult": includeAdult ? "true" : "false"]
        )
        if let env = try? JSONDecoder().decode(ChannelsEnvelope.self, from: data) {
            return env.channels
        }
        if let arr = try? JSONDecoder().decode([ForumChannel].self, from: data) {
            return arr
        }
        return []
    }

    /// Tolerant decode: prefers `{"posts":[...]}` then a bare array `[...]`.
    public func posts(forumId: String, sort: String?, page: Int) async throws -> [ForumPost] {
        var query: [String: String] = ["forumId": forumId, "page": "\(page)"]
        if let sort { query["sort"] = sort }
        let data = try await client.getData("/api/forum/posts", query: query)
        if let env = try? JSONDecoder().decode(PostsEnvelope.self, from: data) {
            return env.posts
        }
        if let arr = try? JSONDecoder().decode([ForumPost].self, from: data) {
            return arr
        }
        return []
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
        let _: EmptyResponse = try await client.post(
            "/api/forum/createPost",
            json: CreatePostBody(forumId: forumId, title: title, content: content)
        )
    }

    public func votePost(postId: String, vote: Int) async throws {
        let _: EmptyResponse = try await client.post(
            "/api/forum/votePost",
            json: VotePostBody(postId: postId, vote: vote)
        )
    }

    public func bookmarkPost(postId: String, bookmarked: Bool) async throws {
        let _: EmptyResponse = try await client.post(
            "/api/forum/bookmarkPost",
            json: BookmarkBody(postId: postId, bookmarked: bookmarked)
        )
    }

    /// Tolerant decode: prefers `{"tags":[...]}` then a bare array `[...]`.
    public func tags(forumId: String) async throws -> [ForumTag] {
        let data = try await client.getData("/api/forum/tags", query: ["forumId": forumId])
        if let env = try? JSONDecoder().decode(TagsEnvelope.self, from: data) {
            return env.tags
        }
        if let arr = try? JSONDecoder().decode([ForumTag].self, from: data) {
            return arr
        }
        return []
    }
}