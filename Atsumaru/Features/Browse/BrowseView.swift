import SwiftUI
import Core

enum BrowseDisplayMode: String, CaseIterable, Identifiable {
    case recentlyUpdated
    case popular
    case filtered

    var id: String { rawValue }
}

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: BrowseViewModel?
    @State private var showingFilters = false
    @State private var showingSearch = false
    @AppStorage("browseDisplayMode") private var displayMode: BrowseDisplayMode = .recentlyUpdated

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, pinnedViews: [.sectionHeaders]) {
                    Section {
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
                        case .filtered:
                            if let viewModel, viewModel.hasActiveFilters {
                                feedContent(items: viewModel.filteredResults,
                                            error: viewModel.filteredError,
                                            isLoading: viewModel.isLoadingFiltered,
                                            loadMore: { Task { await viewModel.loadFiltered() } })
                            } else {
                                filteredEmptyState
                            }
                        }
                    } header: {
                        Picker("Display", selection: $displayMode) {
                            Text("Recently Updated").tag(BrowseDisplayMode.recentlyUpdated)
                            Text("Popular").tag(BrowseDisplayMode.popular)
                            Text("Filtered").tag(BrowseDisplayMode.filtered)
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    Button { showingFilters = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                MangaDetailView(mangaId: id)
            }
            .sheet(isPresented: $showingFilters) {
                if let viewModel {
                    FilterSheet(viewModel: viewModel)
                        .presentationDetents([.large])
                        .onDisappear {
                            if viewModel.hasActiveFilters {
                                displayMode = .filtered
                                Task { await viewModel.loadFiltered(reset: true) }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingSearch) {
                if let viewModel {
                    SearchSheet(viewModel: viewModel)
                        .presentationDetents([.large])
                        .onDisappear {
                            if !viewModel.query.q.isEmpty, viewModel.query.q != "*" {
                                displayMode = .filtered
                                Task { await viewModel.search() }
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
                case .filtered:
                    if viewModel.hasActiveFilters && viewModel.filteredResults.isEmpty {
                        await viewModel.loadFiltered()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            EmptyStateView(message: "Search or apply filters to see results here.")
                .padding(.top, 40)
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
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
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
}
