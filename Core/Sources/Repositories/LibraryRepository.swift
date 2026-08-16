import Foundation

public protocol LibraryRepository: Sendable {
    func bookmarks(offset: Int, limit: Int) async throws -> [Bookmark]
    func history() async throws -> [HistoryEntry]
    func lists() async throws -> [UserList]
    func createList(name: String) async throws
    func deleteList(id: String) async throws
    func continueReading() async throws -> [ContinueReadingItem]
}

public struct LiveLibraryRepository: LibraryRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct ItemsEnvelope<T: Decodable & Sendable>: Decodable, Sendable { let items: [T]? }

    public func bookmarks(offset: Int, limit: Int) async throws -> [Bookmark] {
        let page: ItemsEnvelope<Bookmark> = try await client.get(
            "/api/home2/bookmarks",
            query: ["offset": "\(offset)", "limit": "\(limit)"]
        )
        return page.items ?? []
    }

    public func continueReading() async throws -> [ContinueReadingItem] {
        let page: ItemsEnvelope<ContinueReadingItem> = try await client.get(
            "/api/infinite/continueReading",
            query: ["page": "0", "perPage": "20"]
        )
        return page.items ?? []
    }

    /// Tolerant list decode: prefers `{"lists":[...]}` then a bare array `[...]`.
    public func lists() async throws -> [UserList] {
        let data = try await client.getData("/api/user/userMangaLists/getLists")
        struct ListsEnvelope: Decodable { let lists: [UserList] }
        if let env = try? JSONDecoder().decode(ListsEnvelope.self, from: data) { return env.lists }
        if let arr = try? JSONDecoder().decode([UserList].self, from: data) { return arr }
        return []
    }

    /// Tolerant history decode: prefers `{"items":[...]}` then a bare array.
    public func history() async throws -> [HistoryEntry] {
        let data = try await client.getData("/api/user/history")
        struct ItemsEnvelope: Decodable { let items: [HistoryEntry] }
        if let env = try? JSONDecoder().decode(ItemsEnvelope.self, from: data) { return env.items }
        if let arr = try? JSONDecoder().decode([HistoryEntry].self, from: data) { return arr }
        return []
    }

    public func createList(name: String) async throws {
        struct NameBody: Encodable { let name: String }
        let _: EmptyResponse = try await client.post(
            "/api/user/userMangaLists/create",
            json: NameBody(name: name)
        )
    }

    public func deleteList(id: String) async throws {
        let _: EmptyResponse = try await client.delete(
            "/api/user/userMangaLists/deleteList",
            query: ["id": id]
        )
    }
}