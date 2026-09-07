import Foundation
import Testing
@testable import Core

class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let handlerLock = NSLock()
    nonisolated(unsafe) private static var handlers: [ObjectIdentifier: Handler] = [:]

    class var handler: Handler? {
        get {
            handlerLock.lock()
            defer { handlerLock.unlock() }
            return handlers[ObjectIdentifier(self)]
        }
        set {
            handlerLock.lock()
            handlers[ObjectIdentifier(self)] = newValue
            handlerLock.unlock()
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = type(of: self).handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        do {
            let (resp, data) = try handler(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: T

    var value: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }

    init(_ value: T) { storedValue = value }
}

final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func save(_ data: Data, key: String) throws {
        lock.lock()
        values[key] = data
        lock.unlock()
    }

    func load(key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func delete(key: String) throws {
        lock.lock()
        values[key] = nil
        lock.unlock()
    }
}

@MainActor
final class FailingDownloadStore: DownloadStoring {
    func save(_ snapshot: DownloadedChapterSnapshot) throws { throw TestStoreError.saveFailed }
    func all() -> [DownloadedChapterSnapshot] { [] }
    func delete(chapterId: String) throws {}

    enum TestStoreError: Error { case saveFailed }
}

final class AuthStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class CommentsStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class DownloadStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class ForumStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class LibraryStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class APIClientStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class BrowseStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class HomeStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class MangaStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class NovelStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class ReadStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
final class UserStubURLProtocol: StubURLProtocol, @unchecked Sendable {}
/// Reads a request body from `httpBody` or, for streamed bodies, drains
/// `httpBodyStream` so form/JSON payloads can be asserted in StubURLProtocol
/// tests without a live connection.
func requestBody(of request: URLRequest) -> Data? {
    if let data = request.httpBody { return data }
    guard let stream = request.httpBodyStream else { return nil }
    var data = Data()
    stream.open()
    let capacity = 4096
    let maximumBodySize = 1_048_576
    var buffer = [UInt8](repeating: 0, count: capacity)
    while stream.hasBytesAvailable, data.count < maximumBodySize {
        let read = stream.read(&buffer, maxLength: capacity)
        if read > 0 {
            data.append(&buffer, count: read)
        } else {
            break
        }
    }
    stream.close()
    return data.count < maximumBodySize ? data : nil
}

func jsonDictionary(from data: Data?) throws -> [String: Any] {
    let data = try #require(data)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
