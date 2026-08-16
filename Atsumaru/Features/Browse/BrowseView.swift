import SwiftUI
import Core

enum BrowseDisplayMode: String, CaseIterable, Identifiable {
    case recentlyUpdated
    case search

    var id: String { rawValue }
}

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: BrowseViewModel?
    @State private var searchText = ""
    @State private var showingFilters = false
    @AppStorage("browseDisplayMode") private var displayMode: BrowseDisplayMode = .recentlyUpdated

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                switch displayMode {
                case .recentlyUpdated:
                    recentlyUpdatedContent
                case .search:
                    searchContent
                }
            }
            .navigationTitle("Browse")
            .navigationDestination(for: String.self) { id in
                MangaDetailView(mangaId: id)
            }
            .searchable(text: $searchText, prompt: "Search manga")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Display", selection: $displayMode) {
                    Text("Recently Updated").tag(BrowseDisplayMode.recentlyUpdated)
                    Text("Search").tag(BrowseDisplayMode.search)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.bar)
            }
            .task(id: displayMode) {
                if viewModel == nil {
                    viewModel = BrowseViewModel(
                        browseRepository: environment.browseRepository,
                        homeRepository: environment.homeRepository
                    )
                }
                guard let viewModel else { return }
                if displayMode == .recentlyUpdated && viewModel.recentlyUpdated.isEmpty {
                    await viewModel.loadRecentlyUpdated()
                } else if displayMode == .search && viewModel.filters == nil {
                    await viewModel.loadFilters()
                    await viewModel.search()
                }
            }
            .task(id: searchText) {
                guard displayMode == .search, let viewModel else { return }
                viewModel.query.q = searchText.isEmpty ? "*" : searchText
                await viewModel.search()
            }
            .sheet(isPresented: $showingFilters) {
                if let viewModel {
                    FilterSheet(viewModel: viewModel)
                        .presentationDetents([.large])
                        .onDisappear {
                            Task { await viewModel.search() }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var recentlyUpdatedContent: some View {
        if let viewModel {
            if viewModel.recentlyUpdated.isEmpty {
                if viewModel.recentlyUpdatedError != nil {
                    ErrorStateView(error: viewModel.recentlyUpdatedError ?? .decoding) {
                        Task { await viewModel.loadRecentlyUpdated() }
                    }
                    .padding(.top, 40)
                } else {
                    ProgressView().padding(.top, 40)
                }
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.recentlyUpdated) { item in
                        NavigationLink(value: item.id) {
                            Poster(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if let viewModel, viewModel.isLoading && viewModel.results.isEmpty {
            LoadingSkeletonView()
                .padding(.top, 40)
        } else if let viewModel, let error = viewModel.error, viewModel.results.isEmpty && !viewModel.isLoading {
            ErrorStateView(error: error) { Task { await viewModel.search() } }
                .padding(.top, 40)
        } else if let viewModel, viewModel.results.isEmpty && !viewModel.isLoading {
            EmptyStateView(message: "No results")
                .padding(.top, 40)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel?.results ?? []) { item in
                    NavigationLink(value: item.id) {
                        Poster(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
