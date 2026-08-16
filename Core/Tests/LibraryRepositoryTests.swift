import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct LibraryRepositoryTests {
    @Test func bookmarksDecode() async throws {
        let json = #"{"items":[{"id":"b1","title":"Solo Leveling","image":"posters/sl.jpg","smallImage":"posters/sl-s.avif","mediumImage":"posters/sl-m.avif","largeImage":"posters/sl-l.avif","isAdult":false,"type":"Manga","medium":"Comic","bookmarkStatus":"Reading"}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/home2/bookmarks")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "offset", value: "0")))
            #expect(items.contains(URLQueryItem(name: "limit", value: "20")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/home2/bookmarks")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let bookmarks = try await repo.bookmarks(offset: 0, limit: 20)
        #expect(bookmarks.count == 1)
        #expect(bookmarks.first?.title == "Solo Leveling")
        #expect(bookmarks.first?.bookmarkStatus == "Reading")
    }

    @Test func continueReadingDecodesProgress() async throws {
        let json = #"{"items":[{"id":"cr1","title":"Omniscient Reader","image":"posters/or.jpg","smallImage":"posters/or-s.avif","mediumImage":"posters/or-m.avif","largeImage":"posters/or-l.avif","medium":"Novel","bookmarkStatus":"Reading","continueReading":{"chapterId":"c1","page":5,"ts":123,"mode":"manga"}}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/infinite/continueReading")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "page", value: "0")))
            #expect(items.contains(URLQueryItem(name: "perPage", value: "20")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/infinite/continueReading")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let items = try await repo.continueReading()
        #expect(items.count == 1)
        #expect(items.first?.continueReading?.chapterId == "c1")
        #expect(items.first?.continueReading?.page == 5)
        #expect(items.first?.continueReading?.mode == "manga")
    }

    @Test func listsToleratesArrayEnvelope() async throws {
        let json = #"[{"id":"list1","name":"Favorites","description":"Best reads","itemCount":12,"isPublic":true}]"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/getLists")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/getLists")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let lists = try await repo.lists()
        #expect(lists.count == 1)
        #expect(lists.first?.name == "Favorites")
    }

    @Test func listsThrowsWhenNoEnvelopeDecodes() async throws {
        let json = #"{"error":"shape drifted"}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/getLists")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        await #expect(throws: ApiError.decoding) {
            _ = try await repo.lists()
        }
    }

    @Test func createListPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/create")
            #expect(request.httpMethod == "POST")
            captured.value = LibraryRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/create")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        try await repo.createList(name: "Reading List")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"name\""))
        #expect(bodyString.contains("Reading List"))
    }

    @Test func deleteListDeletes() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let capturedMethod = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/deleteList")
            capturedMethod.value = request.httpMethod
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "id", value: "list1")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/deleteList")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        try await repo.deleteList(id: "list1")
        #expect(capturedMethod.value == "DELETE")
    }
}

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

private extension LibraryRepositoryTests {
    static func body(of request: URLRequest) -> Data? {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return nil }
        var data = Data()
        stream.open()
        let capacity = 4096
        var buffer = [UInt8](repeating: 0, count: capacity)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: capacity)
            if read > 0 {
                data.append(&buffer, count: read)
            } else {
                break
            }
        }
        stream.close()
        return data
    }
}