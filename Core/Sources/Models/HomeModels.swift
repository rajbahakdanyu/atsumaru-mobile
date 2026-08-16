import Foundation

public struct HomeItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let image: String
    public let smallImage: String
    public let mediumImage: String
    public let largeImage: String
    public let isAdult: Bool
    public let type: String
    public let medium: String
    public let mbRating: Double?
    public let views: String?
    public let createdAt: Int?
    public let updatedAt: Int?

    public init(id: String, title: String, image: String, smallImage: String,
                mediumImage: String, largeImage: String, isAdult: Bool,
                type: String, medium_: String, mbRating: Double?, views: String?,
                createdAt: Int?, updatedAt: Int?) {
        self.id = id
        self.title = title
        self.image = image
        self.smallImage = smallImage
        self.mediumImage = mediumImage
        self.largeImage = largeImage
        self.isAdult = isAdult
        self.type = type
        self.medium = medium_
        self.mbRating = mbRating
        self.views = views
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, image, smallImage, mediumImage, largeImage
        case isAdult, type, medium, mbRating, views, createdAt, updatedAt
    }
}

public struct HomeRail: Codable, Sendable {
    public let items: [HomeItem]
    public init(items: [HomeItem]) { self.items = items }
}