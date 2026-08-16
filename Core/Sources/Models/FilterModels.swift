import Foundation

public struct NamedFilter: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let group: String?
    public init(id: String, name: String, group: String? = nil) {
        self.id = id; self.name = name; self.group = group
    }
}

public struct AvailableFilters: Codable, Sendable {
    public let genres: [NamedFilter]
    public let tags: [NamedFilter]
    public let types: [NamedFilter]
    public let statuses: [NamedFilter]
    public init(genres: [NamedFilter], tags: [NamedFilter], types: [NamedFilter], statuses: [NamedFilter]) {
        self.genres = genres; self.tags = tags; self.types = types; self.statuses = statuses
    }
}

public enum BrowseSort: String, CaseIterable, Identifiable, Sendable {
    case relevance = ""
    case titleAsc = "title:asc"
    case titleDesc = "title:desc"
    case ratingDesc = "mbRating:desc"
    case viewsDesc = "views:desc"
    case chapterCountDesc = "chapterCount:desc"
    case dateAddedDesc = "dateAdded:desc"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .relevance: "Relevance"
        case .titleAsc: "Title A–Z"
        case .titleDesc: "Title Z–A"
        case .ratingDesc: "Highest rated"
        case .viewsDesc: "Most viewed"
        case .chapterCountDesc: "Most chapters"
        case .dateAddedDesc: "Recently added"
        }
    }
}
