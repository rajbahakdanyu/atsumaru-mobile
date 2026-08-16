import SwiftUI
import Core

struct ParagraphCommentsSheet: View {
    let chapterId: String
    let paragraph: Int

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var section: CommentSection?
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Paragraph \(paragraph + 1)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: { Text("Done").fontWeight(.semibold) }
                    }
                }
        }
        .task { if section == nil { await load() } }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && section == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let section {
            sectionContent(section: section)
        } else if loadFailed {
            ContentUnavailableView {
                Label("Couldn't load comments", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await load() } }
            }
        } else {
            Text("No comments yet")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func sectionContent(section: CommentSection) -> some View {
        if let sectionId = section.id, !sectionId.isEmpty {
            CommentsView(sectionId: sectionId)
        } else {
            readOnlyInline(section: section)
        }
    }

    @ViewBuilder
    private func readOnlyInline(section: CommentSection) -> some View {
        let comments = section.comments ?? []
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if comments.isEmpty {
                    Text("No comments yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                }
                ForEach(comments) { comment in
                    CommentRow(comment: comment, onReply: {}, onVote: { _ in })
                    Divider()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            section = try await environment.commentsRepository.paragraphCommentSection(
                chapterId: chapterId, paragraph: paragraph, create: true
            )
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}