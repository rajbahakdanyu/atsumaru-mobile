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
        HomeItem(id: "m1", title: "Test Manga", image: "", smallImage: "",
                 mediumImage: "", largeImage: "", isAdult: false, type: "Manga",
                 medium_: "Comic", mbRating: 8.0, views: nil, createdAt: nil, updatedAt: nil)
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