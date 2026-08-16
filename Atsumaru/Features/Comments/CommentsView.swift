import SwiftUI
import MarkdownUI
import Kingfisher
import Core

struct CommentsView: View {
    let sectionId: String
    let ownsNavigation: Bool

    init(sectionId: String, ownsNavigation: Bool = true) {
        self.sectionId = sectionId
        self.ownsNavigation = ownsNavigation
    }

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CommentsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if ownsNavigation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("Done").fontWeight(.semibold) }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = CommentsViewModel(sectionId: sectionId, repository: environment.commentsRepository)
            }
            if viewModel?.comments.isEmpty ?? false {
                await viewModel?.load()
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: CommentsViewModel) -> some View {
        if viewModel.isLoading && viewModel.comments.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.loadFailed && viewModel.comments.isEmpty {
            ContentUnavailableView {
                Label("Couldn't load comments", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        } else {
            list(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func list(viewModel: CommentsViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if viewModel.comments.isEmpty {
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                }
                ForEach(viewModel.comments) { comment in
                    CommentRow(
                        comment: comment,
                        onReply: { viewModel.replyTarget = comment },
                        onVote: { value in await viewModel.vote(comment: comment, vote: value) }
                    )
                    Divider()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .refreshable { await viewModel.refresh() }
        .safeAreaInset(edge: .bottom) { composeBar(viewModel: viewModel) }
    }

    @ViewBuilder
    private func composeBar(viewModel: CommentsViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 8) {
            if let target = viewModel.replyTarget {
                HStack {
                    Text("Replying to \(target.user?.username ?? "comment")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { viewModel.cancelReply() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a comment", text: $viewModel.composing, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                Button {
                    Task { await viewModel.post() }
                } label: {
                    Image(systemName: viewModel.isPosting ? "ellipsis" : "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(viewModel.composing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPosting)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCapsule()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct CommentRow: View {
    let comment: Comment
    let onReply: () -> Void
    let onVote: (Int) async -> Bool

    @State private var spoilerRevealed = false
    @State private var localVote = 0

    private var score: Int {
        (comment.upvotes ?? 0) - (comment.downvotes ?? 0) + localVote
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CommentAvatar(urlString: comment.user?.avatarUrl)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(comment.user?.username ?? "Unknown")
                        .font(.subheadline.bold())
                    if let created = comment.createdAt {
                        Text(formatted(created))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                content
                HStack(spacing: 18) {
                    voteControls
                    Button(action: onReply) {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let raw = comment.content, !raw.isEmpty {
            if comment.spoiler == true && !spoilerRevealed {
                ZStack {
                    Markdown(raw)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .blur(radius: 10)
                        .opacity(0.0)
                    Button { spoilerRevealed = true } label: {
                        Label("Spoiler", systemImage: "eye.slash")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassCapsule()
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Markdown(raw)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var voteControls: some View {
        HStack(spacing: 6) {
            Button {
                guard localVote != 1 else { return }
                localVote = 1
                Task {
                    let success = await onVote(1)
                    if !success { localVote = 0 }
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.caption)
                    .foregroundStyle(localVote == 1 ? .yellow : .secondary)
            }
            .buttonStyle(.plain)

            Text("\(score)")
                .font(.caption.monospacedDigit())
                .frame(minWidth: 16)

            Button {
                guard localVote != -1 else { return }
                localVote = -1
                Task {
                    let success = await onVote(-1)
                    if !success { localVote = 0 }
                }
            } label: {
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundStyle(localVote == -1 ? .blue : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func formatted(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) {
            return d.formatted(.relative(presentation: .named))
        }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: iso) {
            return d.formatted(.relative(presentation: .named))
        }
        return iso
    }
}

struct CommentAvatar: View {
    let urlString: String?

    var body: some View {
        KFImage(Self.url(from: urlString))
            .resizable()
            .placeholder {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
            .scaledToFit()
            .frame(width: 34, height: 34)
            .clipShape(Circle())
    }

    static func url(from path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "https://atsu.moe/" + trimmed)
    }
}