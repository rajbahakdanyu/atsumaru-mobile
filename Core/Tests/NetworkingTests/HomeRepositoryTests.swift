import Foundation
import Testing
@testable import Core

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        do {
            let (resp, data) = try handler(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite(.serialized) struct HomeRepositoryTests {
    @Test func railDecodes() async throws {
        let json = #"{"items":[{"id":"2VgNt","title":"Witch Hat Atelier","image":"posters/a.jpg","smallImage":"posters/a-small.avif","mediumImage":"posters/a-medium.avif","largeImage":"posters/a-large.avif","isAdult":false,"type":"Manga","medium":"Comic","mbRating":8.4,"views":"14.8M"}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/home2/popular")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveHomeRepository(client: client)
        let rail = try await repo.rail(.popular)
        #expect(rail.items.first?.title == "Witch Hat Atelier")
        #expect(rail.items.first?.id == "2VgNt")
    }

    @Test func railDecodesWhenRatingIsNull() async throws {
        let json = #"{"items":[{"id":"a","title":"No Rating","image":"posters/a.jpg","smallImage":"posters/a-small.avif","mediumImage":"posters/a-medium.avif","largeImage":"posters/a-large.avif","isAdult":false,"type":"Manga","medium":"Comic","mbRating":null,"views":"465"}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { _ in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/home2/recentlyUpdated")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveHomeRepository(client: client)
        let rail = try await repo.rail(.recentlyUpdated)
        #expect(rail.items.count == 1)
        #expect(rail.items.first?.mbRating == nil)
    }
}