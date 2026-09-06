import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct MangaRepositoryTests {
    @Test func pageDecodesMangaPage() async throws {
        let json = #"{"mangaPage":{"id":"x","title":"Witch Hat Atelier","englishTitle":"Tongari Boushi","type":"Manga","medium":"Comic","status":"Ongoing","synopsis":"A girl finds a hat.","views":"14.8M","released":1500000000000,"avgRating":8.4,"mbRating":8.4,"totalChapterCount":97,"hasReadHistory":false,"poster":{"image":"posters/a.jpg","smallImage":"posters/a-small.avif","mediumImage":"posters/a-medium.avif","largeImage":"posters/a-large.avif"},"banner":{"url":"banners/b.jpg","aspectRatio":4.75},"genres":[{"id":"37","name":"Adventure","weight":"Defining"}],"tags":[{"id":"1162","name":"Accidents","namePath":"Themes > Accidents","weight":"Defining"}],"authors":[{"id":"a1","name":"Kamome Shirahama","slug":"kamome","type":"Author"}],"chapters":[{"id":"WK_m4l","scanlationMangaId":"cmrs_1","title":"Chapter 97","number":97,"createdAt":1784516183090,"index":129,"pageCount":26,"progress":null}],"recommendations":[{"id":"2VgNt","title":"Rec Title","image":"posters/r.jpg","smallImage":"posters/r-small.avif","mediumImage":"posters/r-medium.avif","largeImage":"posters/r-large.avif","isAdult":false,"type":"Manga","medium":"Comic","mbRating":8.0,"views":"1.0M"}],"similarManga":[],"relations":[{"type":"SpinOff","manga":{"id":"2VgNt","title":"Rec Title","image":"posters/r.jpg","smallImage":"posters/r-small.avif","mediumImage":"posters/r-medium.avif","largeImage":"posters/r-large.avif","isAdult":false,"type":"Manga","medium":"Comic","mbRating":8.0}}],"startReading":null}}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/manga/page")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/manga/page")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveMangaRepository(client: client)
        let page = try await repo.page(id: "x")
        #expect(page.title == "Witch Hat Atelier")
        #expect(page.chapters.count == 1)
        #expect(page.chapters.first?.scanlationMangaId == "cmrs_1")
        #expect(page.recommendations.first?.title == "Rec Title")
        #expect(page.banner?.aspectRatio == 4.75)
        #expect(page.relations.first?.type == "SpinOff")
    }

    @Test func mangaPageToleratesMalformedNestedContent() async throws {
        // relations key missing entirely; genres contains a NON-OBJECT element
        // (element-skip); one tag with null name (leaf-tolerance); poster null;
        // a chapter with numeric scanlation id (leaf-tolerance).
        let json = """
        {"mangaPage":{"id":"m1","title":"T",
          "genres":["Action",{"id":"g2","name":"Drama"},{"id":"g3","name":null}],
          "tags":[],
          "authors":[{"id":"a1","name":"A"}],
          "chapters":[{"id":"c1","title":"Ch 1","number":1,"pageCount":5,
                       "scanlationMangaId":42,"createdAt":1787336992131}],
          "recommendations":[{"id":"r1","title":null,"image":"posters/x.jpg"}],
          "poster":null}}
        """
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/manga/page")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveMangaRepository(client: client)
        let page = try await repo.page(id: "m1")
        #expect(page.title == "T")
        #expect(page.genres.count == 2)              // "Action" skipped; null-name tag decoded (name "")
        #expect(page.chapters.count == 1)            // numeric scanlation id tolerated
        #expect(page.chapters[0].scanlationMangaId == nil)
        #expect(page.recommendations.count == 1)     // null title decoded as ""
        #expect(page.recommendations[0].title == "")
        #expect(page.relations.isEmpty)              // missing key tolerated
        #expect(page.poster == nil)
    }

    @Test func chaptersDecodesISOCreatedAt() async throws {
        let json = #"{"chapters":[{"id":"QFpTs","title":"Chapter 97","number":97,"index":98,"pageCount":26,"createdAt":"2026-06-10T00:03:06.716Z"},{"id":"NoFrac","title":"Chapter 96","number":96,"index":97,"pageCount":26,"createdAt":"2026-06-10T00:03:06Z"}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/manga/chapters")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/manga/chapters")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveMangaRepository(client: client)
        let chapters = try await repo.chapters(id: "x", page: 1)
        #expect(chapters.count == 2)
        #expect(chapters.first?.id == "QFpTs")
        #expect(chapters.first?.createdAt == 1781049786716)
        #expect(chapters.last?.id == "NoFrac")
        #expect(chapters.last?.createdAt == 1781049786000)
    }
}