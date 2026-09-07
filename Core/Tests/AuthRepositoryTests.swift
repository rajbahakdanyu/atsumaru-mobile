import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct AuthRepositoryTests {
    private typealias StubURLProtocol = AuthStubURLProtocol

    @Test func meReturnsNilForGuest() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/auth/me")
            #expect(request.httpMethod == "GET")
            guard request.url?.path == "/api/auth/me" else {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/auth/me")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"me":null}"#.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = InMemoryKeychainStore()
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        let me = try await repo.me()
        #expect(me == nil)
        #expect(keychain.load(key: "auth-user") == nil)
    }

    @Test func meDeletesStaleKeychainBlobWhenServerSaysLoggedOut() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            guard request.url?.path == "/api/auth/me" else {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/auth/me")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"me":null}"#.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = InMemoryKeychainStore()
        try keychain.save(Data(#"{"id":"u1"}"#.utf8), key: "auth-user")
        defer { try? keychain.delete(key: "auth-user") }
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        let me = try await repo.me()
        #expect(me == nil)
        #expect(keychain.load(key: "auth-user") == nil)
    }

    @Test func mePersistsUserWhenAuthed() async throws {
        let json = #"{"me":{"id":"u1","usernameDisplay":"dan","usernameSlug":"dan","email":"dan@e.x","premium":true,"rep":5,"pfp":"pfp/abc.webp"}}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/auth/me")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = InMemoryKeychainStore()
        defer { try? keychain.delete(key: "auth-user") }
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        let me = try await repo.me()
        #expect(me?.id == "u1")
        #expect(me?.username == "dan")
        #expect(me?.avatarUrl == "pfp/abc.webp")
        #expect(me?.premium == true)
        #expect(me?.rep == 5)
        let stored = keychain.load(key: "auth-user")
        #expect(stored != nil)
        let decoded = try JSONDecoder().decode(AuthUser.self, from: try #require(stored))
        #expect(decoded.id == "u1")
    }

    @Test func loginPostsFormFields() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/api/auth/login":
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
                captured.value = requestBody(of: request)
                let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/auth/login")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data(#"{"status":"success","me":{"id":"u1","username":"dan"}}"#.utf8))
            default:
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
        }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = InMemoryKeychainStore()
        defer { try? keychain.delete(key: "auth-user") }
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        let user = try await repo.login(identifier: "user@example.com", password: "p@ss&word=1")

        #expect(user.id == "u1")
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString.contains("username="))
        #expect(bodyString.contains("password="))
        #expect(bodyString.contains("user@example.com"))
        #expect(bodyString.contains("p@ss%26word%3D1"))
    }

    @Test func loginThrowsOnInvalidCredentials() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/auth/login")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"status":"error","error":"Invalid username or password","me":null}"#.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = InMemoryKeychainStore()
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        await #expect(throws: ApiError.server("Invalid username or password")) {
            _ = try await repo.login(identifier: "bad", password: "wrong")
        }
    }

    @Test func logoutClearsLocalSessionWhenOffline() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = InMemoryKeychainStore()
        try keychain.save(Data(#"{"id":"u1"}"#.utf8), key: "auth-user")
        defer { try? keychain.delete(key: "auth-user") }
        let cookie = try #require(HTTPCookie(properties: [
            .domain: ".atsu.moe", .path: "/", .name: "session", .value: "test",
            .secure: "TRUE"
        ]))
        defer { HTTPCookieStorage.shared.deleteCookie(cookie) }
        HTTPCookieStorage.shared.setCookie(cookie)
        let repo = LiveAuthRepository(client: client, keychain: keychain)

        await #expect(throws: ApiError.offline) {
            try await repo.logout()
        }

        #expect(keychain.load(key: "auth-user") == nil)
        #expect(!(HTTPCookieStorage.shared.cookies ?? []).contains { $0.name == "session" && $0.domain == ".atsu.moe" })
    }

    @Test func postFormPercentEncodesAmpersandAndEqualsInValues() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthStubURLProtocol.self]
        let captured = Box<Data?>(nil)
        AuthStubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
            captured.value = requestBody(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/x")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let _: EmptyResponse = try await client.postForm("/x", fields: ["b": "2", "a": "1&x=y"])
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString == "a=1%26x%3Dy&b=2")
    }

    @Test func passwordResetEndpointsPostExpectedFormFields() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthStubURLProtocol.self]
        let requests = Box<[(String, String)]>([])
        AuthStubURLProtocol.handler = { request in
            let body = String(decoding: requestBody(of: request) ?? Data(), as: UTF8.self)
            requests.value.append((request.url?.path ?? "", body))
            let response = HTTPURLResponse(
                url: try #require(request.url), statusCode: 204,
                httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }
        let repository = LiveAuthRepository(
            client: APIClient(session: URLSession(configuration: config)),
            keychain: InMemoryKeychainStore()
        )

        try await repository.sendPasswordReset(email: "user+test@example.com")
        try await repository.resetPassword(
            token: "token&1", newPassword: "new=pass", confirmPassword: "new=pass"
        )

        #expect(requests.value.count == 2)
        #expect(requests.value[0].0 == "/api/auth/sendPasswordReset/sendPasswordReset")
        #expect(requests.value[0].1 == "email=user%2Btest@example.com")
        #expect(requests.value[1].0 == "/api/auth/resetPassword/reset")
        #expect(requests.value[1].1.contains("token=token%261"))
        #expect(requests.value[1].1.contains("newPassword=new%3Dpass"))
        #expect(requests.value[1].1.contains("confirmPassword=new%3Dpass"))
    }
}