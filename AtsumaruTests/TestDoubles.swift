import Foundation
@testable import Core

struct TestFailure: Error, Sendable {}

final class Box<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) { storedValue = value }

    var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock()
            storedValue = newValue
            lock.unlock()
        }
    }
}

func decode<T: Decodable>(_ type: T.Type = T.self, from json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

final class BrowseRepositoryStub: BrowseRepository, Sendable {
    let searchHandler: @Sendable (SearchQuery) async throws -> SearchResult
    let filtersHandler: @Sendable () async throws -> AvailableFilters

    init(
        search: @escaping @Sendable (SearchQuery) async throws -> SearchResult = { _ in SearchResult(found: 0, hits: []) },
        filters: @escaping @Sendable () async throws -> AvailableFilters = {
            AvailableFilters(genres: [], tags: [], types: [], statuses: [])
        }
    ) {
        searchHandler = search
        filtersHandler = filters
    }

    func search(_ query: SearchQuery) async throws -> SearchResult { try await searchHandler(query) }
    func availableFilters() async throws -> AvailableFilters { try await filtersHandler() }
}

final class HomeRepositoryStub: HomeRepository, Sendable {
    let handler: @Sendable (HomeEndpoint, Int, Int) async throws -> HomeRail

    init(handler: @escaping @Sendable (HomeEndpoint, Int, Int) async throws -> HomeRail = { _, _, _ in HomeRail(items: []) }) {
        self.handler = handler
    }

    func rail(_ endpoint: HomeEndpoint) async throws -> HomeRail {
        try await handler(endpoint, 0, 0)
    }

    func rail(_ endpoint: HomeEndpoint, offset: Int, limit: Int) async throws -> HomeRail {
        try await handler(endpoint, offset, limit)
    }
}

final class ReadRepositoryStub: ReadRepository, Sendable {
    let chapterHandler: @Sendable (String, String) async throws -> ReadChapter
    let updateHandler: @Sendable (ProgressUpdate) async throws -> Void

    init(
        chapter: @escaping @Sendable (String, String) async throws -> ReadChapter,
        update: @escaping @Sendable (ProgressUpdate) async throws -> Void = { _ in }
    ) {
        chapterHandler = chapter
        updateHandler = update
    }

    func chapter(mangaId: String, chapterId: String) async throws -> ReadChapter {
        try await chapterHandler(mangaId, chapterId)
    }

    func updateProgress(_ update: ProgressUpdate) async throws {
        try await updateHandler(update)
    }
}

final class NovelRepositoryStub: NovelRepository, Sendable {
    let handler: @Sendable (String, String) async throws -> NovelChapter

    init(handler: @escaping @Sendable (String, String) async throws -> NovelChapter) {
        self.handler = handler
    }

    func novelChapter(mangaId: String, chapterId: String) async throws -> NovelChapter {
        try await handler(mangaId, chapterId)
    }
}

final class MangaRepositoryStub: MangaRepository, Sendable {
    let pageHandler: @Sendable (String) async throws -> MangaPage
    let chaptersHandler: @Sendable (String, Int) async throws -> [Chapter]

    init(
        page: @escaping @Sendable (String) async throws -> MangaPage,
        chapters: @escaping @Sendable (String, Int) async throws -> [Chapter] = { _, _ in [] }
    ) {
        pageHandler = page
        chaptersHandler = chapters
    }

    func page(id: String) async throws -> MangaPage { try await pageHandler(id) }
    func chapters(id: String, page: Int) async throws -> [Chapter] { try await chaptersHandler(id, page) }
}

final class UserRepositoryStub: UserRepository, Sendable {
    let handler: @Sendable () async throws -> PrivateProfile

    init(handler: @escaping @Sendable () async throws -> PrivateProfile) {
        self.handler = handler
    }

    func privateProfile() async throws -> PrivateProfile { try await handler() }
}

final class CommentsRepositoryStub: CommentsRepository, Sendable {
    let threadsHandler: @Sendable (String, String?, String?, String?) async throws -> [Comment]
    let postHandler: @Sendable (String, String?, String?, String, Bool) async throws -> Void
    let voteHandler: @Sendable (String, Int) async throws -> Void

    init(
        threads: @escaping @Sendable (String, String?, String?, String?) async throws -> [Comment] = { _, _, _, _ in [] },
        post: @escaping @Sendable (String, String?, String?, String, Bool) async throws -> Void = { _, _, _, _, _ in },
        vote: @escaping @Sendable (String, Int) async throws -> Void = { _, _ in }
    ) {
        threadsHandler = threads
        postHandler = post
        voteHandler = vote
    }

    func threads(sectionId: String, parentId: String?, cursor: String?, sort: String?) async throws -> [Comment] {
        try await threadsHandler(sectionId, parentId, cursor, sort)
    }

    func postComment(sectionId: String, parentId: String?, replyingToId: String?, content: String, spoiler: Bool) async throws {
        try await postHandler(sectionId, parentId, replyingToId, content, spoiler)
    }

    func vote(commentId: String, vote: Int) async throws { try await voteHandler(commentId, vote) }
    func paragraphCommentSection(chapterId: String, paragraph: Int, create: Bool) async throws -> CommentSection {
        CommentSection(id: "section", comments: [], count: 0)
    }
    func commentSection(chapterId: String) async throws -> CommentSection {
        CommentSection(id: "section", comments: [], count: 0)
    }
}

final class LibraryRepositoryStub: LibraryRepository, Sendable {
    let bookmarksHandler: @Sendable () async throws -> [Bookmark]
    let historyHandler: @Sendable () async throws -> [HistoryEntry]
    let listsHandler: @Sendable () async throws -> [UserList]
    let continueHandler: @Sendable () async throws -> [ContinueReadingItem]
    let createHandler: @Sendable (String) async throws -> Void
    let deleteHandler: @Sendable (String) async throws -> Void
    let pinHandler: @Sendable (String, Bool) async throws -> Void

    init(
        bookmarks: @escaping @Sendable () async throws -> [Bookmark] = { [] },
        history: @escaping @Sendable () async throws -> [HistoryEntry] = { [] },
        lists: @escaping @Sendable () async throws -> [UserList] = { [] },
        continueReading: @escaping @Sendable () async throws -> [ContinueReadingItem] = { [] },
        create: @escaping @Sendable (String) async throws -> Void = { _ in },
        delete: @escaping @Sendable (String) async throws -> Void = { _ in },
        pin: @escaping @Sendable (String, Bool) async throws -> Void = { _, _ in }
    ) {
        bookmarksHandler = bookmarks
        historyHandler = history
        listsHandler = lists
        continueHandler = continueReading
        createHandler = create
        deleteHandler = delete
        pinHandler = pin
    }

    func bookmarks(offset: Int, limit: Int) async throws -> [Bookmark] { try await bookmarksHandler() }
    func history() async throws -> [HistoryEntry] { try await historyHandler() }
    func lists() async throws -> [UserList] { try await listsHandler() }
    func createList(name: String) async throws { try await createHandler(name) }
    func deleteList(id: String) async throws { try await deleteHandler(id) }
    func addManga(listId: String, mangaId: String) async throws -> Bool { false }
    func setPinned(listId: String, pinned: Bool) async throws { try await pinHandler(listId, pinned) }
    func listDetail(id: String) async throws -> ListDetail { throw TestFailure() }
    func continueReading() async throws -> [ContinueReadingItem] { try await continueHandler() }
}

final class ForumRepositoryStub: ForumRepository, Sendable {
    let channelsHandler: @Sendable (Bool) async throws -> [ForumChannel]
    let postsHandler: @Sendable (String, String?, Int, String?) async throws -> [ForumPost]
    let detailHandler: @Sendable (String) async throws -> ForumPostDetail
    let createHandler: @Sendable (String, String, String, Bool, [String]) async throws -> Void
    let editHandler: @Sendable (String, String, String) async throws -> Void
    let removeHandler: @Sendable (String) async throws -> Void
    let voteHandler: @Sendable (String, Int) async throws -> Void
    let bookmarkHandler: @Sendable (String, Bool) async throws -> Void
    let tagsHandler: @Sendable (String) async throws -> [ForumTag]

    init(
        channels: @escaping @Sendable (Bool) async throws -> [ForumChannel] = { _ in [] },
        posts: @escaping @Sendable (String, String?, Int, String?) async throws -> [ForumPost] = { _, _, _, _ in [] },
        detail: @escaping @Sendable (String) async throws -> ForumPostDetail = { _ in throw TestFailure() },
        create: @escaping @Sendable (String, String, String, Bool, [String]) async throws -> Void = { _, _, _, _, _ in },
        edit: @escaping @Sendable (String, String, String) async throws -> Void = { _, _, _ in },
        remove: @escaping @Sendable (String) async throws -> Void = { _ in },
        vote: @escaping @Sendable (String, Int) async throws -> Void = { _, _ in },
        bookmark: @escaping @Sendable (String, Bool) async throws -> Void = { _, _ in },
        tags: @escaping @Sendable (String) async throws -> [ForumTag] = { _ in [] }
    ) {
        channelsHandler = channels
        postsHandler = posts
        detailHandler = detail
        createHandler = create
        editHandler = edit
        removeHandler = remove
        voteHandler = vote
        bookmarkHandler = bookmark
        tagsHandler = tags
    }

    func channels(includeAdult: Bool) async throws -> [ForumChannel] { try await channelsHandler(includeAdult) }
    func posts(forumId: String, sort: String?, page: Int, tagId: String?) async throws -> [ForumPost] {
        try await postsHandler(forumId, sort, page, tagId)
    }
    func postDetail(postId: String) async throws -> ForumPostDetail { try await detailHandler(postId) }
    func createPost(forumId: String, title: String, content: String, spoiler: Bool, tagIds: [String]) async throws {
        try await createHandler(forumId, title, content, spoiler, tagIds)
    }
    func editPost(postId: String, title: String, content: String) async throws {
        try await editHandler(postId, title, content)
    }
    func removePost(postId: String) async throws { try await removeHandler(postId) }
    func votePost(postId: String, vote: Int) async throws { try await voteHandler(postId, vote) }
    func bookmarkPost(postId: String, bookmarked: Bool) async throws { try await bookmarkHandler(postId, bookmarked) }
    func tags(forumId: String) async throws -> [ForumTag] { try await tagsHandler(forumId) }
}

actor AsyncGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitUntilOccupied() async {
        while continuations.isEmpty { await Task.yield() }
    }

    func open() {
        let pending = continuations
        continuations.removeAll()
        for continuation in pending { continuation.resume() }
    }
}
