import SwiftUI
import Core

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel?.isLoading == true && (viewModel?.rails.isEmpty ?? true) {
                    LoadingSkeletonView()
                        .padding(.top, 40)
                } else if let error = viewModel?.error, viewModel?.rails.isEmpty == true {
                    ErrorStateView(error: error) { Task { await viewModel?.load() } }
                        .padding(.top, 40)
                } else if viewModel?.rails.isEmpty == true {
                    EmptyStateView(message: "Nothing here yet. Pull to refresh or try again later.")
                        .padding(.top, 40)
                } else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(viewModel?.rails ?? [], id: \.0.rawValue) { rail in
                            RailSection(title: rail.0.displayName, items: rail.1)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Atsumaru")
            .navigationDestination(for: String.self) { id in
                MangaDetailView(mangaId: id)
            }
            .task {
                if viewModel == nil {
                    viewModel = HomeViewModel(homeRepository: environment.homeRepository)
                }
                await viewModel?.load()
            }
        }
    }
}