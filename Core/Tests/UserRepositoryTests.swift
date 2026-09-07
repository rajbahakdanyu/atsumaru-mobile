import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct UserRepositoryTests {
    private typealias StubURLProtocol = UserStubURLProtocol

    @Test func privateProfileDecodes() async throws {
        let json = #"{"profilePage":{"user":{"id":"u1","username":"dan","usernameSlug":"dan","reputation":5,"pfp":"pfp/dan.webp","mangaRead":42,"chaptersRead":900,"bookmarkCount":13,"commentCount":87}}}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/privateProfile")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/privateProfile")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        let profile = try await repo.privateProfile()
        #expect(profile.id == "u1")
        #expect(profile.username == "dan")
        #expect(profile.rep == 5)
        #expect(profile.avatarUrl == "pfp/dan.webp")
        #expect(profile.countMangaRead == 42)
        #expect(profile.countChaptersRead == 900)
        #expect(profile.countBookmarks == 13)
        #expect(profile.countComments == 87)
    }
}
