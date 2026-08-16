import Foundation
import SwiftData

@Model
public final class DownloadedChapter {
    @Attribute(.unique) public var chapterId: String
    public var mangaId: String
    public var mangaTitle: String
    public var chapterTitle: String
    public var kind: String
    public var pageCount: Int
    public var totalBytes: Int64
    public var completedAt: Date
    public var state: String

    public init(chapterId: String, mangaId: String, mangaTitle: String, chapterTitle: String,
                kind: String, pageCount: Int, totalBytes: Int64, completedAt: Date, state: String) {
        self.chapterId = chapterId
        self.mangaId = mangaId
        self.mangaTitle = mangaTitle
        self.chapterTitle = chapterTitle
        self.kind = kind
        self.pageCount = pageCount
        self.totalBytes = totalBytes
        self.completedAt = completedAt
        self.state = state
    }
}

/// SwiftData `@Model` types are reference types backed by Core Data; field
/// reads after the model has been inserted/fetched are simple accessor reads
/// and are safe to read off the context's queue. We mark Sendable so the
/// DownloadManager actor can hand snapshots back to non-isolated callers.
extension DownloadedChapter: @unchecked Sendable {}

@MainActor
public final class DownloadStore {
    private let container: ModelContainer

    public init(container: ModelContainer? = nil) throws {
        if let container {
            self.container = container
        } else {
            self.container = try ModelContainer(
                for: DownloadedChapter.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        }
    }

    public func save(_ chapter: DownloadedChapter) throws {
        let context = container.mainContext
        if let existing = try? fetch(chapterId: chapter.chapterId, in: context) {
            existing.mangaId = chapter.mangaId
            existing.mangaTitle = chapter.mangaTitle
            existing.chapterTitle = chapter.chapterTitle
            existing.kind = chapter.kind
            existing.pageCount = chapter.pageCount
            existing.totalBytes = chapter.totalBytes
            existing.completedAt = chapter.completedAt
            existing.state = chapter.state
        } else {
            context.insert(DownloadedChapter(
                chapterId: chapter.chapterId, mangaId: chapter.mangaId,
                mangaTitle: chapter.mangaTitle, chapterTitle: chapter.chapterTitle,
                kind: chapter.kind, pageCount: chapter.pageCount,
                totalBytes: chapter.totalBytes, completedAt: chapter.completedAt,
                state: chapter.state))
        }
        try context.save()
    }

    public func all() -> [DownloadedChapter] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<DownloadedChapter>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func delete(chapterId: String) throws {
        let context = container.mainContext
        if let record = try? fetch(chapterId: chapterId, in: context) {
            context.delete(record)
            try context.save()
        }
    }

    public func deleteAll() throws {
        let context = container.mainContext
        let descriptor = FetchDescriptor<DownloadedChapter>()
        if let records = try? context.fetch(descriptor) {
            for record in records { context.delete(record) }
        }
        try context.save()
    }

    public func totalBytes() -> Int64 {
        all().reduce(0) { $0 + $1.totalBytes }
    }

    private func fetch(chapterId: String, in context: ModelContext) throws -> DownloadedChapter? {
        var descriptor = FetchDescriptor<DownloadedChapter>(
            predicate: #Predicate { $0.chapterId == chapterId }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

public extension DownloadStore {
    /// Convenience factory for an in-memory store, callable from any isolation.
    static func makeInMemory() async throws -> DownloadStore {
        try await MainActor.run {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: DownloadedChapter.self, configurations: config)
            return try DownloadStore(container: container)
        }
    }
}