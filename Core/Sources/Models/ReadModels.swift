import Foundation

public struct ReadChapter: Decodable, Sendable {
    public let id: String
    public let title: String
    public let scanlationMangaId: String
    public let pages: [PageImage]

    public init(id: String, title: String, scanlationMangaId: String, pages: [PageImage]) {
        self.id = id; self.title = title; self.scanlationMangaId = scanlationMangaId; self.pages = pages
    }
}

public struct PageImage: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let image: String
    public let number: Int
    public let width: Int
    public let height: Int
    public let aspectRatio: Double
    public init(id: String, image: String, number: Int, width: Int, height: Int, aspectRatio: Double) {
        self.id = id; self.image = image; self.number = number; self.width = width; self.height = height; self.aspectRatio = aspectRatio
    }
}

public enum ReaderMode: String, Sendable, CaseIterable { case paged, strip }

public enum ReaderFit: String, Sendable, CaseIterable { case fit, fill }

public struct ProgressState: Sendable, Equatable {
    public var mangaId: String
    public var chapterId: String
    public var pageIndex: Int
    public var updatedAt: Date
    public init(mangaId: String, chapterId: String, pageIndex: Int, updatedAt: Date) {
        self.mangaId = mangaId; self.chapterId = chapterId; self.pageIndex = pageIndex; self.updatedAt = updatedAt
    }
}

public struct ProgressUpdate: Encodable, Sendable {
    public let mangaScanlationId: String
    public let mangaId: String
    public let chapterId: String
    public let page: Int
    public let frac: Double
    public let pages: Int
    public let ts: Int
    public let strip: Bool
    public let nextChapterId: String?
    public let readMs: Int
    public init(mangaScanlationId: String, mangaId: String, chapterId: String, page: Int, frac: Double, pages: Int, ts: Int, strip: Bool, nextChapterId: String?, readMs: Int) {
        self.mangaScanlationId = mangaScanlationId; self.mangaId = mangaId; self.chapterId = chapterId
        self.page = page; self.frac = frac; self.pages = pages; self.ts = ts; self.strip = strip
        self.nextChapterId = nextChapterId; self.readMs = readMs
    }
}