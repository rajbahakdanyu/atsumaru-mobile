import SwiftUI
import Core

struct BrowseView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: BrowseViewModel?
    @State private var searchText = ""
    @State private var showingFilters = false

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let viewModel, viewModel.results.isEmpty && !viewModel.isLoading {
                    Text("No results")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel?.results ?? []) { Poster(item: $0) }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Browse")
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
            .task(id: searchText) {
                if viewModel == nil {
                    let vm = BrowseViewModel(browseRepository: environment.browseRepository)
                    viewModel = vm
                    await vm.loadFilters()
                }
                guard let viewModel else { return }
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
}