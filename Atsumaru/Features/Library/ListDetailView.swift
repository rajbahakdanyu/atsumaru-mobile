import SwiftUI
import Core

/// One user list's content: a poster grid of its manga; tapping a poster
/// pushes MangaDetailView.
struct ListDetailView: View {
    let listId: String

    @Environment(AppEnvironment.self) private var environment
    @State private var detail: ListDetail?
    @State private var loadFailed = false
    @State private var loadError: ApiError?

    var body: some View {
        Group {
            if let detail {
                if detail.items.isEmpty {
                    ContentUnavailableView("Empty list", systemImage: "list.bullet")
                } else {
                    ScrollView {
                        LazyVGrid(columns: PosterGrid.columns, spacing: PosterGrid.spacing) {
                            ForEach(detail.items) { item in
                                NavigationLink(value: item.mangaId) {
                                    Poster(title: item.title ?? "Untitled", image: item.poster)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .navigationTitle(detail.title ?? "List")
                    .refreshable { await load() }
                }
            } else if loadFailed {
                ErrorStateView(error: loadError ?? .decoding) { Task { await load() } }
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
            loadError = (error as? ApiError) ?? .decoding
            loadFailed = true
        }
    }
}
