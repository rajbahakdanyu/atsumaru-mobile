import Foundation
import Testing
@testable import Core
@testable import Atsumaru

private struct PostedComment: Equatable, Sendable {
    let sectionId: String
    let parentId: String?
    let replyingToId: String?
    let content: String
    let spoiler: Bool
}

private struct CreatedPost: Equatable, Sendable {
    let forumId: String
    let title: String
    let content: String
    let spoiler: Bool
    let tagIds: Set<String>
}

@Suite
@MainActor
struct CommunityViewModelTests {
    @Test func forumLoadPublishesChannelsAndErrors() async throws {
        let channel: ForumChannel = try decode(from: #"{"id":"f1","name":"General"}"#)
        let successful = ForumViewModel(repository: ForumRepositoryStub(channels: { includeAdult in
            #expect(includeAdult)
            return [channel]
        }))
        successful.includeAdult = true
        await successful.load()
        #expect(successful.channels.map(\.id) == ["f1"])
        #expect(successful.error == nil)

        let failing = ForumViewModel(repository: ForumRepositoryStub(channels: { _ in
            throw ApiError.offline
        }))
        await failing.load()
        #expect(failing.channels.isEmpty)
        #expect(failing.error == .offline)
    }

    @Test func failedReplyLoadCanBeRetried() async throws {
        let calls = Box(0)
        let reply: Core.Comment = try decode(from: #"{"id":"reply","content":"Loaded"}"#)
        let repository = CommentsRepositoryStub { _, parentId, _, _ in
            guard parentId != nil else { return [] }
            calls.value += 1
            if calls.value == 1 { throw ApiError.offline }
            return [reply]
        }
        let parent: Core.Comment = try decode(from: #"{"id":"parent","content":"Top"}"#)
        let viewModel = CommentsViewModel(sectionId: "section", repository: repository)

        await viewModel.replies(parent: parent)
        #expect(viewModel.failedReplies.contains("parent"))
        #expect(viewModel.expandedReplies["parent"] == nil)

        await viewModel.replies(parent: parent)
        #expect(!viewModel.failedReplies.contains("parent"))
        #expect(viewModel.expandedReplies["parent"]?.map(\.id) == ["reply"])
        #expect(calls.value == 2)
    }

    @Test func postingReplyTrimsContentAndTargetsThread() async throws {
        let captured = Box<PostedComment?>(nil)
        let repository = CommentsRepositoryStub(
            post: { sectionId, parentId, replyingToId, content, spoiler in
                captured.value = PostedComment(
                    sectionId: sectionId, parentId: parentId,
                    replyingToId: replyingToId, content: content, spoiler: spoiler
                )
            }
        )
        let parent: Core.Comment = try decode(from: #"{"id":"parent","content":"Top"}"#)
        let viewModel = CommentsViewModel(sectionId: "section", repository: repository)
        viewModel.replyTarget = parent
        viewModel.composing = "  Reply text  "

        await viewModel.post()

        #expect(captured.value == PostedComment(
            sectionId: "section", parentId: "parent", replyingToId: "parent",
            content: "Reply text", spoiler: false
        ))
        #expect(viewModel.composing.isEmpty)
        #expect(viewModel.replyTarget == nil)
        #expect(!viewModel.postError)
    }

    @Test func composeValidationAndSubmissionRespectTagRules() async throws {
        let channel: ForumChannel = try decode(from: #"{"id":"f1","name":"General","tagsRequired":true,"maxTagsPerPost":1}"#)
        let firstTag: ForumTag = try decode(from: #"{"id":"t1","name":"One"}"#)
        let secondTag: ForumTag = try decode(from: #"{"id":"t2","name":"Two"}"#)
        let terminalTag: ForumTag = try decode(from: #"{"id":"t3","name":"Closed","terminal":true}"#)
        let captured = Box<CreatedPost?>(nil)
        let repository = ForumRepositoryStub(create: { forumId, title, content, spoiler, tagIds in
            captured.value = CreatedPost(
                forumId: forumId, title: title, content: content,
                spoiler: spoiler, tagIds: Set(tagIds)
            )
        })
        let viewModel = ComposeViewModel(repository: repository)
        viewModel.selectedChannel = channel
        viewModel.tags = [firstTag, secondTag, terminalTag]
        viewModel.title = "  A title  "
        viewModel.content = "  Body  "

        #expect(!viewModel.canSubmit)
        #expect(viewModel.usableTags.map(\.id) == ["t1", "t2"])
        viewModel.toggle(tag: firstTag)
        viewModel.toggle(tag: secondTag)
        #expect(viewModel.selectedTagIds == ["t1"])
        #expect(viewModel.canSubmit)

        await viewModel.submit()

        #expect(captured.value == CreatedPost(
            forumId: "f1", title: "A title", content: "Body",
            spoiler: false, tagIds: ["t1"]
        ))
        #expect(viewModel.didSubmit)
    }

    @Test func postVoteAndBookmarkRollBackOnFailure() async throws {
        let post: ForumPost = try decode(from: #"{"id":"p1","title":"Post","score":10,"viewerVote":"none","viewerBookmarked":false}"#)
        let repository = ForumRepositoryStub(
            vote: { _, _ in throw ApiError.offline },
            bookmark: { _, _ in throw ApiError.offline }
        )
        let viewModel = PostDetailViewModel(post: post, repository: repository)

        await viewModel.vote(1)
        await viewModel.toggleBookmark()

        #expect(viewModel.localVote == 0)
        #expect(!viewModel.bookmarked)
        #expect(viewModel.score == 10)
        #expect(PostDetailViewModel.isValidEdit(title: " abc ", content: " ok "))
        #expect(!PostDetailViewModel.isValidEdit(title: "ab", content: "ok"))
    }

    @Test func channelPostsDiscardStaleResponses() async throws {
        let channel: ForumChannel = try decode(from: #"{"id":"f1","name":"General"}"#)
        let stale: ForumPost = try decode(from: #"{"id":"old","title":"Old"}"#)
        let current: ForumPost = try decode(from: #"{"id":"new","title":"New"}"#)
        let gate = AsyncGate()
        let repository = ForumRepositoryStub(posts: { _, sort, _, _ in
            if sort == "new" {
                await gate.wait()
                return [stale]
            }
            return [current]
        })
        let viewModel = ChannelPostsViewModel(channel: channel, repository: repository)
        viewModel.sort = "new"

        let staleLoad = Task { await viewModel.load() }
        await gate.waitUntilOccupied()
        viewModel.sort = "hot"
        await viewModel.load()
        await gate.open()
        await staleLoad.value

        #expect(viewModel.posts.map(\.id) == ["new"])
        #expect(!viewModel.isLoading)
    }
}
