import Foundation
import os

private let logger = Logger(subsystem: "dev.atsumaru.app", category: "comments")

public protocol CommentsRepository: Sendable {
    func threads(sectionId: String, parentId: String?, cursor: String?, sort: String?) async throws -> [Comment]
    func postComment(sectionId: String, parentId: String?, replyingToId: String?, content: String, spoiler: Bool) async throws
    func vote(commentId: String, vote: Int) async throws
    func paragraphCommentSection(chapterId: String, paragraph: Int, create: Bool) async throws -> CommentSection
    func commentSection(chapterId: String) async throws -> CommentSection
}

public struct LiveCommentsRepository: CommentsRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct PostBody: Encodable {
        let sectionId: String
        let parentId: String?
        let replyingToId: String?
        let content: String
        let spoiler: Bool
    }
    private struct VoteBody: Encodable {
        let commentId: String
        let vote: String   // "up" | "down" | "none" (server Zod union, same as posts)
    }

    public func threads(sectionId: String, parentId: String?, cursor: String?, sort: String?) async throws -> [Comment] {
        var query: [String: String] = ["sectionId": sectionId, "maxDepth": "3"]
        if let parentId { query["parentId"] = parentId }
        if let cursor { query["cursor"] = cursor }
        if let sort { query["sort"] = sort }
        let data = try await client.getData("/api/comments/v2/threads", query: query)
        return try TolerantDecoding.array(Comment.self, from: data, key: "comments")
    }

    public func postComment(sectionId: String, parentId: String?, replyingToId: String?, content: String, spoiler: Bool) async throws {
        try await client.postVoid(
            "/api/comments/v2/postComment",
            json: PostBody(sectionId: sectionId, parentId: parentId,
                           replyingToId: replyingToId, content: content, spoiler: spoiler)
        )
    }

    public func vote(commentId: String, vote: Int) async throws {
        let direction: String
        switch vote {
        case 1: direction = "up"
        case -1: direction = "down"
        default: direction = "none"
        }
        try await client.postVoid(
            "/api/comments/v2/vote",
            json: VoteBody(commentId: commentId, vote: direction)
        )
    }

    public func paragraphCommentSection(chapterId: String, paragraph: Int, create: Bool) async throws -> CommentSection {
        let section: CommentSection = try await client.get(
            "/api/comments/commentSections/getParagraphCommentSection",
            query: ["chapterId": chapterId, "paragraph": "\(paragraph)", "create": create ? "true" : "false"]
        )
        return section
    }

    /// Chapter comments section: GET getCommentSection?chapterId= →
    /// {"section": {"id": ...}}. Tolerates {"commentSection": {...}} and a bare
    /// {"id": ...}; logs the raw payload when nothing matches.
    public func commentSection(chapterId: String) async throws -> CommentSection {
        struct Envelope: Decodable { let section: Bare?; let commentSection: Bare? }
        struct Bare: Decodable { let id: String? }
        let data = try await client.getData(
            "/api/comments/commentSections/getCommentSection",
            query: ["chapterId": chapterId]
        )
        if let env = try? JSONDecoder().decode(Envelope.self, from: data) {
            if let id = env.section?.id ?? env.commentSection?.id, !id.isEmpty {
                return CommentSection(id: id, comments: nil, count: nil)
            }
        }
        if let bare = try? JSONDecoder().decode(Bare.self, from: data),
           let id = bare.id, !id.isEmpty {
            return CommentSection(id: id, comments: nil, count: nil)
        }
        logger.error("commentSection decode failed for chapter \(chapterId, privacy: .public): \(String(data: data.prefix(2000), encoding: .utf8) ?? "?", privacy: .public)")
        throw ApiError.decoding
    }
}