import SwiftUI
import Core

@Observable
@MainActor
final class ForumViewModel {
    var channels: [ForumChannel] = []
    var isLoading = false
    var error: ApiError?
    var includeAdult = false

    private let repository: any ForumRepository
    private var loaded = false

    init(repository: any ForumRepository) {
        self.repository = repository
    }

    func load(force: Bool = false) async {
        guard !loaded || force else { return }
        loaded = true
        isLoading = true
        defer { isLoading = false }
        do {
            channels = try await repository.channels(includeAdult: includeAdult)
            error = nil
        } catch {
            self.error = (error as? ApiError) ?? .decoding
        }
    }
}

struct ForumView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ForumViewModel?
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                LoadingSkeletonView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ForumViewModel(repository: environment.forumRepository)
            }
            await viewModel?.load()
        }
        .sheet(isPresented: $showAuth) {
            AuthFlowView(onSuccess: { showAuth = false })
                .environment(environment)
        }
    }

    @ViewBuilder
    private func content(viewModel: ForumViewModel) -> some View {
        if environment.currentUser == nil {
            signedOutContent
        } else if viewModel.isLoading && viewModel.channels.isEmpty {
            LoadingSkeletonView()
        } else if let error = viewModel.error, viewModel.channels.isEmpty {
            ErrorStateView(error: error) { Task { await viewModel.load(force: true) } }
        } else {
            List {
                if viewModel.channels.isEmpty {
                    EmptyStateView(message: "No channels")
                } else {
                    ForEach(viewModel.channels) { channel in
                        NavigationLink(value: channel) {
                            channelRow(channel)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Forum")
            .navigationDestination(for: ForumChannel.self) { channel in
                ChannelPostsView(channel: channel)
            }
            .navigationDestination(for: ForumPost.self) { post in
                PostDetailView(post: post)
            }
            .refreshable { await viewModel.load(force: true) }
        }
    }

    @ViewBuilder
    private var signedOutContent: some View {
        SignedOutView(message: "Sign in to browse the forum.") {
            showAuth = true
        }
        .navigationTitle("Forum")
    }

    @ViewBuilder
    private func channelRow(_ channel: ForumChannel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name ?? "Untitled")
                    .font(.body.bold())
                if let desc = channel.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let count = channel.postCount {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@Observable
@MainActor
final class ChannelPostsViewModel {
    let channel: ForumChannel
    var posts: [ForumPost] = []
    var isLoading = false
    var error: ApiError?

    private let repository: any ForumRepository

    init(channel: ForumChannel, repository: any ForumRepository) {
        self.channel = channel
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await repository.posts(forumId: channel.id, sort: nil, page: 0)
            error = nil
        } catch {
            self.error = (error as? ApiError) ?? .decoding
        }
    }
}

struct ChannelPostsView: View {
    let channel: ForumChannel
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ChannelPostsViewModel?
    @State private var showingCompose = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                LoadingSkeletonView()
            }
        }
        .navigationTitle(channel.name ?? "Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCompose = true } label: { Image(systemName: "square.and.pencil") }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ChannelPostsViewModel(
                    channel: channel,
                    repository: environment.forumRepository
                )
            }
            if viewModel?.posts.isEmpty ?? false {
                await viewModel?.load()
            }
        }
        .refreshable { await viewModel?.load() }
        .sheet(isPresented: $showingCompose) {
            ComposeView(channel: channel)
        }
    }

    @ViewBuilder
    private func content(viewModel: ChannelPostsViewModel) -> some View {
        if viewModel.isLoading && viewModel.posts.isEmpty {
            LoadingSkeletonView()
        } else if let error = viewModel.error, viewModel.posts.isEmpty {
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        } else {
            List {
                if viewModel.posts.isEmpty {
                    EmptyStateView(message: "No posts yet")
                } else {
                    ForEach(viewModel.posts) { post in
                        NavigationLink(value: post) {
                            postRow(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func postRow(_ post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if post.pinned == true {
                    Image(systemName: "pin.fill").foregroundStyle(.yellow).font(.caption)
                }
                Text(post.title ?? "Untitled")
                    .font(.body.bold())
                    .lineLimit(2)
            }
            HStack(spacing: 12) {
                Text(post.user?.username ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let date = post.createdAtDate {
                    Text(date.relativeLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(post.displayScore)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}