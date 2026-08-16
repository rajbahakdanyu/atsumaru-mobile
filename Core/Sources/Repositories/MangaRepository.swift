import Foundation

public protocol MangaRepository: Sendable {
    func page(id: String) async throws -> MangaPage
    func chapters(id: String, page: Int) async throws -> [Chapter]
}

public struct LiveMangaRepository: MangaRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct PageResponse: Decodable { let mangaPage: MangaPage }
    private struct ChaptersResponse: Decodable { let chapters: [Chapter] }

    public func page(id: String) async throws -> MangaPage {
        let resp: PageResponse = try await client.get("/api/manga/page", query: ["id": id])
        return resp.mangaPage
    }
    public func chapters(id: String, page: Int) async throws -> [Chapter] {
        let resp: ChaptersResponse = try await client.get("/api/manga/chapters", query: ["id": id, "page": String(page)])
        return resp.chapters
    }
}