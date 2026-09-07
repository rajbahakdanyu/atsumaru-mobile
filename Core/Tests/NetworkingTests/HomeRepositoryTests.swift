import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct HomeRepositoryTests {
    private typealias StubURLProtocol = HomeStubURLProtocol

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

    @Test func pagedPopularRailSendsPaginationAndTimeframe() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == HomeEndpoint.popular.path)
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "offset", value: "30")))
            #expect(items.contains(URLQueryItem(name: "limit", value: "15")))
            #expect(items.contains(URLQueryItem(name: "timeframe", value: "all")))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"items":[]}"#.utf8))
        }
        let repository = LiveHomeRepository(
            client: APIClient(session: URLSession(configuration: config))
        )

        #expect(try await repository.rail(.popular, offset: 30, limit: 15).items.isEmpty)
    }
}