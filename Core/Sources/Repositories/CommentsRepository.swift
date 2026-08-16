import Foundation

public protocol CommentsRepository: Sendable {
    func threads(sectionId: String, parentId: String?, cursor: String?, sort: String?) async throws -> [Comment]
    func postComment(sectionId: String, parentId: String?, replyingToId: String?, content: String, spoiler: Bool) async throws
    func vote(commentId: String, vote: Int) async throws
    func paragraphCommentSection(chapterId: String, paragraph: Int, create: Bool) async throws -> CommentSection
}

public struct LiveCommentsRepository: CommentsRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct ThreadsEnvelope: Decodable {
        let threads: [Comment]?
    }
    private struct PostBody: Encodable {
        let sectionId: String
        let parentId: String?
        let replyingToId: String?
        let content: String
        let spoiler: Bool
    }
    private struct VoteBody: Encodable {
        let commentId: String
        let vote: Int
    }

    public func threads(sectionId: String, parentId: String?, cursor: String?, sort: String?) async throws -> [Comment] {
        var query: [String: String] = ["sectionId": sectionId]
        if let parentId { query["parentId"] = parentId }
        if let cursor { query["cursor"] = cursor }
        if let sort { query["sort"] = sort }
        let data = try await client.getData("/api/comments/v2/threads", query: query)
        if let env = try? JSONDecoder().decode(ThreadsEnvelope.self, from: data) {
            return env.threads ?? []
        }
        if let arr = try? JSONDecoder().decode([Comment].self, from: data) {
            return arr
        }
        return []
    }

    public func postComment(sectionId: String, parentId: String?, replyingToId: String?, content: String, spoiler: Bool) async throws {
        let _: EmptyResponse = try await client.post(
            "/api/comments/v2/postComment",
            json: PostBody(sectionId: sectionId, parentId: parentId,
                           replyingToId: replyingToId, content: content, spoiler: spoiler)
        )
    }

    public func vote(commentId: String, vote: Int) async throws {
        let _: EmptyResponse = try await client.post(
            "/api/comments/v2/vote",
            json: VoteBody(commentId: commentId, vote: vote)
        )
    }

    public func paragraphCommentSection(chapterId: String, paragraph: Int, create: Bool) async throws -> CommentSection {
        let section: CommentSection = try await client.get(
            "/api/comments/commentSections/getParagraphCommentSection",
            query: ["chapterId": chapterId, "paragraph": "\(paragraph)", "create": create ? "true" : "false"]
        )
        return section
    }
}