import Foundation

public protocol ReadRepository: Sendable {
    func chapter(mangaId: String, chapterId: String) async throws -> ReadChapter
    func updateProgress(_ update: ProgressUpdate) async throws
}

public struct LiveReadRepository: ReadRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct ReadChapterResponse: Decodable { let readChapter: ReadChapter }
    private struct UpdateProgressBody: Encodable { let progress: ProgressUpdate }

    public func chapter(mangaId: String, chapterId: String) async throws -> ReadChapter {
        let resp: ReadChapterResponse = try await client.get(
            "/api/read/chapter",
            query: ["mangaId": mangaId, "chapterId": chapterId]
        )
        return resp.readChapter
    }

    public func updateProgress(_ update: ProgressUpdate) async throws {
        try await client.postVoid("/api/read/updateProgress", json: UpdateProgressBody(progress: update))
    }
}

public protocol NovelRepository: Sendable {
    func novelChapter(mangaId: String, chapterId: String) async throws -> NovelChapter
}

public struct LiveNovelRepository: NovelRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct NovelChapterResponse: Decodable { let readNovelChapter: NovelChapter }

    public func novelChapter(mangaId: String, chapterId: String) async throws -> NovelChapter {
        let resp: NovelChapterResponse = try await client.get(
            "/api/read/novelChapter",
            query: ["mangaId": mangaId, "chapterId": chapterId]
        )
        return resp.readNovelChapter
    }
}