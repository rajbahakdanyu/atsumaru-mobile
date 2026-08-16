import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct UserRepositoryTests {
    @Test func privateProfileDecodes() async throws {
        let json = #"{"id":"u1","username":"dan","usernameSlug":"dan","email":"dan@e.x","premium":true,"rep":5,"avatarUrl":"/avatars/dan.png","countMangaRead":42,"countChaptersRead":900,"countFollowing":13,"countFollowers":87}"#
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
        #expect(profile.premium == true)
        #expect(profile.rep == 5)
        #expect(profile.countMangaRead == 42)
    }

    @Test func changeUsernamePostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/settings/changeUsername")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            captured.value = UserRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/settings/changeUsername")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        try await repo.changeUsername("newname")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"username\""))
        #expect(bodyString.contains("newname"))
    }

    @Test func changeEmailPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/settings/changeEmail")
            #expect(request.httpMethod == "POST")
            captured.value = UserRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/settings/changeEmail")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        try await repo.changeEmail(email: "new@e.x", password: "secret")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"email\""))
        #expect(bodyString.contains("\"password\""))
    }

    @Test func changePasswordPostsJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/settings/changePassword")
            #expect(request.httpMethod == "POST")
            captured.value = UserRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/settings/changePassword")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        try await repo.changePassword(oldPassword: "old", newPassword: "new")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("\"oldPassword\""))
        #expect(bodyString.contains("\"newPassword\""))
    }

    @Test func notificationPreferencesDecodes() async throws {
        let json = #"{"newChapter":true,"follow":false,"comment":true}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/notificationPreferences")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/notificationPreferences")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        let prefs = try await repo.notificationPreferences()
        #expect(prefs.keys["newChapter"] == true)
        #expect(prefs.keys["follow"] == false)
        #expect(prefs.keys["comment"] == true)
    }

    @Test func updateNotificationPreferencesPUTSBody() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        let capturedMethod = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/user/notificationPreferences")
            capturedMethod.value = request.httpMethod
            captured.value = UserRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/user/notificationPreferences")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        let prefs = NotificationPreferences(keys: ["newChapter": true])
        try await repo.updateNotificationPreferences(prefs)
        #expect(capturedMethod.value == "PUT")
        let roundtrip = try JSONDecoder().decode([String: Bool].self, from: try #require(captured.value))
        #expect(roundtrip["newChapter"] == true)
    }

    @Test func notificationsListDecodes() async throws {
        let json = #"{"items":[{"id":"n1","type":"newChapter","title":"New chapter","body":"Ch. 97 is out"}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/notifications/page")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/notifications/page")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        let list = try await repo.notifications()
        #expect(list.count == 1)
        #expect(list.first?.id == "n1")
        #expect(list.first?.title == "New chapter")
    }

    @Test func notificationCountDecodes() async throws {
        let json = #"{"count":3}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/notifications/count")
            #expect(request.httpMethod == "GET")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/notifications/count")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        let count = try await repo.notificationCount()
        #expect(count == 3)
    }

    @Test func markAllNotificationsReadPosts() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let capturedMethod = Box<String?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/notifications/markAllAsRead")
            capturedMethod.value = request.httpMethod
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/notifications/markAllAsRead")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveUserRepository(client: client)
        try await repo.markAllNotificationsRead()
        #expect(capturedMethod.value == "POST")
    }
}

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

private extension UserRepositoryTests {
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