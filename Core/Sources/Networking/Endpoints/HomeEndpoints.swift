import Foundation

public enum HomeEndpoint: String, Sendable {
    case popular, recentlyUpdated

    public var path: String { "/api/home2/\(rawValue)" }
}
