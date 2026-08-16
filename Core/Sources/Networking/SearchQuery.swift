import Foundation

public struct SearchQuery: Sendable {
    public var q: String = "*"
    public var queryBy: [String] = ["title", "otherNames"]
    public var page: Int = 1
    public var perPage: Int = 30

    public init() {}

    public func toQueryItems() -> [String: String] {
        var items: [String: String] = ["q": q, "page": String(page), "per_page": String(perPage)]
        if !queryBy.isEmpty { items["query_by"] = queryBy.joined(separator: ",") }
        return items
    }
}
