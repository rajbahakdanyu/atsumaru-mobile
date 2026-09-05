import Foundation
import Testing
@testable import Core

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
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
    var value: T
    init(_ value: T) { self.value = value }
}

/// Reads a request body from `httpBody` or, for streamed bodies, drains
/// `httpBodyStream` so form/JSON payloads can be asserted in StubURLProtocol
/// tests without a live connection.
func requestBody(of request: URLRequest) -> Data? {
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
