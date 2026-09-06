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
            query: ["page": "0", "perPage": "40"]
        )
        return page.items ?? []
    }

    /// Tolerant list decode: prefers `{"lists":[...]}` then a bare array `[...]`.
    public func lists() async throws -> [UserList] {
        let data = try await client.getData("/api/user/userMangaLists/getLists")
        return try TolerantDecoding.array(UserList.self, from: data, key: "lists")
    }

    /// Tolerant history decode: prefers `{"items":[...]}` then a bare array.
    public func history() async throws -> [HistoryEntry] {
        let data = try await client.getData("/api/user/history")
        return try TolerantDecoding.array(HistoryEntry.self, from: data, key: "items")
    }

    public func createList(name: String) async throws {
        // Verified contract: the endpoint requires {"title": ..., "visibility": ...}.
        struct CreateBody: Encodable {
            let title: String
            let visibility: String
        }
        try await client.postVoid(
            "/api/user/userMangaLists/create",
            json: CreateBody(title: name, visibility: "Private")
        )
    }

    public func deleteList(id: String) async throws {
        // Verified contract: DELETE with a JSON body {"listId": ...}.
        struct DeleteBody: Encodable { let listId: String }
        try await client.deleteJSON(
            "/api/user/userMangaLists/deleteList",
            json: DeleteBody(listId: id)
        )
    }
}