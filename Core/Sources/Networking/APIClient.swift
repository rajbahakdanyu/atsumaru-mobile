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
}