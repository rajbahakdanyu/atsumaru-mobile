import Foundation

public struct NamedFilter: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
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