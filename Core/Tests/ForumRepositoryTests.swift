import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct ForumRepositoryTests {

    @Test func channelsDecode() async throws {
        let json = #"{"channels":[{"id":"ch1","name":"General","description":"Talk about anything","postCount":42}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/forums/channels")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "adult", value: "true")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/forums/channels")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        let channels = try await repo.channels(includeAdult: true)
        #expect(channels.count == 1)
        #expect(channels.first?.id == "ch1")
        #expect(channels.first?.name == "General")
        #expect(channels.first?.postCount == 42)
    }

    @Test func postDecodesTolerantEnvelope() async throws {
        let json = #"{"post":{"id":"p1","forumId":"ch1","type":"discussion","title":"Hello world","content":"Hi body","upvotes":5,"downvotes":1}}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/getPost")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "postId", value: "p1")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/getPost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        let post = try await repo.post(postId: "p1")
        #expect(post.id == "p1")
        #expect(post.title == "Hello world")
        #expect(post.forumId == "ch1")
        #expect(post.upvotes == 5)
    }

    @Test func createPostPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/createPost")
            #expect(request.httpMethod == "POST")
            captured.value = ForumRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/createPost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        try await repo.createPost(forumId: "ch1", title: "Hello world", content: "# Hi")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"forumId\""))
        #expect(bodyString.contains("\"title\""))
        #expect(bodyString.contains("\"content\""))
        #expect(bodyString.contains("ch1"))
        #expect(bodyString.contains("Hello world"))
    }

    @Test func votePostPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/votePost")
            #expect(request.httpMethod == "POST")
            captured.value = ForumRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/votePost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        try await repo.votePost(postId: "p1", vote: 1)
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"postId\""))
        #expect(bodyString.contains("\"vote\""))
        #expect(bodyString.contains("p1"))
        #expect(bodyString.contains("1"))
    }
}

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

private extension ForumRepositoryTests {
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