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
    @State private var showingCompose = false
    // Safer default: adult channels stay hidden until opted in (audit low fix).
    @AppStorage("forum.includeAdult") private var includeAdult = true

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel: viewModel)
                } else {
                    LoadingSkeletonView()
                }
            }
            .navigationTitle("Forum")
            .toolbar {
                // Compose and the adult-channels menu only make sense signed
                // in; the signed-out screen shows the sign-in prompt instead.
                if environment.currentUser != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingCompose = true } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Toggle(isOn: Binding(
                                get: { includeAdult },
                                set: { newValue in
                                    includeAdult = newValue
                                    viewModel?.includeAdult = newValue
                                    Task { await viewModel?.load(force: true) }
                                }
                            )) {
                                Text("Adult channels")
                            }
                        } label: {
                            Image(systemName: "eye.circle")
                        }
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ForumViewModel(repository: environment.forumRepository)
                viewModel?.includeAdult = includeAdult
            }
            if environment.currentUser != nil {
                await viewModel?.load()
            }
        }
        .onChange(of: environment.currentUser) { _, user in
            if user != nil {
                Task {
                    viewModel?.includeAdult = includeAdult
                    await viewModel?.load(force: true)
                }
            }
        }
        .sheet(isPresented: $showingCompose) {
            ComposeView(initialChannel: nil)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .authSheet(isPresented: $showAuth, environment: environment)
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
                    ContentUnavailableView(
                        "No channels",
                        systemImage: "bubble.left.and.bubble.right"
                    )
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
    var tags: [ForumTag] = []
    var isLoading = false
    var error: ApiError?
    /// Server accepts "hot" | "top" | "new" | "old"; defaults to "new" so
    /// freshly created posts are immediately visible at the top.
    var sort = "new"
    /// Website parity: filter the feed to a single forum tag.
    var tagId: String?

    private let repository: any ForumRepository

    init(channel: ForumChannel, repository: any ForumRepository) {
        self.channel = channel
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            posts = try await repository.posts(forumId: channel.id, sort: sort, page: 0, tagId: tagId)
            error = nil
        } catch {
            self.error = (error as? ApiError) ?? .decoding
        }
    }

    func loadTags() async {
        tags = (try? await repository.tags(forumId: channel.id)) ?? []
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
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Sort", selection: Binding(
                        get: { viewModel?.sort ?? "new" },
                        set: { newValue in
                            viewModel?.sort = newValue
                            Task { await viewModel?.load() }
                        }
                    )) {
                        Text("New").tag("new")
                        Text("Hot").tag("hot")
                        Text("Top").tag("top")
                        Text("Old").tag("old")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Tag", selection: Binding(
                        get: { viewModel?.tagId ?? "" },
                        set: { newValue in
                            viewModel?.tagId = newValue.isEmpty ? nil : newValue
                            Task { await viewModel?.load() }
                        }
                    )) {
                        Text("All tags").tag("")
                        ForEach(viewModel?.tags ?? []) { tag in
                            Text("\(tag.emoji ?? "") \(tag.name ?? tag.id)").tag(tag.id)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
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
                await viewModel?.loadTags()
            }
            if viewModel?.posts.isEmpty ?? false {
                await viewModel?.load()
            }
        }
        .refreshable { await viewModel?.load() }
        .sheet(isPresented: $showingCompose) {
            ComposeView(initialChannel: channel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showingCompose) { _, isShowing in
            // Refresh when the compose sheet closes; a newly created post
            // must show up in the list immediately.
            if !isShowing {
                Task { await viewModel?.load() }
            }
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
                    ContentUnavailableView("No posts yet", systemImage: "bubble.left")
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