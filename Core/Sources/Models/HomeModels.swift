import Foundation

public struct HomeItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let image: String
    public let medium: String
    public let mbRating: Double?
    public let views: String?

    public init(id: String, title: String, image: String, medium: String,
                mbRating: Double? = nil, views: String? = nil) {
        self.id = id
        self.title = title
        self.image = image
        self.medium = medium
        self.mbRating = mbRating
        self.views = views
    }

    enum CodingKeys: String, CodingKey {
        case id, title, image, medium, mbRating, views
        case poster
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""

        // Home rails use `image`; the search documents use `poster`. Tolerate
        // both shapes.
        let poster = try? c.decode(String.self, forKey: .poster)
        image = (try? c.decode(String.self, forKey: .image)) ?? poster ?? ""

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
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(image, forKey: .image)
        try c.encode(medium, forKey: .medium)
        try c.encodeIfPresent(mbRating, forKey: .mbRating)
        try c.encodeIfPresent(views, forKey: .views)
    }
}

public struct HomeRail: Codable, Sendable {
    public let items: [HomeItem]
    public init(items: [HomeItem]) { self.items = items }
}
