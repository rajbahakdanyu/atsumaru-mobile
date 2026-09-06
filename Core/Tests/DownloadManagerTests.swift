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

    @Test func evictionOrderEvictsOldestFirst() {
        let old = DownloadedChapterSnapshot(chapterId: "old", mangaId: "m1", mangaTitle: "M1",
                                            chapterTitle: "Old", kind: "manga", pageCount: 2,
                                            totalBytes: 50, completedAt: Date(timeIntervalSince1970: 100),
                                            state: "completed")
        let mid = DownloadedChapterSnapshot(chapterId: "mid", mangaId: "m1", mangaTitle: "M1",
                                            chapterTitle: "Mid", kind: "manga", pageCount: 2,
                                            totalBytes: 50, completedAt: Date(timeIntervalSince1970: 200),
                                            state: "completed")
        let newest = DownloadedChapterSnapshot(chapterId: "new", mangaId: "m1", mangaTitle: "M1",
                                               chapterTitle: "New", kind: "manga", pageCount: 2,
                                               totalBytes: 50, completedAt: Date(timeIntervalSince1970: 300),
                                               state: "completed")

        // Cap = 110: keep newest (50) + mid (50 + 50 = 100), evict old (would push to 150)
        #expect(DownloadManager.evictionOrder([old, mid, newest], cap: 110) == ["old"])
        // Cap = 50: keep newest only; evict [old, mid] (oldest first)
        #expect(DownloadManager.evictionOrder([old, mid, newest], cap: 50) == ["old", "mid"])
        // Cap = 200: keep all
        #expect(DownloadManager.evictionOrder([old, mid, newest], cap: 200) == [])
        // Cap = 0: evict everything (oldest first)
        #expect(DownloadManager.evictionOrder([old, mid, newest], cap: 0) == ["old", "mid", "new"])
    }

    @Test func evictionOrderEdgeCases() {
        let a = DownloadedChapterSnapshot(chapterId: "a", mangaId: "m1", mangaTitle: "M1",
                                          chapterTitle: "A", kind: "manga", pageCount: 1,
                                          totalBytes: 0, completedAt: Date(timeIntervalSince1970: 100),
                                          state: "completed")
        let b = DownloadedChapterSnapshot(chapterId: "b", mangaId: "m1", mangaTitle: "M1",
                                          chapterTitle: "B", kind: "manga", pageCount: 1,
                                          totalBytes: 10, completedAt: Date(timeIntervalSince1970: 200),
                                          state: "completed")

        // Exactly at cap: a zero-byte item never forces eviction of a fitting item.
        #expect(DownloadManager.evictionOrder([b], cap: 10) == [])
        // A chapter larger than the entire cap is evicted.
        #expect(DownloadManager.evictionOrder([b], cap: 5) == ["b"])
        // Zero-size items never evict anything and are kept in place.
        #expect(DownloadManager.evictionOrder([a, b], cap: 10) == [])
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

    @Test func storageEvictionDeletesOldestFilesAndRecord() async throws {
        // cap = 1 byte forces automatic eviction of any completed chapter, since
        // totalBytes always exceeds the cap. The LRU ordering is unit-tested
        // elsewhere in `evictionOrderEvictsOldestFirst`; here we assert the
        // eviction deletes both the record and the on-disk page files.
        let json = #"{"readChapter":{"id":"ch1","title":"Chapter 1","scanlationMangaId":"sm1","pages":[{"id":"ch1-0","image":"/static/pages/scan/ch1/0.webp","number":0,"width":960,"height":1378,"aspectRatio":0.696}]}}"#
        Self.makeStubURLProtocol(json: json)
        let config = makeBetaURLConfiguration()
        let repo = LiveReadRepository(client: APIClient(session: URLSession(configuration: config)))
        let store = try await DownloadStore.makeInMemory()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let manager = DownloadManager(readRepository: repo, store: store,
                                      baseDirectory: tmpDir, sessionConfiguration: config,
                                      storageCapBytes: 1)

        let manga = makeManga()
        let chapter = try JSONDecoder().decode(Chapter.self,
                                               from: Data(#"{"id":"ch1","title":"Chapter 1","number":1,"pageCount":1}"#.utf8))

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

        // Auto-eviction at the end of enqueue should have removed the chapter.
        let recordsAfter = await manager.listChapters()
        #expect(recordsAfter.count == 0)
        let chapterDir = tmpDir.appendingPathComponent("m1").appendingPathComponent("ch1")
        #expect(!FileManager.default.fileExists(atPath: chapterDir.path))
    }
}