import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct CommunityRepositoryTests {

    @Test func publicProfileDecodes() async throws {
        let json = #"{"id":"u1","username":"dan","usernameSlug":"dan","avatarUrl":"/avatars/dan.png","bio":"hi","rep":5,"isFollowing":false,"countMangaRead":42,"countChaptersRead":900,"followerCount":87,"followingCount":13}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/publicProfile")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "slug", value: "dan")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/publicProfile")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        let profile = try await repo.publicProfile(slug: "dan")
        #expect(profile.id == "u1")
        #expect(profile.username == "dan")
        #expect(profile.followerCount == 87)
        #expect(profile.isFollowing == false)
    }

    @Test func followPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/follow")
            #expect(request.httpMethod == "POST")
            captured.value = CommunityRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/follow")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        try await repo.follow(userId: "u1")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"userId\""))
        #expect(bodyString.contains("u1"))
    }

    @Test func followersDecodesTolerantEnvelope() async throws {
        let json = #"{"users":[{"id":"u2","username":"amy","usernameSlug":"amy","avatarUrl":"/avatars/amy.png"}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/followers")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "slug", value: "dan")))
            #expect(items.contains(URLQueryItem(name: "page", value: "0")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/followers")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        let users = try await repo.followers(slug: "dan", page: 0)
        #expect(users.count == 1)
        #expect(users.first?.id == "u2")
        #expect(users.first?.username == "amy")
    }

    @Test func groupsListDecodesTolerantEnvelope() async throws {
        let json = #"{"groups":[{"id":"g1","name":"Manga Club","tag":"MANGA","type":"open","memberCount":42}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/groups/list")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "page", value: "0")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/groups/list")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        let groups = try await repo.groups(page: 0)
        #expect(groups.count == 1)
        #expect(groups.first?.id == "g1")
        #expect(groups.first?.name == "Manga Club")
        #expect(groups.first?.memberCount == 42)
    }

    @Test func groupsListDecodesBareArray() async throws {
        let json = #"[{"id":"g2","name":"Novel Reads","tag":"NOVEL","type":"open","memberCount":7}]"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/groups/list")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/groups/list")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        let groups = try await repo.groups(page: 0)
        #expect(groups.count == 1)
        #expect(groups.first?.name == "Novel Reads")
    }

    @Test func groupDetailDecodes() async throws {
        let json = #"{"id":"g1","name":"Manga Club","tag":"MANGA","type":"open","memberCount":42,"isMember":true}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/groups/page")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "id", value: "g1")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/groups/page")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        let group = try await repo.group(id: "g1")
        #expect(group.id == "g1")
        #expect(group.name == "Manga Club")
        #expect(group.isMember == true)
    }

    @Test func createGroupPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/groups/create")
            #expect(request.httpMethod == "POST")
            captured.value = CommunityRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/groups/create")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        try await repo.createGroup(name: "Manga Club", tag: "MANGA", type: "open", bio: "We read manga")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"name\""))
        #expect(bodyString.contains("\"tag\""))
        #expect(bodyString.contains("\"type\""))
        #expect(bodyString.contains("\"bio\""))
        #expect(bodyString.contains("Manga Club"))
        #expect(bodyString.contains("MANGA"))
    }

    @Test func joinGroupPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/groups/join")
            #expect(request.httpMethod == "POST")
            captured.value = CommunityRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/groups/join")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        try await repo.joinGroup(id: "g1")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"groupId\""))
        #expect(bodyString.contains("g1"))
    }

    @Test func pollsDecodesTolerantEnvelope() async throws {
        let json = #"{"polls":[{"id":"p1","question":"Best manga?","options":[{"id":"o1","text":"A","voteCount":3},{"id":"o2","text":"B","voteCount":1}]}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/polls/get")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "ids", value: "p1,p2")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/polls/get")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        let polls = try await repo.poll(ids: ["p1", "p2"])
        #expect(polls.count == 1)
        #expect(polls.first?.id == "p1")
        #expect(polls.first?.question == "Best manga?")
        #expect(polls.first?.options?.count == 2)
    }

    @Test func votePollPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/polls/vote")
            #expect(request.httpMethod == "POST")
            captured.value = CommunityRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/polls/vote")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommunityRepository(client: client)
        try await repo.votePoll(pollId: "p1", optionIds: ["o1", "o2"])
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"pollId\""))
        #expect(bodyString.contains("\"optionIds\""))
        #expect(bodyString.contains("p1"))
        #expect(bodyString.contains("o1"))
    }
}

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

private extension CommunityRepositoryTests {
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