import Foundation
import Testing
@testable import Core

struct APIClientTests {
    @Test func imageURLsAreAbsolute() {
        #expect(ImageURLBuilder.poster("posters/abc.jpg")?.absoluteString == "https://atsu.moe/posters/abc.jpg")
        #expect(ImageURLBuilder.page("/static/pages/x/1.webp")?.absoluteString == "https://atsu.moe/static/pages/x/1.webp")
    }

    @Test func homeEndpointsHavePaths() {
        #expect(HomeEndpoint.popular.path == "/api/home2/popular")
        #expect(HomeEndpoint.recentlyUpdated.path == "/api/home2/recentlyUpdated")
    }

    @Test func postVoidSucceedsOnEmptyBody() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/read/updateProgress")
            #expect(request.httpMethod == "POST")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/read/updateProgress")!,
                                       statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = APIClient(session: URLSession(configuration: config))
        struct Body: Encodable { let value: Int }
        try await client.postVoid("/api/read/updateProgress", json: Body(value: 1))
    }

    @Test func postVoidStillThrowsOnServerError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/read/updateProgress")!,
                                       statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = APIClient(session: URLSession(configuration: config))
        struct Body: Encodable { let value: Int }
        await #expect(throws: ApiError.http(500)) {
            try await client.postVoid("/api/read/updateProgress", json: Body(value: 1))
        }
    }
}