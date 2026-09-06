import SwiftUI
import Kingfisher
import Core

/// One user list's content: a poster grid of its manga; tapping a poster
/// pushes MangaDetailView.
struct ListDetailView: View {
    let listId: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.displayScale) private var displayScale
    @State private var detail: ListDetail?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let detail {
                if detail.items.isEmpty {
                    ContentUnavailableView("Empty list", systemImage: "list.bullet")
                } else {
                    ScrollView {
                        LazyVGrid(columns: PosterGrid.columns, spacing: 12) {
                            ForEach(detail.items) { item in
                                NavigationLink(value: item.mangaId) {
                                    posterCard(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .navigationTitle(detail.title ?? "List")
                }
            } else if loadFailed {
                ErrorStateView(error: .decoding) { Task { await load() } }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { MangaDetailView(mangaId: $0) }
        .task { if detail == nil, !loadFailed { await load() } }
    }

    private func load() async {
        do {
            detail = try await environment.libraryRepository.listDetail(id: listId)
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    @ViewBuilder
    private func posterCard(_ item: ListItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage.poster(item.poster.flatMap(ImageURLBuilder.poster), displayScale: displayScale)
                .scaledToFill()
                .frame(width: 108, height: 154)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.title ?? "Untitled")
                .font(.caption)
                .lineLimit(1)
        }
    }
}
