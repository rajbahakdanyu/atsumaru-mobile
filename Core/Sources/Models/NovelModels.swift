import Foundation

public struct NovelChapter: Decodable, Sendable {
    public let id: String
    public let title: String
    public let number: Int
    public let scanlationMangaId: String
    public let paragraphs: [String]
    public let wordCount: Int
    public let paragraphComments: [String: Int]?
}