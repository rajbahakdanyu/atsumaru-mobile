import Foundation

public struct MangaPage: Decodable, Sendable {
    public let id: String
    public let title: String
    public let englishTitle: String?
    public let type: String?
    public let medium: String?
    public let status: String?
    public let synopsis: String?
    public let views: String?
    public let released: Int?
    public let avgRating: Double?
    public let mbRating: Double?
    public let totalChapterCount: Double?
    public let hasReadHistory: Bool?
    public let poster: PosterImages?
    public let banner: Banner?
    public let genres: [Tag]
    public let tags: [Tag]
    public let authors: [Author]
    public let chapters: [Chapter]
    public let recommendations: [HomeItem]
    public let similarManga: [HomeItem]
    public let relations: [Relation]
    public let startReading: StartReading?
}

public struct PosterImages: Decodable, Sendable {
    public let image: String
    public let smallImage: String?
    public let mediumImage: String?
    public let largeImage: String?
}

public struct Banner: Decodable, Sendable {
    public let url: String
    public let aspectRatio: Double
}

public struct Tag: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
}

public struct Author: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let slug: String?
    public let type: String?
}

public struct Relation: Decodable, Sendable {
    public let type: String
    public let manga: HomeItem
}

public struct StartReading: Decodable, Sendable {
    public let chapterId: String
    public let pageIndex: Int?
}

public struct Chapter: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let number: Double
    public let index: Int?
    public let pageCount: Int
    public let scanlationMangaId: String?
    public let createdAt: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, number, index, pageCount, scanlationMangaId, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        // Chapter numbers can be fractional ("Chapter 93.2").
        number = (try? c.decode(Double.self, forKey: .number)) ?? 0
        index = try c.decodeIfPresent(Int.self, forKey: .index)
        pageCount = (try? c.decode(Int.self, forKey: .pageCount)) ?? 0
        scanlationMangaId = try c.decodeIfPresent(String.self, forKey: .scanlationMangaId)
        if let int = try? c.decodeIfPresent(Int.self, forKey: .createdAt) {
            createdAt = int
        } else if let str = try c.decodeIfPresent(String.self, forKey: .createdAt),
                  let ms = Self.epochMs(fromISO8601: str) {
            createdAt = ms
        } else {
            createdAt = nil
        }
    }

    /// Chapter number formatted without a trailing `.0` for whole numbers
    /// (so `97` renders as "97", `93.2` renders as "93.2").
    public var numberLabel: String {
        if number.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(number))
        }
        return String(number)
    }

    private static func epochMs(fromISO8601 s: String) -> Int? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        return nil
    }
}