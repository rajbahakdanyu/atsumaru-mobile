import SwiftUI
import Core

@Observable
@MainActor
final class CommentsViewModel {
    let sectionId: String
    private let repository: any CommentsRepository

    var comments: [Comment] = []
    var isLoading = false
    var loadFailed = false
    var composing = ""
    var isPosting = false
    var postError = false
    var replyTarget: Comment?

    init(sectionId: String, repository: any CommentsRepository) {
        self.sectionId = sectionId
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await repository.threads(
                sectionId: sectionId, parentId: nil, cursor: nil, sort: nil
            )
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    func refresh() async {
        do {
            comments = try await repository.threads(
                sectionId: sectionId, parentId: nil, cursor: nil, sort: nil
            )
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    func post() async {
        let content = composing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await repository.postComment(
                sectionId: sectionId,
                parentId: nil,
                replyingToId: replyTarget?.id,
                content: content,
                spoiler: false
            )
            composing = ""
            replyTarget = nil
            postError = false
            await refresh()
        } catch {
            postError = true
        }
    }

    @discardableResult
    func vote(comment: Comment, vote: Int) async -> Bool {
        do {
            try await repository.vote(commentId: comment.id, vote: vote)
            return true
        } catch {
            return false
        }
    }

    func cancelReply() {
        replyTarget = nil
    }
}