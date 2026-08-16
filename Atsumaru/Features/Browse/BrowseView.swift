import SwiftUI
import Core

enum BrowseDisplayMode: String, CaseIterable, Identifiable {
    case recentlyUpdated
    case popular

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
                LazyVStack(alignment: .leading, pinnedViews: [.sectionHeaders]) {
                    Section {
                        if !searchText.isEmpty {
                            searchContent
                        } else if let viewModel, viewModel.hasActiveFilters {
                            feedContent(items: viewModel.filteredResults,
                                        error: viewModel.filteredError,
                                        isLoading: viewModel.isLoadingFiltered,
                                        loadMore: { Task { await viewModel.loadFiltered() } })
                        } else {
                            switch displayMode {
                            case .recentlyUpdated:
                                feedContent(items: viewModel?.recentlyUpdated ?? [],
                                            error: viewModel?.recentlyUpdatedError,
                                            isLoading: viewModel?.isLoadingRecentlyUpdated ?? false,
                                            loadMore: { Task { await viewModel?.loadRecentlyUpdated() } })
                            case .popular:
                                feedContent(items: viewModel?.popular ?? [],
                                            error: viewModel?.popularError,
                                            isLoading: viewModel?.isLoadingPopular ?? false,
                                            loadMore: { Task { await viewModel?.loadPopular() } })
                            }
                        }
                    } header: {
                        Picker("Display", selection: $displayMode) {
                            Text("Recently Updated").tag(BrowseDisplayMode.recentlyUpdated)
                            Text("Popular").tag(BrowseDisplayMode.popular)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                        .background(.background)
                    }
                }
            }
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                MangaDetailView(mangaId: id)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search manga")
            .sheet(isPresented: $showingFilters) {
                if let viewModel {
                    FilterSheet(viewModel: viewModel)
                        .presentationDetents([.large])
                        .onDisappear {
                            if viewModel.hasActiveFilters {
                                Task { await viewModel.loadFiltered(reset: true) }
                            }
                        }
                }
            }
            .task(id: displayMode) {
                if viewModel == nil {
                    viewModel = BrowseViewModel(
                        browseRepository: environment.browseRepository,
                        homeRepository: environment.homeRepository
                    )
                }
                guard let viewModel else { return }
                switch displayMode {
                case .recentlyUpdated:
                    if viewModel.recentlyUpdated.isEmpty {
                        await viewModel.loadRecentlyUpdated()
                    }
                case .popular:
                    if viewModel.popular.isEmpty {
                        await viewModel.loadPopular()
                    }
                }
            }
            .task(id: searchText) {
                guard !searchText.isEmpty, let viewModel else { return }
                viewModel.query.q = searchText
                await viewModel.search()
            }
        }
    }

    @ViewBuilder
    private func feedContent(items: [HomeItem], error: ApiError?, isLoading: Bool,
                             loadMore: @escaping () -> Void) -> some View {
        if items.isEmpty {
            if error != nil {
                ErrorStateView(error: error ?? .decoding) { loadMore() }
                    .padding(.top, 40)
            } else if isLoading {
                ProgressView().padding(.top, 40)
            } else {
                EmptyStateView(message: "Nothing here yet.")
                    .padding(.top, 40)
            }
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(value: item.id) {
                        Poster(item: item, showsTitle: true)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if item.id == items.last?.id {
                            loadMore()
                        }
                    }
                }
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.horizontal)
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
                        Poster(item: item, showsTitle: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
