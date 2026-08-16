import Foundation

public enum HomeEndpoint: String, Endpoint, Sendable, CaseIterable {
    case popular, topRated, rising, recommended, recentlyUpdated
    case recentlyAdded, hotUpdates, hotArrivals, hiddenGems
    case bingeWorthy, mostBookmarked, mostTalkedAbout, mostPolarizing

    public var path: String { "/api/home2/\(rawValue)" }

    public var displayName: String {
        switch self {
        case .popular: "Popular"
        case .topRated: "Top Rated"
        case .rising: "Rising"
        case .recommended: "Recommended"
        case .recentlyUpdated: "Recently Updated"
        case .recentlyAdded: "Recently Added"
        case .hotUpdates: "Hot Updates"
        case .hotArrivals: "Hot Arrivals"
        case .hiddenGems: "Hidden Gems"
        case .bingeWorthy: "Binge Worthy"
        case .mostBookmarked: "Most Bookmarked"
        case .mostTalkedAbout: "Most Talked About"
        case .mostPolarizing: "Most Polarizing"
        }
    }
}