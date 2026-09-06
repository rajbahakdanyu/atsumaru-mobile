import SwiftUI
import Core
import ImageIO

@Observable
@MainActor
final class ReaderViewModel {
    let mangaId: String
    let chapter: Chapter
    private let readRepository: any ReadRepository
    private let progressStore: ProgressStore?
    private let downloadManager: DownloadManager

    var readChapter: ReadChapter?
    var mode: ReaderMode = .paged
    var currentPage: Int = 0
    var isLoading = false
    var loadFailed = false

    /// File URLs of the locally downloaded pages; nil while reading over the
    /// network. The view loads these directly from disk instead of fetching.
    private(set) var localPageURLs: [URL]?

    private var saveTask: Task<Void, Never>?

    init(mangaId: String, chapter: Chapter, readRepository: any ReadRepository,
         progressStore: ProgressStore?, downloadManager: DownloadManager) {
        self.mangaId = mangaId
        self.chapter = chapter
        self.readRepository = readRepository
        self.progressStore = progressStore
        self.downloadManager = downloadManager
    }

    var pageCount: Int { readChapter?.pages.count ?? 0 }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        // Offline first: a completed download is read entirely from disk —
        // the /api/read/chapter fetch is skipped, so no network is required.
        let local = await downloadManager.localContent(for: chapter.id)
        if case .pages(let urls)? = local {
            loadLocalPages(urls)
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
              height > 0 else { return nil }
        return width / height
    }

    func scheduleProgressSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            if Task.isCancelled { return }
            await self?.saveProgress()
        }
    }

    func saveProgressNow() {
        saveTask?.cancel()
        saveTask = nil
        Task { await self.saveProgress() }
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
            readMs: 0
        )
        try? progressStore?.save(ProgressState(mangaId: mangaId, chapterId: readChapter.id, pageIndex: page, updatedAt: Date()))
        try? await readRepository.updateProgress(update)
    }
}