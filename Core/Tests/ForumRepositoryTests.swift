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
            #expect(items.contains(URLQueryItem(name: "adult", value: "1")))
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

    @Test func channelsOmitAdultParamWhenDisabled() async throws {
        let json = #"{"channels":[]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.first(where: { $0.name == "adult" }) == nil)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/forums/channels")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        let channels = try await repo.channels(includeAdult: false)
        #expect(channels.isEmpty)
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

    @Test func postsDecodeLiveShape() async throws {
        let json = #"{"posts":[{"id":"p9","forumId":"cms0","type":"discussion","title":"UXORIOUS","content":"body","createdAt":1787336992131,"score":12,"upVotes":15,"downVotes":3,"pinned":false,"locked":false,"commentCount":4,"author":{"id":"a1","usernameSlug":"lazyreader","usernameDisplay":"LazyReader","pfp":"pfp/x.webp"}}],"hasMore":false}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/posts")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/posts")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        let posts = try await repo.posts(forumId: "cms0", sort: nil, page: 0, tagId: nil)
        #expect(posts.count == 1)
        #expect(posts.first?.user?.username == "LazyReader")
        #expect(posts.first?.user?.avatarUrl == "pfp/x.webp")
        #expect(posts.first?.createdAt == 1787336992131)
        #expect(posts.first?.createdAtDate == Date(timeIntervalSince1970: 1787336992.131))
        #expect(posts.first?.score == 12)
        #expect(posts.first?.upvotes == 15)
        #expect(posts.first?.downvotes == 3)
        #expect(posts.first?.commentCount == 4)
    }

    @Test func createPostPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/createPost")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/createPost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        try await repo.createPost(
            forumId: "ch1", title: "Hello world", content: "# Hi",
            spoiler: false, tagIds: ["t1", "t2"]
        )
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"forumId\":\"ch1\""))
        #expect(bodyString.contains("\"title\":\"Hello world\""))
        #expect(bodyString.contains("\"content\":\"# Hi\""))
        #expect(bodyString.contains("\"spoiler\":false"))
        #expect(bodyString.contains("\"tagIds\":[\"t1\",\"t2\"]"))
    }

    @Test func postsFilterParamsPassedAsQuery() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/posts")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "forumId", value: "ch1")))
            #expect(items.contains(URLQueryItem(name: "sort", value: "new")))
            #expect(items.contains(URLQueryItem(name: "page", value: "0")))
            #expect(items.contains(URLQueryItem(name: "tagId", value: "t9")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/posts")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"posts":[]}"#.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        let posts = try await repo.posts(forumId: "ch1", sort: "new", page: 0, tagId: "t9")
        #expect(posts.isEmpty)
    }

    @Test func editPostPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/editPost")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/editPost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        try await repo.editPost(postId: "p1", title: "Edited title", content: "Edited body")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"postId\":\"p1\""))
        #expect(bodyString.contains("\"title\":\"Edited title\""))
        #expect(bodyString.contains("\"content\":\"Edited body\""))
    }

    @Test func removePostPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/removePost")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/removePost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        try await repo.removePost(postId: "p1")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"postId\":\"p1\""))
    }

    @Test func votePostPostsVoteDirectionStrings() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/forum/votePost")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/votePost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        try await repo.votePost(postId: "p1", vote: 1)
        var bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"postId\""))
        #expect(bodyString.contains("\"p1\""))
        #expect(bodyString.contains("\"vote\":\"up\""))

        try await repo.votePost(postId: "p1", vote: -1)
        bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"vote\":\"down\""))

        try await repo.votePost(postId: "p1", vote: 0)
        bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"vote\":\"none\""))
    }

    @Test func postDecodesViewerState() async throws {
        let json = #"{"post":{"id":"p1","forumId":"ch1","title":"T","score":3,"viewerVote":"up","viewerBookmarked":true,"viewerSeen":true}}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/forum/getPost")!,
                                        statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveForumRepository(client: client)
        let post = try await repo.post(postId: "p1")
        #expect(post.viewerVote == "up")
        #expect(post.viewerBookmarked == true)
    }
}