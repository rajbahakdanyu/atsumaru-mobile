import SwiftUI
import Textual
import Core

@Observable
@MainActor
final class PostDetailViewModel {
    let postId: String
    var post: ForumPost
    var tags: [ForumTag] = []
    var isLoading = false
    var loadFailed = false
    var localVote = 0
    var bookmarked = false

    private let repository: any ForumRepository

    init(post: ForumPost, repository: any ForumRepository) {
        self.post = post
        self.postId = post.id
        self.repository = repository
    }

    var score: Int {
        post.displayScore + localVote
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await repository.post(postId: postId)
            post = fresh
            loadFailed = false
            if let forumId = fresh.forumId {
                tags = (try? await repository.tags(forumId: forumId)) ?? []
            }
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            loadFailed = true
        }
    }

    func vote(_ value: Int) async {
        let prev = localVote
        localVote = value
        do {
            try await repository.votePost(postId: postId, vote: value)
        } catch {
            localVote = prev
        }
    }

    func toggleBookmark() async {
        let next = !bookmarked
        bookmarked = next
        do {
            try await repository.bookmarkPost(postId: postId, bookmarked: next)
        } catch {
            bookmarked = !next
        }
    }
}

struct PostDetailView: View {
    let post: ForumPost
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: PostDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = PostDetailViewModel(
                    post: post,
                    repository: environment.forumRepository
                )
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(viewModel: PostDetailViewModel) -> some View {
        if viewModel.loadFailed && viewModel.post.content == nil {
            ContentUnavailableView {
                Label("Couldn't load post", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(viewModel: viewModel)
                    if let raw = viewModel.post.content, !raw.isEmpty {
                        StructuredText(markdown: MarkdownSanitizer.sanitizeImages(raw))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !viewModel.tags.isEmpty {
                        tagsRow(viewModel.tags)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .safeAreaInset(edge: .bottom) { actionBar(viewModel: viewModel) }
        }
    }

    @ViewBuilder
    private func header(viewModel: PostDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.post.title ?? "Untitled")
                .font(.title3.bold())
            HStack(spacing: 10) {
                Text(viewModel.post.user?.username ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let created = viewModel.post.createdAtDate {
                    Text(created.relativeLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if viewModel.post.pinned == true {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                if viewModel.post.locked == true {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func tagsRow(_ tags: [ForumTag]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(tags) { tag in
                Text("#\(tag.name ?? tag.id)")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .glassCapsule()
            }
        }
    }

    @ViewBuilder
    private func actionBar(viewModel: PostDetailViewModel) -> some View {
        HStack(spacing: 18) {
            voteButton(viewModel, value: 1, system: "arrow.up", active: viewModel.localVote == 1, color: .yellow)
            Text("\(viewModel.score)").font(.body.monospacedDigit()).frame(minWidth: 24)
            voteButton(viewModel, value: -1, system: "arrow.down", active: viewModel.localVote == -1, color: .blue)
            Spacer()
            Button {
                Task { await viewModel.toggleBookmark() }
            } label: {
                Image(systemName: viewModel.bookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(viewModel.bookmarked ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCapsule()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func voteButton(
        _ viewModel: PostDetailViewModel, value: Int, system: String, active: Bool, color: Color
    ) -> some View {
        Button {
            guard viewModel.localVote != value else { return }
            Task { await viewModel.vote(value) }
        } label: {
            Image(systemName: system)
                .foregroundStyle(active ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}