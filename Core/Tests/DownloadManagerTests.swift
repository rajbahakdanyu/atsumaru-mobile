import Foundation
import Testing
import SwiftData
@testable import Core

@Suite(.serialized)
struct DownloadManagerTests {

    private static func makeStubURLProtocol(json: String, status: Int = 200, bodyData: Data = Data(repeating: 0xFF, count: 256)) {
        StubURLProtocol.handler = { request in
            guard let url = request.url else {
                throw NSError(domain: "test", code: -1, userInfo: nil)
            }
            let path = url.path
            let resp = HTTPURLResponse(url: url, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
            if path == "/api/read/chapter" {
                return (resp, Data(json.utf8))
            }
            return (resp, bodyData)
        }
    }

    private func makeBetaURLConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return config
    }

    private func makeManga() -> HomeItem {
        HomeItem(id: "m1", title: "Test Manga", image: "", medium: "Comic")
    }

    /// Runs `operation`, throwing if it does not finish within `seconds` so a
    /// hang surfaces as a test failure instead of stalling the suite.
    private static func withTimeout<T: Sendable>(seconds: UInt64,
                                                 _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw NSError(domain: "test", code: -100,
                              userInfo: [NSLocalizedDescriptionKey: "Timed out after \(seconds)s"])
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    @Test func enqueueTransitionsToCompleted() async throws {
        let json = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696},{"id":"ch1-1","image":"/static/pages/scan/ch1/1.webp","number":1,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        Self.makeStubURLProtocol(json: json)

        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)

        let manga = makeManga()
        let chapter = try JSONDecoder().decode(Chapter.self,
                                               from: Data(#"{"id":"ch1","title":"Chapter 1","number":1,"pageCount":2}"#.utf8))

        let stream = await manager.events()
        let collector = Task<DownloadEvent?, Never> {
            for await event in stream {
                switch event {
                case .completed(let cid) where cid == "ch1":
                    return event
                case .failed(let cid, _) where cid == "ch1":
                    return event
                default:
                    continue
                }
            }
            return nil
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        await manager.enqueue(manga: manga, chapter: chapter)

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            collector.cancel()
        }
        let event = await collector.value
        timeoutTask.cancel()

        guard event != nil else {
            Issue.record("Expected completion event, got nil/timeout")
            return
        }
        if case .failed(_, let msg) = event {
            Issue.record("Expected completed, got failed: \(msg)")
        }

        let state = await manager.state(for: "ch1")
        #expect(state == .completed)

        let chapterDir = tmpDir.appendingPathComponent("m1").appendingPathComponent("ch1")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: chapterDir.path)) ?? []
        #expect(files.count == 2)

        let records = await manager.listChapters()
        let record = try #require(records.first { $0.chapterId == "ch1" })
        #expect(record.state == "completed")
        #expect(record.pageCount == 2)
        #expect(record.totalBytes > 0)
    }

