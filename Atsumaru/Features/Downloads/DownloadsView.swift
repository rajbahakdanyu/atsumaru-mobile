import SwiftUI
import Kingfisher
import Core

/// Opens a downloaded chapter straight in the reader from the Downloads tab.
struct ChapterOpen: Hashable {
    let mangaId: String
    let chapter: Chapter
    let isNovel: Bool
}

struct DownloadsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.displayScale) private var displayScale
    @State private var viewModel: DownloadsViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Downloads")
                .navigationDestination(for: String.self) { mangaId in
                    MangaDetailView(mangaId: mangaId)
                }
                .navigationDestination(for: ChapterOpen.self) { open in
                    if open.isNovel {
                        NovelReaderView(mangaId: open.mangaId, chapter: open.chapter)
                    } else {
                        MangaReaderView(mangaId: open.mangaId, chapter: open.chapter)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            DownloadSettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .task {
            if viewModel == nil {
                viewModel = DownloadsViewModel(
                    downloadManager: environment.downloadManager,
                    backgroundScheduler: environment.backgroundScheduler
                )
            }
            await viewModel?.load()
        }
        .onDisappear {
            viewModel?.stopEventStream()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            @Bindable var vm = viewModel
            VStack(spacing: 0) {
                if let storageText = vm.storageText {
                    HStack {
                        Label(storageText, systemImage: "internaldrive")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await vm.deleteAll() }
                        } label: {
                            Text("Clear All")
                                .font(.footnote)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                List {
                    if vm.sections.isEmpty {
                        ContentUnavailableView(
                            "No downloads",
                            systemImage: "arrow.down.circle",
                            description: Text("Download chapters from a manga page to keep them offline.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(vm.sections) { section in
                            seriesSection(section)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @State private var expandedSeries: Set<String> = []

    /// One card per series (poster, title, aggregate status); tapping the
    /// card opens the manga. Expanding reveals the downloaded chapters, each
    /// tappable straight into the reader (works offline).
    @ViewBuilder
    private func seriesSection(_ section: DownloadsViewModel.DownloadSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink(value: section.mangaId) {
                    seriesHeader(section)
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation {
                        if expandedSeries.contains(section.id) {
                            expandedSeries.remove(section.id)
                        } else {
                            expandedSeries.insert(section.id)
                        }
                    }
                } label: {
                    Image(systemName: expandedSeries.contains(section.id) ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expandedSeries.contains(section.id) ? "Collapse chapters" : "Expand chapters")
            }
            .contextMenu {
                Button(role: .destructive) {
                    Task { await viewModel?.delete(mangaId: section.mangaId) }
                } label: {
                    Label("Remove all downloads", systemImage: "trash")
                }
            }
            if expandedSeries.contains(section.id) {
                ForEach(section.chapters) { row in
                    NavigationLink(value: ChapterOpen(
                        mangaId: section.mangaId,
                        chapter: Chapter(id: row.chapterId, title: row.chapterTitle, pageCount: row.pageCount),
                        isNovel: section.kind == "novel"
                    )) {
                        downloadRow(row)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel?.delete(row.chapterId) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func seriesHeader(_ section: DownloadsViewModel.DownloadSection) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let path = viewModel?.posterPath(for: section.mangaId),
                   let url = ImageURLBuilder.poster(path) {
                    KFImage.poster(url, displayScale: displayScale)
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(.thinMaterial)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 52, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(section.kind.capitalized) · \(section.chapterCount) chapter\(section.chapterCount == 1 ? "" : "s")\(section.sizeText.map { " · \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let fraction = section.inFlightFraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                } else if section.chapters.contains(where: { $0.state.isFailed }) {
                    Label("Some chapters failed", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Label("Ready offline", systemImage: "checkmark.icloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func downloadRow(_ row: DownloadsViewModel.DownloadRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.chapterTitle)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack(spacing: 8) {
                progressCapsule(for: row)
                Text(row.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let size = row.sizeText {
                    Text(size)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func progressCapsule(for row: DownloadsViewModel.DownloadRow) -> some View {
        switch row.state {
        case .queued:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .downloading(let fraction):
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .frame(maxWidth: 100)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}
