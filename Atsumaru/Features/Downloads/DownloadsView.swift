import SwiftUI
import Kingfisher
import Core

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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Settings get their own gear (HIG: gear belongs on
                        // the toolbar); Clear All stays in the overflow menu.
                        NavigationLink {
                            DownloadSettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                Task { await viewModel?.deleteAll() }
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
        }
        .task {
            if viewModel == nil {
                viewModel = DownloadsViewModel(
                    downloadManager: environment.downloadManager,
                    backgroundScheduler: environment.backgroundScheduler,
                    mangaRepository: environment.mangaRepository
                )
            }
            await viewModel?.load()
            await viewModel?.hydratePosters()
        }
        .onDisappear {
            viewModel?.stopEventStream()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if viewModel.sections.isEmpty {
                ContentUnavailableView(
                    "No downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Download chapters from a manga page to keep them offline.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .refreshable { await viewModel.refresh() }
            } else {
                // List with zero row insets: separators span the full width
                // (they follow the insets) while padding lives inside the
                // row — and native swipe-to-delete keeps working.
                List {
                    ForEach(viewModel.sections) { section in
                        NavigationLink(value: section.mangaId) {
                            seriesHeader(section)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(mangaId: section.mangaId) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(mangaId: section.mangaId) }
                            } label: {
                                Label("Remove all downloads", systemImage: "trash")
                            }
                        }
                    }
                    .listRowSeparator(.visible)
                }
                .listStyle(.plain)
                .refreshable { await viewModel.refresh() }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
            .clipShape(RoundedRectangle(cornerRadius: Poster.thumbCornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.subheadline)
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
                } else if section.failedCount > 0 {
                    Label(section.failedCount == section.chapterCount ? "Failed" : "\(section.failedCount) failed",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    // Local files — no cloud glyph.
                    Label("Ready offline", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
