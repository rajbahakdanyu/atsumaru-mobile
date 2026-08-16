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
}