import Foundation

public enum ApiError: Error, Equatable {
    case invalidURL
    case http(Int)
    case server(String)
    case decoding
    case offline
}

public struct APIResponse<T: Decodable & Sendable>: Sendable {
    public let data: T
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

    public func get<T: Decodable & Sendable>(
        _ path: String, query: [String: String] = [:]
    ) async throws -> T {
        guard var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw ApiError.invalidURL
        }
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("atsumaru-ios", forHTTPHeaderField: "User-Agent")
        request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
        let (data, response) = try await session.data(for: request)
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
        guard var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw ApiError.invalidURL
        }
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("atsumaru-ios", forHTTPHeaderField: "User-Agent")
        request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw ApiError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError.decoding
        }
    }

    public func put<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ path: String, query: [String: String] = [:], json body: Body
    ) async throws -> T {
        guard var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw ApiError.invalidURL
        }
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("atsumaru-ios", forHTTPHeaderField: "User-Agent")
        request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ApiError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw ApiError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError.decoding
        }
    }
}

public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

extension APIClient {
    public func postForm<T: Decodable & Sendable>(
        _ path: String,
        fields: [String: String]
    ) async throws -> T {
        guard var components = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw ApiError.invalidURL
        }
        components.path = path
        guard let url = components.url else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("atsumaru-ios", forHTTPHeaderField: "User-Agent")
        request.setValue("fetch", forHTTPHeaderField: "X-Requested-With")
        request.httpBody = Data(Self.formEncode(fields).utf8)
        let (data, response) = try await session.data(for: request)
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