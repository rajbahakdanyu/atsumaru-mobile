import SwiftUI
import Core

enum FollowListMode: Hashable, Sendable {
    case followers
    case following
}

@Observable
@MainActor
final class FollowersViewModel {
    let slug: String
    let mode: FollowListMode
    var users: [UserSummary] = []
    var isLoading = false
    var loadFailed = false

    private let repository: any CommunityRepository

    init(slug: String, mode: FollowListMode, repository: any CommunityRepository) {
        self.slug = slug
        self.mode = mode
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = mode == .followers
                ? try await repository.followers(slug: slug, page: 0)
                : try await repository.following(slug: slug, page: 0)
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

struct FollowersView: View {
    let slug: String
    let mode: FollowListMode
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: FollowersViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(mode == .followers ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = FollowersViewModel(
                    slug: slug,
                    mode: mode,
                    repository: environment.communityRepository
                )
            }
            await viewModel?.load()
        }
        .refreshable { await viewModel?.load() }
    }

    @ViewBuilder
    private func content(viewModel: FollowersViewModel) -> some View {
        if viewModel.isLoading && viewModel.users.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.loadFailed && viewModel.users.isEmpty {
            ContentUnavailableView {
                Label("Couldn't load", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        } else {
            List {
                if viewModel.users.isEmpty {
                    Text("No one here yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.users) { user in
                        NavigationLink {
                            ProfileView(slug: user.usernameSlug ?? user.username ?? user.id)
                        } label: {
                            userRow(user)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func userRow(_ user: UserSummary) -> some View {
        HStack(spacing: 12) {
            CommunityAvatar(urlString: user.avatarUrl, size: 44)
            Text(user.username ?? user.usernameSlug ?? user.id)
                .font(.body)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}