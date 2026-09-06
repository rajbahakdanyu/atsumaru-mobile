import Foundation

public struct NovelChapter: Decodable, Sendable {
    public let id: String
    public let title: String
    public let number: Int
    public let scanlationMangaId: String
    public let paragraphs: [String]
    public let wordCount: Int
    public let paragraphComments: [String: Int]?

    public init(id: String, title: String, number: Int, scanlationMangaId: String,
                paragraphs: [String], wordCount: Int, paragraphComments: [String: Int]? = nil) {
        self.id = id; self.title = title; self.number = number
        self.scanlationMangaId = scanlationMangaId; self.paragraphs = paragraphs
        self.wordCount = wordCount; self.paragraphComments = paragraphComments
    }
}