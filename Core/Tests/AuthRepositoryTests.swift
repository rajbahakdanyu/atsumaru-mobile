import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct KeychainStoreTests {
    @Test func saveLoadDeleteRoundTrip() throws {
        let store = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let key = "test-key-\(UUID().uuidString)"
        defer { try? store.delete(key: key) }

        let payload = Data("hello-atsumaru".utf8)
        #expect(store.load(key: key) == nil)

        try store.save(payload, key: key)
        #expect(store.load(key: key) == payload)

        try store.delete(key: key)
        #expect(store.load(key: key) == nil)
    }

    @Test func saveOverwritesExistingValue() throws {
        let store = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let key = "overwrite-\(UUID().uuidString)"
        defer { try? store.delete(key: key) }

        try store.save(Data("first".utf8), key: key)
        try store.save(Data("second".utf8), key: key)
        #expect(store.load(key: key) == Data("second".utf8))
        try store.delete(key: key)
    }

    @Test func deleteIsIdempotentWhenAbsent() throws {
        let store = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let key = "absent-\(UUID().uuidString)"
        try store.delete(key: key)
        try store.delete(key: key)
        #expect(store.load(key: key) == nil)
    }
}

@Suite(.serialized) struct AuthRepositoryTests {
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
        let keychain = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        let me = try await repo.me()
        #expect(me == nil)
        #expect(keychain.load(key: "auth-user") == nil)
    }

    @Test func mePersistsUserWhenAuthed() async throws {
        let json = #"{"me":{"id":"u1","username":"dan","usernameSlug":"dan","email":"dan@e.x","premium":true,"rep":5}}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/auth/me")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        defer { try? keychain.delete(key: "auth-user") }
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        let me = try await repo.me()
        #expect(me?.id == "u1")
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
                captured.value = AuthRepositoryTests.body(of: request)
                let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/auth/login")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data(#"{"status":"success","me":{"id":"u1","username":"dan"}}"#.utf8))
            default:
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
        }
        let client = APIClient(session: URLSession(configuration: config))
        let keychain = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
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
        let keychain = KeychainStore(service: "dev.atsumaru.app.tests.\(UUID().uuidString)")
        let repo = LiveAuthRepository(client: client, keychain: keychain)
        await #expect(throws: ApiError.self) {
            _ = try await repo.login(identifier: "bad", password: "wrong")
        }
    }

    @Test func postFormPercentEncodesAmpersandAndEqualsInValues() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let captured = Box<Data?>(nil)
        StubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
            captured.value = AuthRepositoryTests.body(of: request)
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/x")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{}".utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let _: EmptyResponse = try await client.postForm("/x", fields: ["b": "2", "a": "1&x=y"])
        let bodyString = String(decoding: try #require(captured.value), as: UTF8.self)
        #expect(bodyString == "a=1%26x%3Dy&b=2")
    }
}

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

private extension AuthRepositoryTests {
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