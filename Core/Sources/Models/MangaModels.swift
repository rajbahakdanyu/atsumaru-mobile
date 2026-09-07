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

    enum CodingKeys: String, CodingKey {
        case id, title, type, medium, status, synopsis, avgRating, poster, banner
        case genres, tags, authors, scanlators, chapters, recommendations, relations, startReading
    }

    /// Tolerant decode: only `id` is required. One malformed array element or
    /// oddly-typed field must never blank the whole page.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        medium = try? c.decodeIfPresent(String.self, forKey: .medium)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        synopsis = try? c.decodeIfPresent(String.self, forKey: .synopsis)
        avgRating = try? c.decodeIfPresent(Double.self, forKey: .avgRating)
        poster = try? c.decodeIfPresent(PosterImages.self, forKey: .poster)
        banner = try? c.decodeIfPresent(Banner.self, forKey: .banner)
        genres = c.tolerantArray(Tag.self, forKey: .genres)
        tags = c.tolerantArray(Tag.self, forKey: .tags)
        authors = c.tolerantArray(Author.self, forKey: .authors)
        scanlators = try? c.decodeIfPresent([Scanlator].self, forKey: .scanlators)
        chapters = c.tolerantArray(Chapter.self, forKey: .chapters)
        recommendations = c.tolerantArray(HomeItem.self, forKey: .recommendations)
        relations = c.tolerantArray(Relation.self, forKey: .relations)
        startReading = try? c.decodeIfPresent(StartReading.self, forKey: .startReading)
    }

    /// Memberwise init for locally-synthesized pages (e.g. the offline
    /// fallback that lists downloaded chapters when the network fails).
    public init(
        id: String, title: String, type: String? = nil, medium: String? = nil,
        status: String? = nil, synopsis: String? = nil, avgRating: Double? = nil,
        poster: PosterImages? = nil, banner: Banner? = nil,
        genres: [Tag] = [], tags: [Tag] = [], authors: [Author] = [],
        scanlators: [Scanlator]? = nil, chapters: [Chapter] = [],
        recommendations: [HomeItem] = [], relations: [Relation] = [],
        startReading: StartReading? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.medium = medium
        self.status = status
        self.synopsis = synopsis
        self.avgRating = avgRating
        self.poster = poster
        self.banner = banner
        self.genres = genres
        self.tags = tags
        self.authors = authors
        self.scanlators = scanlators
        self.chapters = chapters
        self.recommendations = recommendations
        self.relations = relations
        self.startReading = startReading
    }
}

public struct PosterImages: Decodable, Sendable {
    public let image: String

    enum CodingKeys: String, CodingKey { case image, id, smallImage, mediumImage }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        image = (try? c.decode(String.self, forKey: .image))
            ?? (try? c.decode(String.self, forKey: .id))
            ?? (try? c.decode(String.self, forKey: .mediumImage))
            ?? (try? c.decode(String.self, forKey: .smallImage))
            ?? ""
    }
}

public struct Banner: Decodable, Sendable {
    public let url: String
    public let aspectRatio: Double

    enum CodingKeys: String, CodingKey { case url, aspectRatio }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        aspectRatio = (try? c.decode(Double.self, forKey: .aspectRatio)) ?? 1
    }
}

public struct Tag: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String?

    enum CodingKeys: String, CodingKey { case id, name }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        name = try? c.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct Author: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String?
    public let slug: String?
    public let type: String?

    enum CodingKeys: String, CodingKey { case id, name, slug, type }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        slug = try? c.decodeIfPresent(String.self, forKey: .slug)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
    }
}

public struct Scanlator: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String?

    enum CodingKeys: String, CodingKey { case id, name }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        name = try? c.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct Relation: Decodable, Sendable {
    public let type: String
    public let manga: HomeItem

    enum CodingKeys: String, CodingKey { case type, manga }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        // Required: if it fails the Relation decode fails, but element-skip
        // removes just the bad relation.
        manga = try c.decode(HomeItem.self, forKey: .manga)
    }
}

public struct StartReading: Decodable, Sendable {
    public let chapterId: String

    enum CodingKeys: String, CodingKey { case chapterId }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chapterId = (try? c.decode(String.self, forKey: .chapterId)) ?? ""
    }
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

    /// Memberwise init for locally-synthesized chapters (e.g. resume targets,
    /// offline reads) where the real metadata is fetched later.
    public init(
        id: String, title: String = "", number: Double = 0, index: Int? = nil,
        pageCount: Int = 0, scanlationMangaId: String? = nil,
        createdAt: Int? = nil, progress: ChapterProgress? = nil
    ) {
        self.id = id
        self.title = title
        self.number = number
        self.index = index
        self.pageCount = pageCount
        self.scanlationMangaId = scanlationMangaId
        self.createdAt = createdAt
        self.progress = progress
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        // Chapter numbers can be fractional ("Chapter 93.2").
        number = (try? c.decode(Double.self, forKey: .number)) ?? 0
        index = try c.decodeIfPresent(Int.self, forKey: .index)
        pageCount = (try? c.decode(Int.self, forKey: .pageCount)) ?? 0
        scanlationMangaId = try? c.decodeIfPresent(String.self, forKey: .scanlationMangaId)
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

    public var fraction: Double {
        if let frac { return min(max(frac, 0), 1) }
        guard let page, let pages, pages > 0 else { return 0 }
        return min(max(Double(page) / Double(pages), 0), 1)
    }

    public var isComplete: Bool { fraction >= 0.95 }
}