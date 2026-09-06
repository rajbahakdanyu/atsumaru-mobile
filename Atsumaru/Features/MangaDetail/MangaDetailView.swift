import SwiftUI
import Core
import Kingfisher

struct MangaDetailView: View {
    let mangaId: String
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.displayScale) private var displayScale
    @State private var viewModel: MangaDetailViewModel?
    @State private var detailsExpanded = false
    @State private var selectedScanlatorId: String?
    /// Per-chapter download state for chapters that HAVE a download record.
    /// A missing key means "not downloaded". Values fold the live DownloadManager
    /// state onto the persisted record via `DownloadState.effective`.
    @State private var downloadStates: [String: DownloadState] = [:]
    @State private var isPollingDownloads = false
    @State private var pendingDeleteChapter: Chapter?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if let manga = viewModel?.manga {
                content(for: manga)
            } else if viewModel?.loadFailed == true {
                ContentUnavailableView {
                    Label("Couldn't load manga", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Something went wrong. Please try again.")
                } actions: {
                    Button("Retry") {
                        Task { await viewModel?.load() }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel?.manga?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Chapter.self) { chapter in
            if viewModel?.manga?.medium == "Novel" {
                NovelReaderView(mangaId: mangaId, chapter: chapter)
            } else {
                MangaReaderView(mangaId: mangaId, chapter: chapter)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MangaDetailViewModel(
                    mangaId: mangaId,
                    mangaRepository: environment.mangaRepository
                )
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(for manga: MangaPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(manga)
                detailsSection(manga)
                continueReadingButton(for: manga)
                chapterSection(manga)
            }
            .padding(.bottom, 24)
        }
        .task { await pollUntilIdle() }
        .confirmationDialog("Delete downloaded chapter?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Download", role: .destructive) {
                Task { await deletePendingChapter() }
            }
        } message: {
            Text("Only the offline copy is removed. You can download it again later.")
        }
    }

    @ViewBuilder
    private func header(_ manga: MangaPage) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let path = manga.poster?.image, let url = ImageURLBuilder.poster(path) {
                KFImage.poster(url, displayScale: displayScale)
                    .scaledToFill()
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Rectangle()
                    .fill(.thinMaterial)
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                if let status = manga.status, !status.isEmpty {
                    labeledRow("Status", status)
                }
                if let rating = manga.avgRating {
                    labeledRow("Rating", rating.formatted(.number.precision(.fractionLength(1))))
                }
                let authors = manga.authors.filter { $0.type?.lowercased() != "artist" }
                if !authors.isEmpty {
                    labeledRow("Author", authors.map(\.name).joined(separator: ", "))
                }
                let artists = manga.authors.filter { $0.type?.lowercased() == "artist" }
                if !artists.isEmpty {
                    labeledRow("Artist", artists.map(\.name).joined(separator: ", "))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func detailsSection(_ manga: MangaPage) -> some View {
        let genres = manga.genres.map(\.name)
        let tags = manga.tags.map(\.name)
        let hasSynopsis = !(manga.synopsis?.isEmpty ?? true)
        if hasSynopsis || !genres.isEmpty || !tags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.snappy) { detailsExpanded.toggle() }
                } label: {
                    HStack {
                        Text("Details")
                            .font(.headline)
                        Spacer()
                        Image(systemName: detailsExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)

                if hasSynopsis {
                    Text(manga.synopsis ?? "")
                        .font(.body)
                        .lineLimit(detailsExpanded ? nil : 2)
                }

                if !genres.isEmpty {
                    if detailsExpanded {
                        FlowLayout(spacing: 8) {
                            ForEach(genres, id: \.self) { chip($0) }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(genres, id: \.self) { chip($0) }
                            }
                        }
                    }
                }

                if detailsExpanded, !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { chip($0) }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func continueReadingButton(for manga: MangaPage) -> some View {
        if let chapter = startReadingChapter(in: manga) {
            NavigationLink(value: chapter) {
                Label("Continue Reading", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 16)
        }
    }

    private func startReadingChapter(in manga: MangaPage) -> Chapter? {
        // 1. Most recently read chapter from local progress (source of truth
        //    for where the user left off, including logged-out users).
        if let local = environment.progressStore?.latestProgress(mangaId: manga.id),
           let ch = manga.chapters.first(where: { $0.id == local.chapterId }) {
            return ch
        }
        // 2. Server-provided continue point.
        if let sr = manga.startReading, let ch = manga.chapters.first(where: { $0.id == sr.chapterId }) {
            return ch
        }
        // 3. Fall back to the latest chapter.
        if manga.chapters.isEmpty { return nil }
        return manga.chapters.max { ($0.index ?? Int.min, $0.number) < ($1.index ?? Int.min, $1.number) }
    }

    @ViewBuilder
    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCapsule()
    }

    @ViewBuilder
    private func chapterSection(_ manga: MangaPage) -> some View {
        if !manga.chapters.isEmpty {
            LazyVStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Chapters")
                        .font(.headline)
                    Spacer()
                    scanlatorMenu(manga)
                }
                let visible = manga.chapters.filter { chapter in
                    guard let sid = selectedScanlatorId else { return true }
                    return chapter.scanlationMangaId == sid
                }
                if visible.isEmpty {
                    Text("No chapters for this group.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(visible) { chapter in
                        chapterRow(chapter, manga: manga)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func scanlatorMenu(_ manga: MangaPage) -> some View {
        let groups = manga.scanlators ?? []
        if groups.count > 1 {
            Menu {
                Button {
                    selectedScanlatorId = nil
                } label: {
                    if selectedScanlatorId == nil {
                        Label("All groups", systemImage: "checkmark")
                    } else {
                        Text("All groups")
                    }
                }
                ForEach(groups) { group in
                    Button {
                        selectedScanlatorId = group.id
                    } label: {
                        if selectedScanlatorId == group.id {
                            Label(group.name, systemImage: "checkmark")
                        } else {
                            Text(group.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedScanlatorId.flatMap { id in groups.first(where: { $0.id == id })?.name } ?? "All groups")
                        .font(.caption)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func chapterRow(_ chapter: Chapter, manga: MangaPage) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: chapter) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.title)
                            .font(.body)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let created = chapter.createdAt?.dateFromEpochMs {
                                Text(created.relativeLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let translator = manga.translatorName(for: chapter) {
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(translator)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                    if chapter.progress != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            downloadIndicator(chapter, manga: manga)
        }
    }

    /// Trailing download control for a chapter row. Deliberately a SIBLING of
    /// the chapter's NavigationLink (not inside it), so tapping it never
    /// navigates to the reader.
    @ViewBuilder
    private func downloadIndicator(_ chapter: Chapter, manga: MangaPage) -> some View {
        switch downloadStates[chapter.id] {
        case nil:
            Button {
                enqueueDownload(chapter, manga: manga)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .some(.queued):
            // No cancel API on DownloadManager — non-interactive placeholder.
            Image(systemName: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(6)
        case .some(.downloading(let fraction)):
            ProgressView(value: fraction)
                .padding(6)
        case .some(.completed):
            Button {
                pendingDeleteChapter = chapter
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .some(.failed):
            Button {
                enqueueDownload(chapter, manga: manga)
            } label: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func enqueueDownload(_ chapter: Chapter, manga: MangaPage) {
        let item = HomeItem(
            id: manga.id,
            title: manga.title,
            image: manga.poster?.image ?? "",
            medium: manga.medium ?? "Comic"
        )
        Task {
            await environment.downloadManager.enqueue(manga: item, chapter: chapter)
            await pollUntilIdle()
        }
    }

    private func deletePendingChapter() async {
        guard let chapter = pendingDeleteChapter else { return }
        pendingDeleteChapter = nil
        await environment.downloadManager.deleteChapter(chapter.id)
        await refreshDownloadStates()
    }

    /// Refreshes the per-chapter download map, then polls once per second
    /// while any chapter is queued/in flight so a finished download flips to
    /// "completed" without an event-stream subscription on this screen.
    private func pollUntilIdle() async {
        guard !isPollingDownloads else { return }
        isPollingDownloads = true
        defer { isPollingDownloads = false }
        await refreshDownloadStates()
        while !Task.isCancelled, downloadStates.values.contains(where: isInFlight) {
            try? await Task.sleep(for: .seconds(1))
            await refreshDownloadStates()
        }
    }

    private func isInFlight(_ state: DownloadState) -> Bool {
        switch state {
        case .queued, .downloading: return true
        case .completed, .failed: return false
        }
    }

    private func refreshDownloadStates() async {
        let records = await environment.downloadManager.listChapters()
            .filter { $0.mangaId == mangaId }
        var updated: [String: DownloadState] = [:]
        for record in records {
            let live = await environment.downloadManager.state(for: record.chapterId)
            updated[record.chapterId] = DownloadState.effective(live: live, persisted: record.state)
        }
        downloadStates = updated
    }
}
