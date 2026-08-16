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
        case poster, posterSmall, posterMedium
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)

        // Home rails use `image`/`smallImage`/`mediumImage`/`largeImage`; the
        // search documents use `poster`/`posterSmall`/`posterMedium` and omit
        // `largeImage`. Tolerate both shapes.
        let poster = try? c.decode(String.self, forKey: .poster)
        image = (try? c.decode(String.self, forKey: .image)) ?? poster ?? ""
        smallImage = (try? c.decode(String.self, forKey: .smallImage))
            ?? (try? c.decode(String.self, forKey: .posterSmall))
            ?? image
        mediumImage = (try? c.decode(String.self, forKey: .mediumImage))
            ?? (try? c.decode(String.self, forKey: .posterMedium))
            ?? image
        largeImage = (try? c.decode(String.self, forKey: .largeImage)) ?? image

        isAdult = (try? c.decode(Bool.self, forKey: .isAdult)) ?? false
        type = (try? c.decode(String.self, forKey: .type)) ?? "Manga"
        medium = (try? c.decode(String.self, forKey: .medium)) ?? "Comic"
        mbRating = try? c.decode(Double.self, forKey: .mbRating)

        // `views` is a formatted string ("14.8M") on rails but a raw Int on
        // search documents.
        if let s = try? c.decode(String.self, forKey: .views) {
            views = s
        } else if let n = try? c.decode(Int.self, forKey: .views) {
            views = String(n)
        } else {
            views = nil
        }

        createdAt = try? c.decode(Int.self, forKey: .createdAt)
        updatedAt = try? c.decode(Int.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(image, forKey: .image)
        try c.encode(smallImage, forKey: .smallImage)
        try c.encode(mediumImage, forKey: .mediumImage)
        try c.encode(largeImage, forKey: .largeImage)
        try c.encode(isAdult, forKey: .isAdult)
        try c.encode(type, forKey: .type)
        try c.encode(medium, forKey: .medium)
        try c.encodeIfPresent(mbRating, forKey: .mbRating)
        try c.encodeIfPresent(views, forKey: .views)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

public struct HomeRail: Codable, Sendable {
    public let items: [HomeItem]
    public init(items: [HomeItem]) { self.items = items }
}