import Foundation

public enum ApiError: Error, Equatable {
    case invalidURL
    case http(Int)
    case server(String)
    case decoding
    case offline
}

public final class APIClient: @unchecked Sendable {
    public static let baseURL = URL(string: "https://atsu.moe")!
    private let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSession()
    }

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config)
    }

    /// Maps connectivity-related `URLError` cases to `ApiError.offline` so
    /// callers can distinguish "no connection" from other failures. Any other
    /// error is rethrown unchanged.
    private static func mapTransportError(_ error: Error) -> ApiError {
        guard let urlError = error as? URLError else { return .http(0) }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
             .dataNotAllowed, .internationalRoamingOff:
            return .offline
        default:
            return .http(urlError.code.rawValue)
        }
    }

    /// Performs a request, mapping connectivity failures to `ApiError.offline`.
    private func fetch(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw Self.mapTransportError(error)
        }
    }

    /// Builds a request against `Self.baseURL` with the shared header set.
    private func buildRequest(method: String, path: String, query: [String: String]) throws -> URLRequest {
        guard var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw ApiError.invalidURL
        }
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("atsumaru-ios", forHTTPHeaderField: "User-Agent")
        request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
        return request
    }

    public func get<T: Decodable & Sendable>(
        _ path: String, query: [String: String] = [:]
    ) async throws -> T {
        let request = try buildRequest(method: "GET", path: path, query: query)
        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw ApiError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError.decoding
        }
    }

    public func post<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ path: String, query: [String: String] = [:], json body: Body
    ) async throws -> T {
        var request = try buildRequest(method: "POST", path: path, query: query)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw ApiError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError.decoding
        }
    }

    /// Raw GET returning the response body as `Data`, for endpoints whose JSON
/// envelope shape is uncertain and must be decoded tolerantly by the caller.
    public func getData(
        _ path: String, query: [String: String] = [:]
    ) async throws -> Data {
        let request = try buildRequest(method: "GET", path: path, query: query)
        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw ApiError.http(http.statusCode) }
        return data
    }

}

public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

extension APIClient {
    /// POSTs a JSON body and checks the HTTP status, discarding the response body.
    /// For write endpoints that return 204/no meaningful body; avoids decoding
    /// failures on empty responses that `EmptyResponse` would otherwise throw.
    public func postVoid<Body: Encodable & Sendable>(
        _ path: String, query: [String: String] = [:], json body: Body
    ) async throws {
        try await send(method: "POST", path: path, query: query,
                       contentType: "application/json", body: try JSONEncoder().encode(body))
    }

    /// DELETEs and checks the HTTP status, discarding the response body.
    public func deleteVoid(_ path: String, query: [String: String] = [:]) async throws {
        try await send(method: "DELETE", path: path, query: query, contentType: nil, body: nil)
    }

    /// POSTs form fields and checks the HTTP status, discarding the response body.
    public func postFormVoid(_ path: String, fields: [String: String]) async throws {
        try await send(method: "POST", path: path, query: [:],
                       contentType: "application/x-www-form-urlencoded",
                       body: Data(Self.formEncode(fields).utf8))
    }

    private func send(method: String, path: String, query: [String: String],
                      contentType: String?, body: Data?) async throws {
        var request = try buildRequest(method: method, path: path, query: query)
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body
        let (_, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw ApiError.http(http.statusCode) }
    }
}

extension APIClient {
    public func postForm<T: Decodable & Sendable>(
        _ path: String,
        fields: [String: String]
    ) async throws -> T {
        var request = try buildRequest(method: "POST", path: path, query: [:])
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.formEncode(fields).utf8)
        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw ApiError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError.decoding
        }
    }

    /// Percent-encodes form fields for `application/x-www-form-urlencoded`.
    /// `&` and `=` are encoded so they survive inside values; `+` is also
    /// encoded to avoid the form-decoding space ambiguity.
    static func formEncode(_ fields: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.subtract(CharacterSet(charactersIn: "&=+"))
        return fields
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
            .map { pair in
                let key = pair.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? pair.key
                let value = pair.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? pair.value
                return "\(key)=\(value)"
            }
            .joined(separator: "&")
    }
}