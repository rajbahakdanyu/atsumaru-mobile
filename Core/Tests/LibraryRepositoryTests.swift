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
            #expect(items.contains(URLQueryItem(name: "perPage", value: "40")))
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
        // Real API shape: `title` (not `name`), no `itemCount`.
        let json = #"[{"id":"list1","title":"Favorites","description":"Best reads","isPublic":true}]"#
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

    @Test func listsDecodeNameFromTitleKey() async throws {
        let json = #"{"lists":[{"id":"list2","title":"To Read","description":"Queue"}]}"#
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
        #expect(lists.first?.name == "To Read")
        #expect(lists.first?.description == "Queue")
        #expect(lists.first?.pinned == false)
    }

    @Test func listsDecodePinnedAt() async throws {
        let json = #"{"lists":[{"id":"list3","title":"Pinned One","pinnedAt":"2026-01-01T00:00:00Z"}]}"#
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
        #expect(lists.first?.pinned == true)
        #expect(lists.first?.pinnedAt == "2026-01-01T00:00:00Z")
    }

    @Test func addMangaPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/addManga")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/addManga")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"alreadyExists":false}"#.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let exists = try await repo.addManga(listId: "l1", mangaId: "m1")
        #expect(exists == false)
        let body = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(body.contains("\"listId\":\"l1\""))
        #expect(body.contains("\"mangaId\":\"m1\""))
    }

    @Test func addMangaReturnsAlreadyExistsTrue() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/addManga")
            #expect(request.httpMethod == "POST")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/addManga")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"alreadyExists":true}"#.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let exists = try await repo.addManga(listId: "l1", mangaId: "m1")
        #expect(exists == true)
    }

    @Test func setPinnedPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/setPinned")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/setPinned")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        try await repo.setPinned(listId: "l1", pinned: true)
        let body = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(body.contains("\"listId\":\"l1\""))
        #expect(body.contains("\"pinned\":true"))
    }

    @Test func listDetailTolerantDecode() async throws {
        // Shape unverified from the wire — decode MUST tolerate both a flat item
        // shape {mangaId, title} and a nested {mangaId, manga:{title, poster:{image}}}.
        // When the verified `members` key is present alongside legacy `items`,
        // `members` wins (members has 2 entries, items 3 → count == 2).
        let json = """
        {"list":{"id":"l1","title":"My List","visibility":"Private",
          "members":[{"mangaId":"m1","title":"Flat T","note":"reading next"},
                     {"mangaId":"m2","manga":{"title":"Nested T","poster":{"image":"posters/n.jpg"}}}],
          "items":[{"mangaId":"x1","title":"Legacy 1"},
                   {"mangaId":"x2","title":"Legacy 2"},
                   {"mangaId":"x3","title":"Legacy 3"}]}}
        """
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/getList")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "listId", value: "l1")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/getList")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let detail = try await repo.listDetail(id: "l1")
        #expect(detail.id == "l1")
        #expect(detail.title == "My List")
        #expect(detail.visibility == "Private")
        #expect(detail.items.count == 2)
        #expect(detail.items[0].mangaId == "m1")
        #expect(detail.items[0].title == "Flat T")
        #expect(detail.items[0].poster == nil)
        #expect(detail.items[0].note == "reading next")
        #expect(detail.items[1].mangaId == "m2")
        #expect(detail.items[1].title == "Nested T")
        #expect(detail.items[1].poster == "posters/n.jpg")
    }

    @Test func listDetailAcceptsBareListShape() async throws {
        // Tolerant decode: if no {"list": ...} envelope arrives, a bare list
        // object at the top level must still decode.
        let json = """
        {"id":"l2","title":"Bare","visibility":"Public","items":[]}
        """
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/getList")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/getList")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let detail = try await repo.listDetail(id: "l2")
        #expect(detail.title == "Bare")
        #expect(detail.items.isEmpty)
    }

    @Test func listDetailDecodesMembersShape() async throws {
        // Verified wire shape: {"list": {id, title, visibility, members: [<manga-like>]}}
        // member: {id, title, medium, poster: {id, smallUrl, mediumUrl, largeUrl}, ...}
        let json = """
        {"list":{"id":"l1","title":"My List","visibility":"Private",
          "members":[
            {"id":"m1","title":"Knight","medium":"Comic",
             "poster":{"id":"posters/k1.webp","smallUrl":"posters/k1.webp","mediumUrl":"posters/k1.webp"}},
            {"id":"m2","title":"No Poster","medium":"Novel"},
            {"id":"m3","title":"Legacy","poster":"posters/legacy.webp"}]}}
        """
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/getList")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "listId", value: "l1")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/getList")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let detail = try await repo.listDetail(id: "l1")
        #expect(detail.items.count == 3)
        #expect(detail.items[0].mangaId == "m1")
        #expect(detail.items[0].title == "Knight")
        #expect(detail.items[0].poster == "posters/k1.webp")
        #expect(detail.items[1].mangaId == "m2")
        #expect(detail.items[1].poster == nil)
        #expect(detail.items[2].poster == "posters/legacy.webp")
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
        // Verified contract: POST /api/user/userMangaLists/create requires
        // {"title": ..., "visibility": "Public"|"Private"}.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/create")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/create")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        try await repo.createList(name: "Reading List")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"title\":\"Reading List\""))
        #expect(bodyString.contains("\"visibility\":\"Private\""))
        #expect(!bodyString.contains("\"name\""))
    }

    @Test func deleteListSendsJSONBody() async throws {
        // Verified contract: DELETE /api/user/userMangaLists/deleteList requires
        // a JSON body {"listId": ...}; no query params.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let capturedMethod = Box<String?>(nil)
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/deleteList")
            capturedMethod.value = request.httpMethod
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.isEmpty)
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/deleteList")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        try await repo.deleteList(id: "list1")
        #expect(capturedMethod.value == "DELETE")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"listId\":\"list1\""))
    }

    @Test func historyDecodesEpochMsReadAtAndNestedChapter() async throws {
        // Real history shape: `id` IS the manga id, `readAt` is epoch-ms, and
        // the chapter title/number live inside `continueReading`.
        let json = #"{"items":[{"id":"m1","title":"Solo Leveling","image":"posters/sl.jpg","readAt":1725148800000,"continueReading":{"chapterId":"c9","title":"Chapter 99","number":99,"page":3}}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/history")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/history")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let entries = try await repo.history()
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.id == "m1")
        #expect(entry.title == "Solo Leveling")
        #expect(entry.chapterId == "c9")
        #expect(entry.chapterTitle == "Chapter 99")
        #expect(entry.chapterNumber == 99)
        #expect(entry.readAt == 1_725_148_800_000)
        #expect(entry.readAtDate != nil)
    }

    @Test func historyReadAtAcceptsISO8601String() throws {
        let json = #"{"id":"m1","readAt":"2024-09-01T00:00:00.000Z","continueReading":{"title":"Chapter 1"}}"#
        let entry = try JSONDecoder().decode(HistoryEntry.self, from: Data(json.utf8))
        #expect(entry.readAtDate?.timeIntervalSince1970 == 1_725_148_800.0)
        #expect(entry.chapterTitle == "Chapter 1")
    }

    @Test func historyEntryWithoutContinueReadingDecodes() throws {
        let json = #"{"id":"m2","title":"Berserk"}"#
        let entry = try JSONDecoder().decode(HistoryEntry.self, from: Data(json.utf8))
        #expect(entry.id == "m2")
        #expect(entry.chapterTitle == nil)
        #expect(entry.chapterNumber == nil)
        #expect(entry.readAt == nil)
        #expect(entry.readAtDate == nil)
    }

    @Test func listDetailDecodesMangaKey() async throws {
        // REAL live shape: the list's manga live under "manga", not "members"/"items".
        let json = """
        {"status":"success","error":null,"list":{"id":"3PfuqvC7","title":"List",
          "description":null,"visibility":"Private","countViews":1,"countUpvotes":0,
          "countDownvotes":0,"createdAt":1788679000947,
          "manga":[
            {"id":"2VgNt","title":"Witch Hat Atelier","index":0,"note":null,
             "poster":{"id":"posters/N3HO30V76uWZV9iG.jpg","smallUrl":"posters/N3HO30V76uWZV9iG-small.avif","mediumUrl":"posters/N3HO30V76uWZV9iG-medium.avif"}},
            {"id":"3xHoW","title":"The Knight Only Lives Today","index":1,"note":null,
             "poster":{"id":"posters/3Pe8J1zAEnTA0UeP.jpg","smallUrl":"posters/3Pe8J1zAEnTA0UeP-small.avif","mediumUrl":"posters/3Pe8J1zAEnTA0UeP-medium.avif"}}]}}
        """
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/getList")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/getList")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let detail = try await repo.listDetail(id: "3PfuqvC7")
        #expect(detail.items.count == 2)
        #expect(detail.items[0].mangaId == "2VgNt")
        #expect(detail.items[0].title == "Witch Hat Atelier")
        #expect(detail.items[0].poster == "posters/N3HO30V76uWZV9iG.jpg")
        #expect(detail.items[1].mangaId == "3xHoW")
    }

    @Test func listsDecodeEmbeddedMangaIds() async throws {
        let json = """
        [{"id":"3PfuqvC7","title":"List","visibility":"Private",
          "manga":[{"id":"2VgNt","poster":{"id":"posters/a.jpg"}},
                   {"id":"3xHoW","poster":{"id":"posters/b.jpg"}}]}]
        """
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/userMangaLists/getLists")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/userMangaLists/getLists")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveLibraryRepository(client: client)
        let lists = try await repo.lists()
        #expect(lists.first?.mangaIds == ["2VgNt", "3xHoW"])
    }
}