import Foundation

public enum DownloadState: Sendable, Equatable {
    case queued
    case downloading(Double)
    case completed
    case failed(String)
}

public enum DownloadEvent: Sendable, Equatable {
    case progress(chapterId: String, fraction: Double)
    case completed(chapterId: String)
    case failed(chapterId: String, message: String)
}

public actor DownloadManager {
    private let readRepository: any ReadRepository
    private let store: DownloadStore?
    private let baseDirectory: URL
    private let session: URLSession
    private let storageCapBytes: Int64

    private var states: [String: DownloadState] = [:]
    private var pageProgress: [String: [Double]] = [:]
    private var subscribers: [UUID: AsyncStream<DownloadEvent>.Continuation] = [:]

    public static let defaultStorageCapBytes: Int64 = 500 * 1024 * 1024

    public init(readRepository: any ReadRepository,
                store: DownloadStore? = nil,
                baseDirectory: URL? = nil,
                sessionConfiguration: URLSessionConfiguration? = nil,
                storageCapBytes: Int64 = DownloadManager.defaultStorageCapBytes) {
        self.readRepository = readRepository
        self.store = store
        self.baseDirectory = baseDirectory ?? Self.defaultDownloadsURL()
        self.storageCapBytes = storageCapBytes
        let config = sessionConfiguration ?? Self.makeDefaultSessionConfiguration()
        self.session = URLSession(configuration: config)
    }

    public func enqueue(manga: HomeItem, chapter: Chapter) async {
        let chapterId = chapter.id
        states[chapterId] = .queued
        await persist(chapterId: chapterId, manga: manga, chapter: chapter,
                      pageCount: chapter.pageCount, totalBytes: 0, state: "queued")
        emit(.progress(chapterId: chapterId, fraction: 0))
        Task { await self.runDownload(manga: manga, chapter: chapter) }
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

    public func storageEviction() async {
        guard let store else { return }
        let chapters = await store.all()
        let toEvictIds = Self.evictionOrder(chapters, cap: storageCapBytes)
        for chapterId in toEvictIds {
            if let record = chapters.first(where: { $0.chapterId == chapterId }) {
                await evictChapter(record)
            }
        }
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

    public func listChapters() async -> [DownloadedChapter] {
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

    private func runDownload(manga: HomeItem, chapter: Chapter) async {
        let chapterId = chapter.id
        do {
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
            for (index, page) in pages.enumerated() {
                let bytes = try await downloadPage(manga: manga, chapterId: chapterId,
                                                   page: page, pageIndex: index, pageCount: pageCount)
                totalBytes += bytes
                updatePageProgress(chapterId: chapterId, pageIndex: index, pageCount: pageCount)
            }
            states[chapterId] = .completed
            await persist(chapterId: chapterId, manga: manga, chapter: chapter,
                          pageCount: pageCount, totalBytes: totalBytes, state: "completed")
            await storageEviction()
            emit(.completed(chapterId: chapterId))
        } catch {
            let message = error.localizedDescription
            states[chapterId] = .failed(message)
            await persist(chapterId: chapterId, manga: manga, chapter: chapter,
                          pageCount: chapter.pageCount, totalBytes: 0, state: "failed")
            emit(.failed(chapterId: chapterId, message: message))
        }
    }

    private func downloadPage(manga: HomeItem, chapterId: String, page: PageImage,
                             pageIndex: Int, pageCount: Int) async throws -> Int64 {
        guard let url = ImageURLBuilder.page(page.image) else {
            throw NSError(domain: "dev.atsumaru.DownloadManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid image URL for page \(page.number)"])
        }
        let (data, _) = try await session.data(for: URLRequest(url: url))
        let ext = Self.pathExtension(from: page.image) ?? "webp"
        let dir = baseDirectory.appendingPathComponent(manga.id, isDirectory: true)
            .appendingPathComponent(chapterId, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(page.number)", isDirectory: false)
            .appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try data.write(to: dest)
        return Int64(data.count)
    }

    private func updatePageProgress(chapterId: String, pageIndex: Int, pageCount: Int) {
        guard var arr = pageProgress[chapterId] else { return }
        arr[pageIndex] = 1.0
        pageProgress[chapterId] = arr
        let completedPages = arr.reduce(0, +)
        let fraction = completedPages / Double(max(pageCount, 1))
        states[chapterId] = .downloading(fraction)
        emit(.progress(chapterId: chapterId, fraction: fraction))
    }

    private func persist(chapterId: String, manga: HomeItem, chapter: Chapter,
                         pageCount: Int, totalBytes: Int64, state: String) async {
        guard let store else { return }
        let record = DownloadedChapter(
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
        try? await store.save(record)
    }

    private func evictChapter(_ record: DownloadedChapter) async {
        let chapterDir = baseDirectory.appendingPathComponent(record.mangaId, isDirectory: true)
            .appendingPathComponent(record.chapterId, isDirectory: true)
        try? FileManager.default.removeItem(at: chapterDir)
        let mangaDir = chapterDir.deletingLastPathComponent()
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: mangaDir.path),
           contents.isEmpty {
            try? FileManager.default.removeItem(at: mangaDir)
        }
        try? await store?.delete(chapterId: record.chapterId)
        states[record.chapterId] = nil
    }

    private static func kind(for manga: HomeItem) -> String {
        let medium = manga.medium.lowercased()
        return medium.contains("novel") ? "novel" : "manga"
    }

    public static func evictionOrder(_ chapters: [DownloadedChapter], cap: Int64) -> [String] {
        let sorted = chapters.sorted { $0.completedAt > $1.completedAt }
        var running: Int64 = 0
        var evict: [String] = []
        for chapter in sorted {
            if running + chapter.totalBytes > cap {
                evict.append(chapter.chapterId)
            } else {
                running += chapter.totalBytes
            }
        }
        return evict.reversed()
    }

    public static func defaultDownloadsURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent("Downloads", isDirectory: true)
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
        config.allowsCellularAccess = false
        return config
    }
}