import Foundation
import os

public enum DownloadState: Sendable, Equatable {
    case queued
    case downloading(Double)
    case completed
    case failed(String)

    public var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
    /// Maps a live in-memory state onto what the UI should show for a record
    /// persisted from a previous session. After relaunch there is no live
    /// state, so `state(for:)` reports `.queued` for everything; a persisted
    /// "completed" record stays completed and a persisted "failed" record
    /// must stay failed (not surface as queued).
    public static func effective(live: DownloadState, persisted: String) -> DownloadState {
        switch live {
        case .queued:
            switch persisted {
            case "completed": return .completed
            case "failed": return .failed("Download failed")
            default: return .queued
            }
        case .downloading(let fraction): return .downloading(fraction)
        case .completed: return .completed
        case .failed(let message): return .failed(message)
        }
    }
}

/// Offline content served by `DownloadManager.localContent(for:)` for a
/// completed download: page-image file URLs (manga) or paragraph strings
/// (novel).
public enum DownloadedContent: Sendable, Equatable {
    case pages([URL])
    case novelParagraphs([String])
}

public enum DownloadEvent: Sendable, Equatable {
    case progress(chapterId: String, fraction: Double)
    case completed(chapterId: String)
    case failed(chapterId: String, message: String)
}

public actor DownloadManager {
    private static let log = Logger(subsystem: "dev.atsumaru.app", category: "downloads")

    private let readRepository: any ReadRepository
    private let novelRepository: (any NovelRepository)?
    private let store: DownloadStore?
    private let baseDirectory: URL
    private var session: URLSession

    private var states: [String: DownloadState] = [:]
    private var pageProgress: [String: [Double]] = [:]
    private var subscribers: [UUID: AsyncStream<DownloadEvent>.Continuation] = [:]
    private var tasks: [String: TaskEntry] = [:]

    /// File name for serialized novel content inside a chapter directory.
    public static let novelContentFileName = "content.json"

    /// Bookkeeping so a superseded run can tell its own task entry apart from
    /// a replacement run's (Task handles are not comparable, hence the id).
    private struct TaskEntry {
        let id: UUID
        let task: Task<Void, Never>
    }

    /// Maximum number of page-image downloads in flight at once per chapter.
    private static let pageConcurrency = 4

    public init(readRepository: any ReadRepository,
                novelRepository: (any NovelRepository)? = nil,
                store: DownloadStore? = nil,
                baseDirectory: URL? = nil,
                sessionConfiguration: URLSessionConfiguration? = nil,
                allowsCellularAccess: Bool = true) {
        self.readRepository = readRepository
        self.novelRepository = novelRepository
        self.store = store
        self.baseDirectory = baseDirectory ?? Self.defaultDownloadsURL()
        let config = sessionConfiguration ?? Self.makeDefaultSessionConfiguration()
        config.allowsCellularAccess = allowsCellularAccess
        self.session = URLSession(configuration: config)
    }

    /// Rebuilds the download session with the given cellular policy so the
    /// "any network" setting takes effect without relaunching the app.
    public func setAllowsCellularAccess(_ allowed: Bool) {
        let config = Self.makeDefaultSessionConfiguration()
        config.allowsCellularAccess = allowed
        session = URLSession(configuration: config)
    }

    public func enqueue(manga: HomeItem, chapter: Chapter) async {
        let chapterId = chapter.id
        tasks[chapterId]?.task.cancel()
        states[chapterId] = .queued
        pageProgress[chapterId] = nil
        do {
            try await persist(chapterId: chapterId, manga: manga, chapter: chapter,
                              pageCount: chapter.pageCount, totalBytes: 0, state: "queued")
        } catch {
            let message = error.localizedDescription
            states[chapterId] = .failed(message)
            Self.log.error("Could not persist queued chapter \(chapterId, privacy: .public): \(message, privacy: .public)")
            emit(.failed(chapterId: chapterId, message: message))
            return
        }
        Self.log.info("Enqueued \(Self.kind(for: manga), privacy: .public) chapter \(chapterId, privacy: .public)")
        emit(.progress(chapterId: chapterId, fraction: 0))
        let entryID = UUID()
        let task = Task { await self.runDownload(manga: manga, chapter: chapter, taskID: entryID) }
        tasks[chapterId] = TaskEntry(id: entryID, task: task)
    }

    /// One-time launch sweep: records left in "queued"/"downloading" by a
    /// previous session can never resume (their tasks died with the process),
    /// so they are marked failed. Users see the failure and can re-enqueue.
    public func restoreInterruptedDownloads() async {
        guard let store else { return }
        let records = await store.all()
        var restored = 0
        for record in records where record.state == "queued" || record.state == "downloading" {
            let failed = DownloadedChapterSnapshot(
                chapterId: record.chapterId, mangaId: record.mangaId,
                mangaTitle: record.mangaTitle, chapterTitle: record.chapterTitle,
                kind: record.kind, pageCount: record.pageCount,
                totalBytes: record.totalBytes, completedAt: record.completedAt,
                state: "failed")
            try? await store.save(failed)
            states[record.chapterId] = .failed("Download interrupted by app restart")
            pageProgress[record.chapterId] = nil
            restored += 1
        }
        if restored > 0 {
            Self.log.warning("Marked \(restored, privacy: .public) interrupted download(s) as failed at launch")
        }
    }

    /// Offline content for a completed download: sorted page-file URLs for
    /// manga, or the parsed paragraphs for novels. Nil when the chapter has
    /// no record or its persisted state is not "completed".
    public func localContent(for chapterId: String) async -> DownloadedContent? {
        guard let store,
              let record = await store.all().first(where: { $0.chapterId == chapterId }),
              record.state == "completed",
              let dir = try? chapterDirectory(mangaId: record.mangaId, chapterId: chapterId) else { return nil }
        if record.kind == "novel" {
            let url = dir.appendingPathComponent(Self.novelContentFileName, isDirectory: false)
            guard let data = try? Data(contentsOf: url),
                  let paragraphs = try? JSONDecoder().decode([String].self, from: data),
                  !paragraphs.isEmpty else { return nil }
            return .novelParagraphs(paragraphs)
        }
        guard record.pageCount > 0,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
              files.count == record.pageCount else { return nil }
        let pages = files.sorted { Self.pageIndex($0) < Self.pageIndex($1) }
        return .pages(pages)
    }

    private static func pageIndex(_ url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent) ?? Int.max
    }

    public func state(for chapterId: String) -> DownloadState {
        states[chapterId] ?? .queued
    }

    public func events() -> AsyncStream<DownloadEvent> {
        let id = UUID()
        return AsyncStream<DownloadEvent> { continuation in
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeSubscriber(id) }
            }
        }
    }

    /// Suspends until every listed chapter reaches a terminal state
    /// (`.completed` or `.failed`), the stream ends, or the surrounding task
    /// is cancelled. Listens to the events stream instead of polling.
    public func awaitCompletion(_ chapterIds: [String]) async {
        var target = Set(chapterIds)
        target = target.filter { id in
            switch states[id] {
            case .completed, .failed: return false
            default: return true
            }
        }
        guard !target.isEmpty else { return }
        let stream = events()
        outer: for await event in stream {
            if Task.isCancelled { break outer }
            switch event {
            case .completed(let id), .failed(let id, _):
                target.remove(id)
                if target.isEmpty { break outer }
            case .progress:
                continue
            }
        }
    }

    public func storageUsed() -> Int64 {
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let url as URL in enumerator {
                if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let size = values.fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    public func deleteChapter(_ chapterId: String) async {
        guard let store else { return }
        let chapters = await store.all()
        if let record = chapters.first(where: { $0.chapterId == chapterId }) {
            await evictChapter(record)
        }
    }

    public func deleteAll() async {
        guard let store else { return }
        let chapters = await store.all()
        for record in chapters {
            await evictChapter(record)
        }
    }

    public func listChapters() async -> [DownloadedChapterSnapshot] {
        guard let store else { return [] }
        return await store.all()
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    private func emit(_ event: DownloadEvent) {
        for (_, sub) in subscribers {
            sub.yield(event)
        }
    }

    private func runDownload(manga: HomeItem, chapter: Chapter, taskID: UUID) async {
        let chapterId = chapter.id
        let kind = Self.kind(for: manga)
        Self.log.info("Downloading \(kind, privacy: .public) chapter \(chapterId, privacy: .public)")
        // A superseded run must not clean up the replacement run's state, and
        // a cancelled run must not persist or emit after a deletion.
        defer {
            if tasks[chapterId]?.id == taskID {
                tasks[chapterId] = nil
                pageProgress[chapterId] = nil
            }
        }
        var fetchedCount = 0
        do {
            let chapterDir = try chapterDirectory(mangaId: manga.id, chapterId: chapterId)
            if FileManager.default.fileExists(atPath: chapterDir.path) {
                try FileManager.default.removeItem(at: chapterDir)
            }
            let totalBytes: Int64
            if kind == "novel" {
                (fetchedCount, totalBytes) = try await downloadNovelContent(manga: manga, chapterId: chapterId)
            } else {
                (fetchedCount, totalBytes) = try await downloadMangaPages(manga: manga, chapter: chapter)
            }
            // The chapter may have been deleted (or re-enqueued) while this
            // download was in flight; bail before resurrecting anything.
            guard !Task.isCancelled else {
                Self.log.info("Download of \(chapterId, privacy: .public) cancelled before completion")
                return
            }
            try await persist(chapterId: chapterId, manga: manga, chapter: chapter,
                              pageCount: fetchedCount, totalBytes: totalBytes, state: "completed")
            states[chapterId] = .completed
            Self.log.info("Chapter \(chapterId, privacy: .public) downloaded (\(totalBytes, privacy: .public) bytes)")
            emit(.completed(chapterId: chapterId))
        } catch {
            if Task.isCancelled { return }
            if let chapterDir = try? chapterDirectory(mangaId: manga.id, chapterId: chapterId) {
                try? FileManager.default.removeItem(at: chapterDir)
            }
            let message = error.localizedDescription
            states[chapterId] = .failed(message)
            do {
                try await persist(chapterId: chapterId, manga: manga, chapter: chapter,
                                  pageCount: fetchedCount, totalBytes: 0, state: "failed")
            } catch {
                Self.log.error("Could not persist failed chapter \(chapterId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            Self.log.error("Chapter \(chapterId, privacy: .public) download failed: \(message, privacy: .public)")
            emit(.failed(chapterId: chapterId, message: message))
        }
    }

    /// Fetches a novel chapter and serializes its paragraphs to a single
    /// `content.json` inside the chapter directory. Returns the paragraph
    /// count and the serialized byte count.
    private func downloadNovelContent(manga: HomeItem, chapterId: String) async throws -> (Int, Int64) {
        guard let novelRepository else {
            throw NSError(domain: "dev.atsumaru.DownloadManager", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Novel downloads are unavailable"])
        }
        let novel = try await novelRepository.novelChapter(mangaId: manga.id, chapterId: chapterId)
        let paragraphs = novel.paragraphs
        guard !paragraphs.isEmpty else {
            throw NSError(domain: "dev.atsumaru.DownloadManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Novel chapter has no content"])
        }
        states[chapterId] = .downloading(0)
        emit(.progress(chapterId: chapterId, fraction: 0))
        for (index, _) in paragraphs.enumerated() {
            let fraction = Double(index + 1) / Double(paragraphs.count)
            states[chapterId] = .downloading(fraction)
            emit(.progress(chapterId: chapterId, fraction: fraction))
        }
        let dir = try chapterDirectory(mangaId: manga.id, chapterId: chapterId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Self.excludeFromBackup(dir)
        let data = try JSONEncoder().encode(paragraphs)
        try data.write(to: dir.appendingPathComponent(Self.novelContentFileName, isDirectory: false),
                       options: .atomic)
        return (paragraphs.count, Int64(data.count))
    }

    private func downloadMangaPages(manga: HomeItem, chapter: Chapter) async throws -> (Int, Int64) {
        let chapterId = chapter.id
        let readChapter = try await readRepository.chapter(mangaId: manga.id, chapterId: chapterId)
        let pages = readChapter.pages
        let pageCount = pages.count
        guard pageCount > 0 else {
            throw NSError(domain: "dev.atsumaru.DownloadManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Chapter has no pages"])
        }
        pageProgress[chapterId] = Array(repeating: 0.0, count: pageCount)
        states[chapterId] = .downloading(0)
        emit(.progress(chapterId: chapterId, fraction: 0))

        var totalBytes: Int64 = 0
        try await withThrowingTaskGroup(of: (Int, Int64).self) { group in
            var iterator = pages.enumerated().makeIterator()
            func addNext() {
                if let (index, page) = iterator.next() {
                    group.addTask {
                        let bytes = try await self.downloadPage(manga: manga, chapterId: chapterId,
                                                                page: page, pageIndex: index, pageCount: pageCount)
                        return (index, bytes)
                    }
                }
            }
            for _ in 0..<min(Self.pageConcurrency, pageCount) { addNext() }
            for try await (index, bytes) in group {
                totalBytes += bytes
                updatePageProgress(chapterId: chapterId, pageIndex: index, pageCount: pageCount)
                addNext()
            }
        }
        return (pageCount, totalBytes)
    }

    private func downloadPage(manga: HomeItem, chapterId: String, page: PageImage,
                              pageIndex: Int, pageCount: Int) async throws -> Int64 {
        guard let url = ImageURLBuilder.page(page.image) else {
            throw NSError(domain: "dev.atsumaru.DownloadManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid image URL for page \(page.number)"])
        }
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "dev.atsumaru.DownloadManager", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(status) for page \(page.number)"])
        }
        guard !Task.isCancelled else { throw CancellationError() }
        let ext = Self.pathExtension(from: page.image) ?? "webp"
        let dir = try chapterDirectory(mangaId: manga.id, chapterId: chapterId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Self.excludeFromBackup(dir)
        let dest = dir.appendingPathComponent("\(page.number)", isDirectory: false)
            .appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try data.write(to: dest, options: .atomic)
        return Int64(data.count)
    }

    /// Marks a directory (and its contents) so iCloud does not back it up.
    /// Downloaded chapters are re-fetchable, so backing them up wastes quota.
    private static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = url
        try url.setResourceValues(values)
    }

    private func updatePageProgress(chapterId: String, pageIndex: Int, pageCount: Int) {
        guard var arr = pageProgress[chapterId] else { return }
        arr[pageIndex] = 1.0
        pageProgress[chapterId] = arr
        let completedPages = arr.reduce(0, +)
        let fraction = completedPages / Double(max(pageCount, 1))
        states[chapterId] = .downloading(fraction)
        Self.log.debug("Page \(pageIndex + 1, privacy: .public)/\(pageCount, privacy: .public) of \(chapterId, privacy: .public)")
        emit(.progress(chapterId: chapterId, fraction: fraction))
    }

    private func persist(chapterId: String, manga: HomeItem, chapter: Chapter,
                         pageCount: Int, totalBytes: Int64, state: String) async throws {
        guard let store else {
            throw NSError(
                domain: "dev.atsumaru.DownloadManager",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Download storage is unavailable"]
            )
        }
        let snapshot = DownloadedChapterSnapshot(
            chapterId: chapterId,
            mangaId: manga.id,
            mangaTitle: manga.title,
            chapterTitle: chapter.title,
            kind: Self.kind(for: manga),
            pageCount: pageCount,
            totalBytes: totalBytes,
            completedAt: Date(),
            state: state
        )
        try await store.save(snapshot)
    }

    private func evictChapter(_ record: DownloadedChapterSnapshot) async {
        // Cancel any in-flight download first: a running task would otherwise
        // re-persist its record and resurrect the deleted chapter.
        tasks[record.chapterId]?.task.cancel()
        tasks[record.chapterId] = nil
        pageProgress[record.chapterId] = nil
        if let chapterDir = try? chapterDirectory(mangaId: record.mangaId, chapterId: record.chapterId) {
            try? FileManager.default.removeItem(at: chapterDir)
            let mangaDir = chapterDir.deletingLastPathComponent()
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: mangaDir.path),
               contents.isEmpty {
                try? FileManager.default.removeItem(at: mangaDir)
            }
        }
        try? await store?.delete(chapterId: record.chapterId)
        states[record.chapterId] = nil
        Self.log.info("Evicted chapter \(record.chapterId, privacy: .public)")
    }

    private static func kind(for manga: HomeItem) -> String {
        let medium = manga.medium.lowercased()
        return medium.contains("novel") ? "novel" : "manga"
    }

    private func chapterDirectory(mangaId: String, chapterId: String) throws -> URL {
        let root = baseDirectory.standardizedFileURL
        let candidate = root
            .appendingPathComponent(mangaId, isDirectory: true)
            .appendingPathComponent(chapterId, isDirectory: true)
            .standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPrefix) else {
            throw NSError(
                domain: "dev.atsumaru.DownloadManager",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Invalid download identifier"]
            )
        }
        return candidate
    }

    public static func defaultDownloadsURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Inspects a relative image path and returns a lowercase file extension
    /// (without a leading dot), or nil if none can be derived.
    public static func pathExtension(from path: String) -> String? {
        let trimmed = String(path.split(separator: "?").first ?? "")
        guard let dotIdx = trimmed.lastIndex(of: ".") else { return nil }
        let ext = String(trimmed[trimmed.index(after: dotIdx)...]).lowercased()
        guard (1...5).contains(ext.count) else { return nil }
        return ext
    }

    private static func makeDefaultSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        return config
    }
}