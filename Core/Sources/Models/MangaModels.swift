import Foundation

public struct MangaPage: Decodable, Sendable {
    public let id: String
    public let title: String
    public let type: String?
    public let medium: String?
    public let status: String?
    public let synopsis: String?
    public let avgRating: Double?
    public let poster: PosterImages?
    public let banner: Banner?
    public let genres: [Tag]
    public let tags: [Tag]
    public let authors: [Author]
    public let scanlators: [Scanlator]?
    public let chapters: [Chapter]
    public let recommendations: [HomeItem]
    public let relations: [Relation]
    public let startReading: StartReading?

    public func translatorName(for chapter: Chapter) -> String? {
        guard let sid = chapter.scanlationMangaId else { return nil }
        return scanlators?.first { $0.id == sid }?.name
    }
}

public struct PosterImages: Decodable, Sendable {
    public let image: String
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

public struct Scanlator: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
}

public struct Relation: Decodable, Sendable {
    public let type: String
    public let manga: HomeItem
}

public struct StartReading: Decodable, Sendable {
    public let chapterId: String
}

public struct Chapter: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let number: Double
    public let index: Int?
    public let pageCount: Int
    public let scanlationMangaId: String?
    public let createdAt: Int?
    public let progress: ChapterProgress?

    enum CodingKeys: String, CodingKey {
        case id, title, number, index, pageCount, scanlationMangaId, createdAt, progress
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
        createdAt = DateParsing.decodeEpochMs(c, forKey: .createdAt)
        progress = try c.decodeIfPresent(ChapterProgress.self, forKey: .progress)
    }
}

/// Server-side reading progress for a chapter (present when the user has
/// read at least part of it). `page`/`pages` are 1-based; `frac` is 0...1.
public struct ChapterProgress: Codable, Hashable, Sendable {
    public let mangaId: String?
    public let page: Int?
    public let pages: Int?
    public let ts: Int?
    public let strip: Bool?
    public let frac: Double?

    public init(mangaId: String? = nil, page: Int? = nil, pages: Int? = nil,
                ts: Int? = nil, strip: Bool? = nil, frac: Double? = nil) {
        self.mangaId = mangaId
        self.page = page
        self.pages = pages
        self.ts = ts
        self.strip = strip
        self.frac = frac
    }
}