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
    var didRemove = false
    var actionError: String?
    var actionErrorTitle = "Something went wrong"

    private let repository: any ForumRepository

    init(post: ForumPost, repository: any ForumRepository) {
        self.post = post
        self.postId = post.id
        self.localVote = Self.voteValue(from: post.viewerVote)
        self.bookmarked = post.viewerBookmarked ?? false
        self.repository = repository
    }

    /// Server rules: title >= 3 chars, content >= 2 chars.
    static func isValidEdit(title: String, content: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        content.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    @discardableResult
    func edit(title: String, content: String) async -> Bool {
        do {
            try await repository.editPost(
                postId: postId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            await load()
            return true
        } catch {
            actionErrorTitle = "Couldn't save changes"
            actionError = "Please try again."
            return false
        }
    }

    func remove() async {
        do {
            try await repository.removePost(postId: postId)
            didRemove = true
        } catch {
            actionErrorTitle = "Couldn't delete post"
            actionError = "Please try again."
        }
    }

    /// Maps the API's viewerVote ("up"/"down"/"none"/nil) to the UI's ±1/0 domain.
    private static func voteValue(from viewerVote: String?) -> Int {
        switch viewerVote {
        case "up": return 1
        case "down": return -1
        default: return 0
        }
    }

    private func syncViewerState(from fresh: ForumPost) {
        localVote = Self.voteValue(from: fresh.viewerVote)
        if let bookmarked = fresh.viewerBookmarked {
            self.bookmarked = bookmarked
        }
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
            syncViewerState(from: fresh)
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
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PostDetailViewModel?
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    private var isOwnPost: Bool {
        guard let viewModel, let user = environment.currentUser else { return false }
        if let slug = viewModel.post.user?.usernameSlug, slug == user.usernameSlug { return true }
        if let authorId = viewModel.post.user?.id, authorId == user.id { return true }
        return false
    }

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
        .toolbar {
            if isOwnPost {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Post", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let viewModel {
                EditPostView(viewModel: viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog(
            "Delete this post?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel?.remove()
                    if viewModel?.didRemove == true { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This post will be permanently removed.")
        }
        .alert(
            viewModel?.actionErrorTitle ?? "Something went wrong",
            isPresented: Binding(
                get: { viewModel?.actionError != nil },
                set: { if !$0 { viewModel?.actionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.actionError ?? "")
        }
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
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private func actionBar(viewModel: PostDetailViewModel) -> some View {
        HStack(spacing: 18) {
            voteButton(viewModel, value: 1, system: "arrow.up", active: viewModel.localVote == 1, color: VoteColors.up)
            Text("\(viewModel.score)").font(.body.monospacedDigit()).frame(minWidth: 24)
            voteButton(viewModel, value: -1, system: "arrow.down", active: viewModel.localVote == -1, color: VoteColors.down)
            Spacer()
            Button {
                Task { await viewModel.toggleBookmark() }
            } label: {
                Image(systemName: viewModel.bookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(viewModel.bookmarked ? VoteColors.bookmark : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCapsule(interactive: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func voteButton(
        _ viewModel: PostDetailViewModel, value: Int, system: String, active: Bool, color: Color
    ) -> some View {
        Button {
            // Tapping the active direction un-votes (server accepts "none").
            Task { await viewModel.vote(viewModel.localVote == value ? 0 : value) }
        } label: {
            Image(systemName: system)
                .foregroundStyle(active ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

struct EditPostView: View {
    @Bindable var viewModel: PostDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var isSaving = false
    @State private var originalTitle: String
    @State private var originalContent: String
    @State private var showDiscardConfirmation = false

    init(viewModel: PostDetailViewModel) {
        self.viewModel = viewModel
        _title = State(initialValue: viewModel.post.title ?? "")
        _content = State(initialValue: viewModel.post.content ?? "")
        _originalTitle = State(initialValue: viewModel.post.title ?? "")
        _originalContent = State(initialValue: viewModel.post.content ?? "")
    }

    private var hasEdits: Bool {
        title != originalTitle || content != originalContent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(.headline)
                        .submitLabel(.next)
                }
                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .frame(minHeight: 180)
                            .scrollDismissesKeyboard(.interactively)
                        if content.isEmpty {
                            Text("Start writing…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                } header: {
                    Text("Body")
                } footer: {
                    Text("Markdown formatting is supported.")
                }
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasEdits {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            isSaving = true
                            let saved = await viewModel.edit(title: title, content: content)
                            isSaving = false
                            if saved { dismiss() }
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(!PostDetailViewModel.isValidEdit(title: title, content: content) || isSaving)
                }
            }
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("Your edits haven't been saved yet.")
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
}