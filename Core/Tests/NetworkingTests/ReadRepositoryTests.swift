import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct ReadRepositoryTests {
    @Test func chapterDecodesReadChapterWithPages() async throws {
        let json = #"{"readChapter":{"id":"QFpTs","title":"Chapter 97","scanlationMangaId":"cmrs_1","pages":[{"id":"QFpTs-0","image":"/static/pages/scan/QFpTs/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696},{"id":"QFpTs-1","image":"/static/pages/scan/QFpTs/1.webp","number":1,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/read/chapter")
            #expect(request.url?.query == "mangaId=m1&chapterId=QFpTs")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/read/chapter")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveReadRepository(client: client)
        let chapter = try await repo.chapter(mangaId: "m1", chapterId: "QFpTs")
        #expect(chapter.id == "QFpTs")
        #expect(chapter.title == "Chapter 97")
        #expect(chapter.scanlationMangaId == "cmrs_1")
        #expect(chapter.pages.count == 2)
        #expect(chapter.pages.first?.id == "QFpTs-0")
        #expect(chapter.pages.first?.image == "/static/pages/scan/QFpTs/0.webp")
        #expect(chapter.pages.first?.aspectRatio == 0.696)
    }

    @Test func updateProgressPostsProgressBody() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/read/updateProgress")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let body = try #require(Self.body(of: request))
            let payload = try JSONDecoder().decode(ProgressBodyPayload.self, from: body)
            let p = payload.progress
            #expect(p.mangaScanlationId == "cmrs_1")
            #expect(p.mangaId == "m1")
            #expect(p.chapterId == "QFpTs")
            #expect(p.page == 4)
            #expect(p.pages == 26)
            #expect(p.strip == false)
            #expect(p.nextChapterId == nil as String?)
            #expect(p.ts > 0)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/read/updateProgress")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveReadRepository(client: client)
        let update = ProgressUpdate(mangaScanlationId: "cmrs_1", mangaId: "m1", chapterId: "QFpTs",
                                    page: 4, frac: 0.192, pages: 26, ts: 1_700_000_000_000,
                                    strip: false, nextChapterId: nil, readMs: 0)
        try await repo.updateProgress(update)
    }
}

private struct ProgressBodyPayload: Decodable {
    let progress: ProgressPayload
}

private struct ProgressPayload: Decodable {
    let mangaScanlationId: String
    let mangaId: String
    let chapterId: String
    let page: Int
    let frac: Double
    let pages: Int
    let ts: Int
    let strip: Bool
    let nextChapterId: String?
    let readMs: Int
}

private extension ReadRepositoryTests {
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