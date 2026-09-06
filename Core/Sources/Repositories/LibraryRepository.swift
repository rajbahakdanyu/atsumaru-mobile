import Foundation
import os

public protocol LibraryRepository: Sendable {
    func bookmarks(offset: Int, limit: Int) async throws -> [Bookmark]
    func history() async throws -> [HistoryEntry]
    func lists() async throws -> [UserList]
    func createList(name: String) async throws
    func deleteList(id: String) async throws
    func addManga(listId: String, mangaId: String) async throws -> Bool
    func setPinned(listId: String, pinned: Bool) async throws
    func listDetail(id: String) async throws -> ListDetail
    func continueReading() async throws -> [ContinueReadingItem]
}

private let logger = Logger(subsystem: "dev.atsumaru.app", category: "library")

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

    public func addManga(listId: String, mangaId: String) async throws -> Bool {
        // Verified contract: response contains `alreadyExists` (nil → false).
        struct AddBody: Encodable { let listId: String; let mangaId: String }
        struct AddResponse: Decodable { let alreadyExists: Bool? }
        let response: AddResponse = try await client.post(
            "/api/user/userMangaLists/addManga",
            json: AddBody(listId: listId, mangaId: mangaId)
        )
        return response.alreadyExists ?? false
    }

    public func setPinned(listId: String, pinned: Bool) async throws {
        // Verified contract: POST {"listId": ..., "pinned": Bool}.
        struct PinBody: Encodable { let listId: String; let pinned: Bool }
        try await client.postVoid(
            "/api/user/userMangaLists/setPinned",
            json: PinBody(listId: listId, pinned: pinned)
        )
    }

    /// Single list with its manga. The `getList` response shape is UNVERIFIED,
    /// so decode tolerantly (`{"list": {...}}` then a bare list object); when
    /// neither shape matches, log the raw response (truncated) so the first
    /// real run fixes any shape mismatch.
    public func listDetail(id: String) async throws -> ListDetail {
        struct Envelope: Decodable { let list: ListDetail }
        let data = try await client.getData(
            "/api/user/userMangaLists/getList",
            query: ["listId": id]
        )
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return envelope.list
        }
        if let bare = try? JSONDecoder().decode(ListDetail.self, from: data) {
            return bare
        }
        logger.error("listDetail \(id, privacy: .public) decode failed: \(String(data: data.prefix(2000), encoding: .utf8) ?? "?", privacy: .public)")
        throw ApiError.decoding
    }
}