    @Test func enqueueReportsFailureForMissingPages() async throws {
        let config = makeBetaURLConfiguration()
        StubURLProtocol.handler = { request in
            guard let url = request.url else {
                throw NSError(domain: "test", code: -1, userInfo: nil)
            }
            let resp = HTTPURLResponse(url: url, statusCode: 500,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }

        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)

        let manga = makeManga()
        let chapter = try JSONDecoder().decode(Chapter.self,
                                               from: Data(#"{"id":"chE","title":"Chapter E","number":1,"pageCount":2}"#.utf8))

        let stream = await manager.events()
        let collector = Task<DownloadEvent?, Never> {
            for await event in stream {
                switch event {
                case .completed(let cid) where cid == "chE":
                    return event
                case .failed(let cid, _) where cid == "chE":
                    return event
                default:
                    continue
                }
            }
            return nil
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        await manager.enqueue(manga: manga, chapter: chapter)

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            collector.cancel()
        }
        let event = await collector.value
        timeoutTask.cancel()

        guard case .failed("chE", _) = event else {
            Issue.record("Expected failed event, got: \(String(describing: event))")
            return
        }

        let state = await manager.state(for: "chE")
        guard case .failed = state else {
            Issue.record("Expected failed state, got: \(state)")
            return
        }
    }

    @Test func awaitCompletionReturnsAfterTargetsComplete() async throws {
        // Regression: `awaitCompletion` used to `break` out of the switch
        // instead of the event loop, so it never returned. It must return
        // once the target chapter reaches a terminal state.
        let json = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        Self.makeStubURLProtocol(json: json)
        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)

        let manga = makeManga()
        let chapter = try JSONDecoder().decode(Chapter.self,
                                               from: Data(#"{"id":"ch1","title":"Chapter 1","number":1,"pageCount":1}"#.utf8))

        // The waiter starts BEFORE enqueueing, so the chapter is not yet in a
        // terminal state when awaitCompletion begins and it must exit via the
        // completion event. Before the labeled-loop fix this would hang
        // forever; the timeout turns such a hang into a failing test rather
        // than a stalled suite. (async let, not Task: cancelling the group
        // after timeout must propagate into the stream iteration.)
        try await Self.withTimeout(seconds: 10) {
            async let completion: Void = manager.awaitCompletion(["ch1"])
            await manager.enqueue(manga: manga, chapter: chapter)
            await completion
        }

        let state = await manager.state(for: "ch1")
        #expect(state == .completed)
    }

    @Test func noStorageCapEviction() async throws {
        // DownloadManager no longer evicts: enqueueing two chapters both
        // complete and both records remain regardless of size.
        let json = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        Self.makeStubURLProtocol(json: json)
        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)

        let manga = makeManga()
        let chapter1 = try JSONDecoder().decode(Chapter.self,
                                                 from: Data(#"{"id":"ch1","title":"Chapter 1","number":1,"pageCount":1}"#.utf8))
        let chapter2 = try JSONDecoder().decode(Chapter.self,
                                                 from: Data(#"{"id":"ch2","title":"Chapter 2","number":2,"pageCount":1}"#.utf8))

        try await Self.withTimeout(seconds: 10) {
            async let completion: Void = manager.awaitCompletion(["ch1", "ch2"])
            await manager.enqueue(manga: manga, chapter: chapter1)
            await manager.enqueue(manga: manga, chapter: chapter2)
            await completion
        }

        let records = await manager.listChapters()
        #expect(records.count == 2, "no cap: both records survive completion")
        #expect(records.allSatisfy { $0.state == "completed" })
    }

    @Test func pathExtensionEdgeCases() {
        #expect(DownloadManager.pathExtension(from: "/static/pages/scan/ch1/0.webp") == "webp")
        #expect(DownloadManager.pathExtension(from: "/static/pages/x/1.JPEG") == "jpeg")
        #expect(DownloadManager.pathExtension(from: "/static/pages/x/1.webp?token=abc") == "webp")
        #expect(DownloadManager.pathExtension(from: "/static/pages/noext") == nil)
        #expect(DownloadManager.pathExtension(from: "/static/pages/x/1.") == nil)
        #expect(DownloadManager.pathExtension(from: "/static/pages/x/.git") == "git")
        #expect(DownloadManager.pathExtension(from: "/static/pages/x/.hidden") == nil)
    }

    @Test func pathTraversalIdentifiersCannotEscapeDownloadRoot() async throws {
        let json = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        Self.makeStubURLProtocol(json: json)
        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-parent-\(UUID().uuidString)", isDirectory: true)
        let root = parent.appendingPathComponent("downloads", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: root, sessionConfiguration: config)
        let manga = HomeItem(id: "..", title: "Traversal", image: "", medium: "Comic")
        let chapter = try JSONDecoder().decode(
            Chapter.self,
            from: Data(#"{"id":"escaped","title":"Chapter","number":1,"pageCount":1}"#.utf8)
        )

        let event = try await Self.collectTerminalEvent(manager: manager, chapterId: "escaped") {
            await manager.enqueue(manga: manga, chapter: chapter)
        }

        guard case .failed = event else {
            Issue.record("Expected traversal download to fail")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent("escaped").path))
    }

    // MARK: - Novel download pipeline

    @Test func enqueueDownloadsNovelChapterToContentJSON() async throws {
        let paragraphs = ["First paragraph.", "Second paragraph.", "Third paragraph."]
        let novelJSON = """
        {"readNovelChapter":{"id":"chN","title":"Chapter N","number":1,"scanlationMangaId":"sm1",
         "paragraphs":["First paragraph.","Second paragraph.","Third paragraph."],"wordCount":6}}
        """
        StubURLProtocol.handler = { request in
            guard let url = request.url else {
                throw NSError(domain: "test", code: -1, userInfo: nil)
            }
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path == "/api/read/novelChapter" {
                return (resp, Data(novelJSON.utf8))
            }
            return (resp, Data(repeating: 0xFF, count: 64))
        }

        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let novelRepo = LiveNovelRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, novelRepository: novelRepo,
                                      store: store, baseDirectory: tmpDir,
                                      sessionConfiguration: config)

        // medium "Novel" routes the download to the novel pipeline.
        let manga = HomeItem(id: "mN", title: "Test Novel", image: "", medium: "Novel")
        // pageCount is 0 for novel chapters; the record must persist the
        // actual paragraph count instead.
        let chapter = try JSONDecoder().decode(Chapter.self,
                                               from: Data(#"{"id":"chN","title":"Chapter N","number":1,"pageCount":0}"#.utf8))

        let event = try await Self.collectTerminalEvent(manager: manager, chapterId: "chN") {
            await manager.enqueue(manga: manga, chapter: chapter)
        }
        guard case .completed = event else {
            Issue.record("Expected completed, got: \(String(describing: event))")
            return
        }

        let state = await manager.state(for: "chN")
        #expect(state == .completed)

        let record = try #require(await manager.listChapters().first { $0.chapterId == "chN" })
        #expect(record.state == "completed")
        #expect(record.kind == "novel")
        #expect(record.pageCount == paragraphs.count)
        #expect(record.totalBytes > 0)

        let contentURL = tmpDir.appendingPathComponent("mN").appendingPathComponent("chN")
            .appendingPathComponent("content.json")
        let data = try #require(try? Data(contentsOf: contentURL))
        #expect(try JSONDecoder().decode([String].self, from: data) == paragraphs)

        #expect(await manager.localContent(for: "chN") == .novelParagraphs(paragraphs))
    }

    // MARK: - Offline-read API

    @Test func localContentReturnsSortedPageURLsForManga() async throws {
        let json = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696},{"id":"ch1-1","image":"/static/pages/scan/ch1/1.webp","number":1,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        Self.makeStubURLProtocol(json: json)
        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)
        let manga = makeManga()
        let chapter = try JSONDecoder().decode(Chapter.self,
                                               from: Data(#"{"id":"ch1","title":"Chapter 1","number":1,"pageCount":2}"#.utf8))
        _ = try await Self.collectTerminalEvent(manager: manager, chapterId: "ch1") {
            await manager.enqueue(manga: manga, chapter: chapter)
        }

        let expected0 = tmpDir.appendingPathComponent("m1").appendingPathComponent("ch1")
            .appendingPathComponent("0").appendingPathExtension("webp")
        let expected1 = tmpDir.appendingPathComponent("m1").appendingPathComponent("ch1")
            .appendingPathComponent("1").appendingPathExtension("webp")
        #expect(await manager.localContent(for: "ch1") == .pages([expected0, expected1]))
        #expect(await manager.localContent(for: "missing") == nil)
    }

    @Test func localContentReturnsNilWhenRecordNotCompleted() async throws {
        let store = try await DownloadStore.makeInMemory()
        try await store.save(DownloadedChapterSnapshot(
            chapterId: "chF", mangaId: "m1", mangaTitle: "M1", chapterTitle: "F",
            kind: "manga", pageCount: 1, totalBytes: 10,
            completedAt: Date(), state: "failed"))
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        // Files exist on disk, but the persisted record is not completed, so
        // the offline-read API must refuse to serve them.
        let chapterDir = tmpDir.appendingPathComponent("m1").appendingPathComponent("chF")
        try FileManager.default.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        try Data([0xFF]).write(to: chapterDir.appendingPathComponent("0.webp"))

        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)
        #expect(await manager.localContent(for: "chF") == nil)
    }

    // MARK: - Launch restoration

    @Test func restoreInterruptedDownloadsMarksNonTerminalRecordsFailed() async throws {
        let store = try await DownloadStore.makeInMemory()
        func snapshot(_ id: String, state: String) -> DownloadedChapterSnapshot {
            DownloadedChapterSnapshot(chapterId: id, mangaId: "m1", mangaTitle: "M1",
                                      chapterTitle: id, kind: "manga", pageCount: 1,
                                      totalBytes: 0, completedAt: Date(), state: state)
        }
        try await store.save(snapshot("chQ", state: "queued"))
        try await store.save(snapshot("chD", state: "downloading"))
        try await store.save(snapshot("chC", state: "completed"))
        try await store.save(snapshot("chF", state: "failed"))

        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: FileManager.default.temporaryDirectory,
                                      sessionConfiguration: config)
        await manager.restoreInterruptedDownloads()

        let records = await manager.listChapters()
        #expect(records.first { $0.chapterId == "chQ" }?.state == "failed")
        #expect(records.first { $0.chapterId == "chD" }?.state == "failed")
        #expect(records.first { $0.chapterId == "chC" }?.state == "completed")
        #expect(records.first { $0.chapterId == "chF" }?.state == "failed")
    }

    // MARK: - Effective state mapping

    @Test func effectiveStateMapsPersistedFailureToFailed() {
        // Regression: a persisted "failed" record with no live state (after
        // relaunch) used to surface as .queued, hiding the failure.
        guard case .failed = DownloadState.effective(live: .queued, persisted: "failed") else {
            Issue.record("persisted failed + no live state must map to .failed")
            return
        }
        #expect(DownloadState.effective(live: .queued, persisted: "completed") == .completed)
        #expect(DownloadState.effective(live: .queued, persisted: "queued") == .queued)
        #expect(DownloadState.effective(live: .queued, persisted: "downloading") == .queued)
        #expect(DownloadState.effective(live: .downloading(0.5), persisted: "queued") == .downloading(0.5))
        #expect(DownloadState.effective(live: .completed, persisted: "completed") == .completed)
        #expect(DownloadState.effective(live: .failed("boom"), persisted: "failed") == .failed("boom"))
    }

    // MARK: - Scheduler retry semantics

    private final class RequestCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() { lock.lock(); value += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    @Test func refreshAndDownloadRetriesFailedAndSkipsCompleted() async throws {
        let chapterReads = RequestCounter()
        let bookmarksJSON = #"{"items":[{"id":"m1","title":"M1","medium":"Comic"}]}"#
        let pageJSON = #"{"mangaPage":{"id":"m1","title":"M1","genres":[],"tags":[],"authors":[],"chapters":[{"id":"ch1","title":"Chapter 1","number":1,"pageCount":1}],"recommendations":[],"relations":[]}}"#
        let chapterJSON = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        StubURLProtocol.handler = { request in
            guard let url = request.url else {
                throw NSError(domain: "test", code: -1, userInfo: nil)
            }
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            switch url.path {
            case "/api/home2/bookmarks": return (resp, Data(bookmarksJSON.utf8))
            case "/api/manga/page": return (resp, Data(pageJSON.utf8))
            case "/api/read/chapter":
                chapterReads.increment()
                return (resp, Data(chapterJSON.utf8))
            default: return (resp, Data(repeating: 0xFF, count: 64))
            }
        }

        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)
        let scheduler = BackgroundScheduler(
            downloadManager: manager,
            libraryRepository: LiveLibraryRepository(client: APIClient(session: URLSession(configuration: config))),
            mangaRepository: LiveMangaRepository(client: APIClient(session: URLSession(configuration: config))))

        UserDefaults.standard.set(false, forKey: BackgroundScheduler.notificationsKey)
        // A transient failure must not permanently block the scheduler: a
        // "failed" record is retried, a "completed" one is skipped.
        try await store.save(DownloadedChapterSnapshot(
            chapterId: "ch1", mangaId: "m1", mangaTitle: "M1", chapterTitle: "Chapter 1",
            kind: "manga", pageCount: 1, totalBytes: 0,
            completedAt: Date(), state: "failed"))

        let first = try await Self.withTimeout(seconds: 10) { await scheduler.refreshAndDownload() }
        #expect(first)
        #expect(chapterReads.count == 1)
        let record = try #require(await manager.listChapters().first { $0.chapterId == "ch1" })
        #expect(record.state == "completed")

        let second = try await Self.withTimeout(seconds: 10) { await scheduler.refreshAndDownload() }
        #expect(second)
        #expect(chapterReads.count == 1, "completed record must be skipped, not re-downloaded")
    }

    @Test func refreshEstablishesBaselineThenDownloadsOnlyNewChapters() async throws {
        let mangaId = "baseline-\(UUID().uuidString)"
        let seenKey = "dev.atsumaru.app.seenChapters.\(mangaId)"
        UserDefaults.standard.removeObject(forKey: seenKey)
        defer { UserDefaults.standard.removeObject(forKey: seenKey) }
        let pageJSON = Box("""
        {"mangaPage":{"id":"\(mangaId)","title":"M1","genres":[],"tags":[],"authors":[],"chapters":[{"id":"old","title":"Old","number":1,"pageCount":1}],"recommendations":[],"relations":[]}}
        """)
        let chapterReads = RequestCounter()
        let config = makeBetaURLConfiguration()
        StubURLProtocol.handler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            switch url.path {
            case "/api/home2/bookmarks":
                return (response, Data(#"{"items":[{"id":"\#(mangaId)","title":"M1","medium":"Comic"}]}"#.utf8))
            case "/api/manga/page":
                return (response, Data(pageJSON.value.utf8))
            case "/api/read/chapter":
                chapterReads.increment()
                return (response, Data(#"{"readChapter":{"id":"new","title":"New","scanlationMangaId":"sm1","pages":[{"id":"new-0","image":"/static/pages/new/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696}]}}"#.utf8))
            default:
                return (response, Data(repeating: 0xFF, count: 64))
            }
        }
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)
        let scheduler = BackgroundScheduler(
            downloadManager: manager,
            libraryRepository: LiveLibraryRepository(client: APIClient(session: URLSession(configuration: config))),
            mangaRepository: LiveMangaRepository(client: APIClient(session: URLSession(configuration: config))))

        #expect(await scheduler.refreshAndDownload())
        #expect(chapterReads.count == 0, "the first observation establishes a baseline")

        pageJSON.value = """
        {"mangaPage":{"id":"\(mangaId)","title":"M1","genres":[],"tags":[],"authors":[],"chapters":[{"id":"new","title":"New","number":2,"pageCount":1},{"id":"old","title":"Old","number":1,"pageCount":1}],"recommendations":[],"relations":[]}}
        """
        #expect(await scheduler.refreshAndDownload())
        #expect(chapterReads.count == 1)
        #expect(await manager.listChapters().map(\.chapterId) == ["new"])

        await manager.deleteChapter("new")
        #expect(await scheduler.refreshAndDownload())
        #expect(chapterReads.count == 1, "a manually deleted chapter must remain seen")
    }

    // MARK: - Delete races

    @Test func deleteChapterCancelsInFlightDownloadAndPreventsResurrection() async throws {
        let chapterJSON = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        let gate = DispatchSemaphore(value: 0)
        StubURLProtocol.handler = { request in
            guard let url = request.url else {
                throw NSError(domain: "test", code: -1, userInfo: nil)
            }
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.path == "/api/read/chapter" {
                return (resp, Data(chapterJSON.utf8))
            }
            // Page image request blocks until the test releases it.
            gate.wait()
            return (resp, Data(repeating: 0xFF, count: 64))
        }

        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config)
        let manga = makeManga()
        let chapter = try JSONDecoder().decode(Chapter.self,
                                               from: Data(#"{"id":"ch1","title":"Chapter 1","number":1,"pageCount":1}"#.utf8))
        await manager.enqueue(manga: manga, chapter: chapter)
        // Let the download start and block on the page image request.
        try await Task.sleep(nanoseconds: 500_000_000)

        await manager.deleteChapter("ch1")
        let chapterDir = tmpDir.appendingPathComponent("m1").appendingPathComponent("ch1")
        #expect(!FileManager.default.fileExists(atPath: chapterDir.path))
        #expect(await manager.listChapters().isEmpty)

        // Unblock the in-flight request; the cancelled download must bail
        // before persisting, so the record stays deleted.
        gate.signal()
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(await manager.listChapters().isEmpty, "cancelled download must not resurrect the record")
        let state = await manager.state(for: "ch1")
        #expect(state != .completed)
    }

    /// Enqueues via `trigger` after subscribing to the event stream, and
    /// returns the first terminal event for `chapterId`.
    private static func collectTerminalEvent(manager: DownloadManager,
                                             chapterId: String,
                                             trigger: () async -> Void) async throws -> DownloadEvent? {
        let stream = await manager.events()
        let collector = Task<DownloadEvent?, Never> {
            for await event in stream {
                switch event {
                case .completed(let cid) where cid == chapterId:
                    return event
                case .failed(let cid, _) where cid == chapterId:
                    return event
                default:
                    continue
                }
            }
            return nil
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        await trigger()
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000)
            collector.cancel()
        }
        let event = await collector.value
        timeoutTask.cancel()
        return event
    }
}