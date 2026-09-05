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

/// Sendable value-type snapshot of a `DownloadedChapter` record. The actor
/// `DownloadManager` and non-isolated callers exchange these instead of the
/// Core Data-backed `@Model` reference type, which must not cross actor
/// boundaries.
public struct DownloadedChapterSnapshot: Sendable {
    public let chapterId: String
    public let mangaId: String
    public let mangaTitle: String
    public let chapterTitle: String
    public let kind: String
    public let pageCount: Int
    public let totalBytes: Int64
    public let completedAt: Date
    public let state: String

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

@MainActor
public final class DownloadStore {
    private let container: ModelContainer

    public init(container: ModelContainer? = nil) throws {
        if let container {
            self.container = container
        } else {
            self.container = try ModelContainer(
                for: DownloadedChapter.self,
                configurations: ModelConfiguration("downloads", isStoredInMemoryOnly: false)
            )
        }
    }

    public func save(_ snapshot: DownloadedChapterSnapshot) throws {
        let context = container.mainContext
        if let existing = try? fetch(chapterId: snapshot.chapterId, in: context) {
            existing.mangaId = snapshot.mangaId
            existing.mangaTitle = snapshot.mangaTitle
            existing.chapterTitle = snapshot.chapterTitle
            existing.kind = snapshot.kind
            existing.pageCount = snapshot.pageCount
            existing.totalBytes = snapshot.totalBytes
            existing.completedAt = snapshot.completedAt
            existing.state = snapshot.state
        } else {
            context.insert(DownloadedChapter(
                chapterId: snapshot.chapterId, mangaId: snapshot.mangaId,
                mangaTitle: snapshot.mangaTitle, chapterTitle: snapshot.chapterTitle,
                kind: snapshot.kind, pageCount: snapshot.pageCount,
                totalBytes: snapshot.totalBytes, completedAt: snapshot.completedAt,
                state: snapshot.state))
        }
        try context.save()
    }

    public func all() -> [DownloadedChapterSnapshot] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<DownloadedChapter>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map {
            DownloadedChapterSnapshot(
                chapterId: $0.chapterId, mangaId: $0.mangaId, mangaTitle: $0.mangaTitle,
                chapterTitle: $0.chapterTitle, kind: $0.kind, pageCount: $0.pageCount,
                totalBytes: $0.totalBytes, completedAt: $0.completedAt, state: $0.state
            )
        }
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