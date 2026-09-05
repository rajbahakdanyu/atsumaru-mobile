import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct CommentsRepositoryTests {

    @Test func threadsDecode() async throws {
        let json = #"{"comments":[{"id":"cmt1","content":"Mc reminds me of Seo Eun Hyun","createdAt":1787304830269,"score":1,"upVotes":null,"downVotes":null,"spoiler":false,"parentId":null,"user":{"id":"u1","usernameSlug":"hobin001","usernameDisplay":"HOBIN001","pfp":"pfp/abc.webp","verified":true},"replies":[]}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/comments/v2/threads")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "sectionId", value: "sec1")))
            #expect(items.contains(URLQueryItem(name: "maxDepth", value: "3")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/comments/v2/threads")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommentsRepository(client: client)
        let threads = try await repo.threads(sectionId: "sec1", parentId: nil, cursor: nil, sort: nil)
        #expect(threads.count == 1)
        #expect(threads.first?.id == "cmt1")
        #expect(threads.first?.user?.username == "HOBIN001")
        #expect(threads.first?.user?.avatarUrl == "pfp/abc.webp")
        #expect(threads.first?.createdAt == 1787304830269)
        #expect(threads.first?.createdAtDate == Date(timeIntervalSince1970: 1787304830.269))
        #expect(threads.first?.score == 1)
        #expect(threads.first?.spoiler == false)
    }

    @Test func threadsDecodeBareArrayToleratesLegacyFields() async throws {
        let json = #"[{"id":"c2","content":"plain array","user":{"id":"u2","username":"bob"},"createdAt":"2024-01-01T00:00:00.000Z","upvotes":2,"downvotes":1,"spoiler":true}]"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/comments/v2/threads")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/comments/v2/threads")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommentsRepository(client: client)
        let threads = try await repo.threads(sectionId: "sec2", parentId: nil, cursor: nil, sort: nil)
        #expect(threads.count == 1)
        #expect(threads.first?.id == "c2")
        #expect(threads.first?.spoiler == true)
        #expect(threads.first?.user?.username == "bob")
        #expect(threads.first?.upvotes == 2)
    }

    @Test func postCommentPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/comments/v2/postComment")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/comments/v2/postComment")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommentsRepository(client: client)
        try await repo.postComment(sectionId: "sec1", parentId: "p0", replyingToId: "r0",
                                   content: "Nice chapter", spoiler: false)
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"sectionId\""))
        #expect(bodyString.contains("\"content\""))
        #expect(bodyString.contains("\"spoiler\""))
        #expect(bodyString.contains("Nice chapter"))
    }

    @Test func votePostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/comments/v2/vote")
            #expect(request.httpMethod == "POST")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/comments/v2/vote")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommentsRepository(client: client)
        try await repo.vote(commentId: "c1", vote: 1)
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"commentId\""))
        #expect(bodyString.contains("\"vote\""))
        #expect(bodyString.contains("c1"))
        #expect(bodyString.contains("1"))
    }

    @Test func paragraphCommentSectionDecodes() async throws {
        let json = #"{"id":"sec9","comments":[{"id":"c3","content":"para comment","user":{"id":"u3","username":"carol"},"spoiler":false}],"count":1}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/comments/commentSections/getParagraphCommentSection")
            #expect(request.httpMethod == "GET")
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(items.contains(URLQueryItem(name: "chapterId", value: "ch1")))
            #expect(items.contains(URLQueryItem(name: "paragraph", value: "3")))
            #expect(items.contains(URLQueryItem(name: "create", value: "true")))
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/comments/commentSections/getParagraphCommentSection")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveCommentsRepository(client: client)
        let section = try await repo.paragraphCommentSection(chapterId: "ch1", paragraph: 3, create: true)
        #expect(section.id == "sec9")
        #expect(section.count == 1)
        #expect(section.comments?.first?.id == "c3")
        #expect(section.comments?.first?.user?.username == "carol")
    }
}