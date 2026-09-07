import Foundation
import Testing
@testable import Core

struct APIClientTests {
    @Test func imageURLsAreAbsolute() {
        #expect(ImageURLBuilder.poster("posters/abc.jpg")?.absoluteString == "https://atsu.moe/static/posters/abc.jpg")
        #expect(ImageURLBuilder.poster("banners/b.jpg")?.absoluteString == "https://atsu.moe/static/banners/b.jpg")
        #expect(ImageURLBuilder.poster("/static/posters/c.jpg")?.absoluteString == "https://atsu.moe/static/posters/c.jpg")
        #expect(ImageURLBuilder.page("/static/pages/x/1.webp")?.absoluteString == "https://atsu.moe/static/pages/x/1.webp")
        #expect(ImageURLBuilder.page("@evil.example/x")?.host != "evil.example")
        #expect(ImageURLBuilder.page(":443@evil.example/x")?.host != "evil.example")
        #expect(ImageURLBuilder.page("https://cdn.atsu.moe/pages/x.webp")?.host == "cdn.atsu.moe")
    }

    @Test func avatarURLsPinAtsumoeHost() {
        #expect(ImageURLBuilder.avatar("https://atsu.moe/pfp/x.webp")?.absoluteString == "https://atsu.moe/pfp/x.webp")
        #expect(ImageURLBuilder.avatar("https://cdn.atsu.moe/pfp/x.webp")?.absoluteString == "https://cdn.atsu.moe/pfp/x.webp")
        #expect(ImageURLBuilder.avatar("https://atsu.moe.evil.com/x.jpg") == nil)
        #expect(ImageURLBuilder.avatar("https://atsu.moe@evil.example/x.jpg") == nil)
    }

    @Test func avatarURLsRejectAttackerHTTPAndEmptyInput() {
        #expect(ImageURLBuilder.avatar("https://evil.example/x.jpg") == nil)
        #expect(ImageURLBuilder.avatar("http://evil.example/x.jpg") == nil)
        #expect(ImageURLBuilder.avatar("http://atsu.moe/pfp/x.webp") == nil)
        #expect(ImageURLBuilder.avatar("pfp/abc.webp")?.absoluteString == "https://atsu.moe/pfp/abc.webp")
        #expect(ImageURLBuilder.avatar("") == nil)
        #expect(ImageURLBuilder.avatar(nil) == nil)
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

    @Test func formEncodeSortsKeysAndEncodesReservedCharacters() {
        let encoded = APIClient.formEncode([
            "password": "a&b=c+d",
            "email": "user@example.com"
        ])
        // `@` is in `urlQueryAllowed`, so it stays literal; `&=+` are encoded.
        #expect(encoded == "email=user@example.com&password=a%26b%3Dc%2Bd")
    }

    @Test func formEncodeHandlesEmptyFields() {
        #expect(APIClient.formEncode([:]) == "")
        #expect(APIClient.formEncode(["a": ""]) == "a=")
    }

    @Test func getMapsOfflineURLError() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let client = APIClient(session: URLSession(configuration: config))
        await #expect(throws: ApiError.offline) {
            let _: EmptyResponse = try await client.get("/api/auth/me")
        }
    }
}