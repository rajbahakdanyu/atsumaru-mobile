import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct NovelRepositoryTests {
    private typealias StubURLProtocol = NovelStubURLProtocol

    @Test func novelChapterDecodesParagraphsAndComments() async throws {
        let json = ##"{"readNovelChapter":{"id":"abc1","title":"Chapter 1: Awakening","number":1,"scanlationMangaId":"cmrs_n1","paragraphs":["# Chapter 1: Awakening","The morning sun crested over the hills.","\"Hold on,\" she whispered."],"wordCount":412,"paragraphComments":{"0":1,"2":3}}}"##
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/read/novelChapter")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "mangaId", value: "x")))
            #expect(items.contains(URLQueryItem(name: "chapterId", value: "abc1")))
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/read/novelChapter")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveNovelRepository(client: client)
        let chapter = try await repo.novelChapter(mangaId: "x", chapterId: "abc1")
        #expect(chapter.id == "abc1")
        #expect(chapter.title == "Chapter 1: Awakening")
        #expect(chapter.number == 1)
        #expect(chapter.scanlationMangaId == "cmrs_n1")
        #expect(chapter.paragraphs.count == 3)
        #expect(chapter.paragraphs.first == "# Chapter 1: Awakening")
        #expect(chapter.wordCount == 412)
        #expect(chapter.paragraphComments?["0"] == 1)
        #expect(chapter.paragraphComments?["2"] == 3)
    }
}