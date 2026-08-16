import SwiftUI
import Core

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel?.rails ?? [], id: \.0.rawValue) { rail in
                        RailSection(title: rail.0.displayName, items: rail.1)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Atsumaru")
            .task {
                if viewModel == nil {
                    viewModel = HomeViewModel(homeRepository: environment.homeRepository)
                }
                await viewModel?.load()
            }
        }
    }
}