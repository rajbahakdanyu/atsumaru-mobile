import Foundation

public enum HomeEndpoint: String, Endpoint, Sendable, CaseIterable {
    case popular, topRated, rising, recommended, recentlyUpdated
    case recentlyAdded, hotUpdates, hotArrivals, hiddenGems
    case bingeWorthy, mostBookmarked, mostTalkedAbout, mostPolarizing

    public var path: String { "/api/home2/\(rawValue)" }
}