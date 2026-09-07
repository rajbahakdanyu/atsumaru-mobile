import Foundation
import SwiftData

@Model
final class ProgressRecord {
    @Attribute(.unique) var key: String
    var mangaId: String
    var chapterId: String
    var pageIndex: Int
    var updatedAt: Date

    init(mangaId: String, chapterId: String, pageIndex: Int, updatedAt: Date) {
        self.key = "\(mangaId)_\(chapterId)"
        self.mangaId = mangaId
        self.chapterId = chapterId
        self.pageIndex = pageIndex
        self.updatedAt = updatedAt
    }
}

@MainActor
public final class ProgressStore {
    private let container: ModelContainer

    public init(container: ModelContainer? = nil) throws {
        if let container {
            self.container = container
        } else {
            self.container = try ModelContainer(
                for: ProgressRecord.self,
                configurations: ModelConfiguration("progress", isStoredInMemoryOnly: false)
            )
        }
    }

    public func save(_ state: ProgressState) throws {
        let context = container.mainContext
        let existing = try fetch(mangaId: state.mangaId, chapterId: state.chapterId, in: context)
        if let existing {
            existing.chapterId = state.chapterId
            existing.pageIndex = state.pageIndex
            existing.updatedAt = state.updatedAt
        } else {
            context.insert(ProgressRecord(mangaId: state.mangaId, chapterId: state.chapterId, pageIndex: state.pageIndex, updatedAt: state.updatedAt))
        }
        try context.save()
    }

    public func progress(mangaId: String, chapterId: String) -> ProgressState? {
        let context = container.mainContext
        guard let record = try? fetch(mangaId: mangaId, chapterId: chapterId, in: context) else { return nil }
        return ProgressState(mangaId: record.mangaId, chapterId: record.chapterId, pageIndex: record.pageIndex, updatedAt: record.updatedAt)
    }

    /// Returns the most recently updated reading progress for a manga, if any.
    public func latestProgress(mangaId: String) -> ProgressState? {
        let context = container.mainContext
        var descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.mangaId == mangaId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let record = try? context.fetch(descriptor).first else { return nil }
        return ProgressState(mangaId: record.mangaId, chapterId: record.chapterId, pageIndex: record.pageIndex, updatedAt: record.updatedAt)
    }

    public func progressByChapter(mangaId: String) -> [String: ProgressState] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.mangaId == mangaId }
        )
        guard let records = try? context.fetch(descriptor) else { return [:] }
        return Dictionary(uniqueKeysWithValues: records.map { record in
            (record.chapterId, ProgressState(
                mangaId: record.mangaId,
                chapterId: record.chapterId,
                pageIndex: record.pageIndex,
                updatedAt: record.updatedAt
            ))
        })
    }

    public func delete(mangaId: String, chapterId: String) throws {
        let context = container.mainContext
        if let record = try fetch(mangaId: mangaId, chapterId: chapterId, in: context) {
            context.delete(record)
            try context.save()
        }
    }

    private func fetch(mangaId: String, chapterId: String, in context: ModelContext) throws -> ProgressRecord? {
        var descriptor = FetchDescriptor<ProgressRecord>(
            predicate: #Predicate { $0.mangaId == mangaId && $0.chapterId == chapterId }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

public extension ProgressStore {
    static func makeInMemory() async throws -> ProgressStore {
        try await MainActor.run {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: ProgressRecord.self, configurations: configuration)
            return try ProgressStore(container: container)
        }
    }
}