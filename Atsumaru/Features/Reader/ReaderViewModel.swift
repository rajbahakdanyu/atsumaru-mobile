import SwiftUI
import Core
import ImageIO
import os

private let logger = Logger(subsystem: "dev.atsumaru.app", category: "progress")

@MainActor
final class ProgressSaveDebouncer {
    private var task: Task<Void, Never>?

    func schedule(_ operation: @escaping @MainActor () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

@Observable
@MainActor
final class ReaderViewModel {
    let mangaId: String
    private(set) var chapter: Chapter
    private let readRepository: any ReadRepository
    private let progressStore: ProgressStore?
    private let downloadManager: DownloadManager
    private let mangaRepository: any MangaRepository

    var readChapter: ReadChapter?
    var mode: ReaderMode = .paged
    var currentPage: Int = 0
    var isLoading = false
    var loadFailed = false
    /// The chapter that follows the current one in reading order; nil while
    /// unknown (still loading, offline, or last chapter).
    private(set) var nextChapter: Chapter?

    /// File URLs of the locally downloaded pages; nil while reading over the
    /// network. The view loads these directly from disk instead of fetching.
    private(set) var localPageURLs: [URL]?

    private let saveDebouncer = ProgressSaveDebouncer()

    init(mangaId: String, chapter: Chapter, readRepository: any ReadRepository,
         progressStore: ProgressStore?, downloadManager: DownloadManager,
         mangaRepository: any MangaRepository) {
        self.mangaId = mangaId
        self.chapter = chapter
        self.readRepository = readRepository
        self.progressStore = progressStore
        self.downloadManager = downloadManager
        self.mangaRepository = mangaRepository
    }

    var pageCount: Int { readChapter?.pages.count ?? 0 }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        // Offline first: a completed download is read entirely from disk —
        // the /api/read/chapter fetch is skipped, so no network is required.
        let local = await downloadManager.localContent(for: chapter.id)
        if case .pages(let urls)? = local {
            loadLocalPages(urls)
            await resolveNextChapter()
            return
        }
        do {
            let fetched = try await readRepository.chapter(mangaId: mangaId, chapterId: chapter.id)
            readChapter = fetched
            localPageURLs = nil
            if let local = progressStore?.progress(mangaId: mangaId, chapterId: chapter.id),
               fetched.pages.indices.contains(local.pageIndex) {
                currentPage = local.pageIndex
            } else {
                currentPage = 0
            }
            loadFailed = false
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            loadFailed = true
        }
        await resolveNextChapter()
    }

    /// Builds the reader's page model from local page files. `image` stays
    /// empty (the view uses `localPageURLs` directly) and the aspect comes
    /// from the file header so the downsampling cap matches remote pages.
    private func loadLocalPages(_ urls: [URL]) {
        let pages = urls.enumerated().map { index, fileURL in
            PageImage(id: "\(chapter.id)-\(index)", image: "", number: index,
                      width: 0, height: 0,
                      aspectRatio: Self.fileAspectRatio(of: fileURL) ?? 1)
        }
        readChapter = ReadChapter(
            id: chapter.id,
            title: chapter.title,
            scanlationMangaId: chapter.scanlationMangaId ?? "",
            pages: pages
        )
        localPageURLs = urls
        if let local = progressStore?.progress(mangaId: mangaId, chapterId: chapter.id),
           pages.indices.contains(local.pageIndex) {
            currentPage = local.pageIndex
        } else {
            currentPage = 0
        }
        loadFailed = false
    }

    /// Reads pixel dimensions from the image header without decoding the
    /// bitmap. Falls back to the square cap when the header can't be read.
    private static func fileAspectRatio(of fileURL: URL) -> Double? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0 else { return nil }
        let orientationValue = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let isRotated = [5, 6, 7, 8].contains(orientationValue)
        if isRotated {
            return height / width
        } else {
            return width / height
        }
    }

    func scheduleProgressSave() {
        saveDebouncer.schedule { [weak self] in
            await self?.saveProgress()
        }
    }

    func saveProgressNow() {
        saveDebouncer.cancel()
        Task { await self.saveProgress() }
    }

    /// Awaitable variant of `saveProgressNow` for paths that must persist the
    /// outgoing state before moving on (e.g. switching chapters).
    func saveProgressNowAsync() async {
        saveDebouncer.cancel()
        await saveProgress()
    }

    @MainActor
    func saveProgress() async {
        guard let readChapter, pageCount > 0 else { return }
        let page = max(0, min(currentPage, pageCount - 1))
        let frac = Double(page + 1) / Double(pageCount)
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let update = ProgressUpdate(
            mangaScanlationId: readChapter.scanlationMangaId,
            mangaId: mangaId,
            chapterId: readChapter.id,
            page: page,
            frac: frac,
            pages: pageCount,
            ts: ts,
            strip: mode == .strip,
            nextChapterId: nil,
            readMs: 0,
            // Last page = chapter finished; the server uses this for
            // Continue Reading / history and the row's read state.
            completed: frac >= 0.999
        )
        do {
            try progressStore?.save(ProgressState(
                mangaId: mangaId, chapterId: readChapter.id,
                pageIndex: page, updatedAt: Date()
            ))
        } catch {
            logger.error("local progress save failed for chapter \(readChapter.id, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        guard !readChapter.scanlationMangaId.isEmpty else { return }
        do {
            try await readRepository.updateProgress(update)
        } catch {
            if let apiError = error as? ApiError {
                switch apiError {
                case .http(401), .http(403):
                    logger.debug("progress save unauthorized for chapter \(readChapter.id, privacy: .public)")
                default:
                    logger.error("progress save failed for chapter \(readChapter.id, privacy: .public): \(String(describing: apiError), privacy: .public)")
                }
            } else {
                logger.error("progress save failed for chapter \(readChapter.id, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Site parity (`filter(scanId) → findIndex(current) → [idx+1]`), made
    /// order safe: chapters are sorted ascending by index/number first, so
    /// the next element is always the next chapter in READING order
    /// regardless of the array's original direction.
    private func resolveNextChapter() async {
        nextChapter = nil
        guard let scanId = chapter.scanlationMangaId, !scanId.isEmpty else { return }
        do {
            let page = try await mangaRepository.page(id: mangaId)
            let ordered = page.chapters
                .filter { $0.scanlationMangaId == scanId }
                .sorted { lhs, rhs in
                    switch (lhs.index, rhs.index) {
                    case let (li?, ri?):
                        if li != ri { return li < ri }
                        return lhs.number < rhs.number
                    case (nil, nil):
                        return lhs.number < rhs.number
                    case (nil, _?):
                        return false
                    case (_?, nil):
                        return true
                    }
                }
            guard let idx = ordered.firstIndex(where: { $0.id == chapter.id }),
                  ordered.indices.contains(idx + 1) else { return }
            nextChapter = ordered[idx + 1]
        } catch {
            nextChapter = nil  // offline: no auto-advance, current chapter still readable
        }
    }

    /// Loads another chapter in place (auto-advance). Saves the outgoing
    /// chapter's progress first, then resets and reloads.
    func switchChapter(to newChapter: Chapter) async {
        await saveProgressNowAsync()
        chapter = newChapter
        readChapter = nil
        localPageURLs = nil
        currentPage = 0
        loadFailed = false
        await load()
    }
}
