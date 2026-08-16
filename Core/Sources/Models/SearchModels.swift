import Foundation

public struct SearchHit: Codable, Sendable {
    public let document: HomeItem
    public init(document: HomeItem) { self.document = document }
}

public struct SearchResult: Codable, Sendable {
    public let found: Int
    public let hits: [SearchHit]
    public init(found: Int, hits: [SearchHit]) { self.found = found; self.hits = hits }
}