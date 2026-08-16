import Foundation

public struct SearchQuery: Sendable {
    public var q: String = "*"
    public var queryBy: [String] = ["title", "otherNames"]
    public var genres: [String] = []
    public var tags: [String] = []
    public var types: [String] = []
    public var statuses: [String] = []
    public var mediums: [String] = []
    public var minChapters: Int?
    public var sortBy: String = ""
    public var page: Int = 1
    public var perPage: Int = 30

    public init() {}

    public func toQueryItems() -> [String: String] {
        var items: [String: String] = ["q": q, "page": String(page), "per_page": String(perPage)]
        if !queryBy.isEmpty { items["query_by"] = queryBy.joined(separator: ",") }
        var filters: [String] = []
        if !genres.isEmpty { filters.append("genreIds:=[\(genres.joined(separator: ","))]") }
        if !tags.isEmpty { filters.append("tagIds:=[\(tags.joined(separator: ","))]") }
        if !statuses.isEmpty { filters.append("status:=[\(statuses.joined(separator: ","))]") }
        if !types.isEmpty { filters.append("type:=[\(types.joined(separator: ","))]") }
        if !mediums.isEmpty { filters.append("medium:=[\(mediums.joined(separator: ","))]") }
        if let minChapters { filters.append("chapterCount:>=\(minChapters)") }
        if !filters.isEmpty { items["filter_by"] = filters.joined(separator: " && ") }
        if !sortBy.isEmpty { items["sort_by"] = sortBy }
        return items
    }
}
