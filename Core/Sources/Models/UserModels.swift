import Foundation

/// Tolerant private-profile model. The live endpoint returns
/// `{"profilePage":{"user":{...}}}`, where `user` uses `username`,
/// `reputation`, `mangaRead`, `chaptersRead`, `bookmarkCount`, `commentCount`,
/// `followingCount` and `followersCount`. This model maps those onto the
/// app-facing field names; unknown keys are ignored so shape drift won't break
/// decoding.
public struct PrivateProfile: Decodable, Sendable, Equatable {
    public let id: String?
    public let username: String?
    public let premium: Bool?
    public let rep: Int?
    public let avatarUrl: String?
    public let countMangaRead: Int?
    public let countChaptersRead: Int?
    public let countBookmarks: Int?
    public let countComments: Int?

    private struct Envelope: Decodable {
        let profilePage: Page?
        struct Page: Decodable {
            let user: User?
        }
        struct User: Decodable {
            let id: String?
            let username: String?
            let premium: Bool?
            let reputation: Int?
            let pfp: String?
            let mangaRead: Int?
            let chaptersRead: Int?
            let bookmarkCount: Int?
            let commentCount: Int?
        }
    }

    public init(from decoder: Decoder) throws {
        if let env = try? Envelope(from: decoder), let u = env.profilePage?.user {
            id = u.id
            username = u.username
            premium = u.premium
            rep = u.reputation
            avatarUrl = u.pfp
            countMangaRead = u.mangaRead
            countChaptersRead = u.chaptersRead
            countBookmarks = u.bookmarkCount
            countComments = u.commentCount
            return
        }

        // Legacy flat shape (used by earlier tests / callers).
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        premium = try c.decodeIfPresent(Bool.self, forKey: .premium)
        rep = try c.decodeIfPresent(Int.self, forKey: .rep)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        countMangaRead = try c.decodeIfPresent(Int.self, forKey: .countMangaRead)
        countChaptersRead = try c.decodeIfPresent(Int.self, forKey: .countChaptersRead)
        countBookmarks = nil
        countComments = nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, username, premium, rep, avatarUrl
        case countMangaRead, countChaptersRead
    }

    public init(
        id: String? = nil,
        username: String? = nil,
        premium: Bool? = nil,
        rep: Int? = nil,
        avatarUrl: String? = nil,
        countMangaRead: Int? = nil,
        countChaptersRead: Int? = nil,
        countBookmarks: Int? = nil,
        countComments: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.premium = premium
        self.rep = rep
        self.avatarUrl = avatarUrl
        self.countMangaRead = countMangaRead
        self.countChaptersRead = countChaptersRead
        self.countBookmarks = countBookmarks
        self.countComments = countComments
    }
}

/// Tolerant bookmark item (HomeItem-shaped plus `bookmarkStatus`). `id` falls
/// back to "" when the server omits it so the item stays `Identifiable`.
public struct Bookmark: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let image: String?
    public let medium: String?
    public let bookmarkStatus: String?
    public let isAdult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, image
        case medium, bookmarkStatus, isAdult
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        image = try c.decodeIfPresent(String.self, forKey: .image)
        medium = try c.decodeIfPresent(String.self, forKey: .medium)
        bookmarkStatus = try c.decodeIfPresent(String.self, forKey: .bookmarkStatus)
        isAdult = try c.decodeIfPresent(Bool.self, forKey: .isAdult)
    }

    public init(id: String, title: String, image: String? = nil,
                medium: String? = nil, bookmarkStatus: String? = nil, isAdult: Bool? = nil) {
        self.id = id
        self.title = title
        self.image = image
        self.medium = medium
        self.bookmarkStatus = bookmarkStatus
        self.isAdult = isAdult
    }
}

/// Tolerant history entry. Verified live shape: `id` IS the manga id (there
/// is no `mangaId` key); `readAt` is an epoch-ms number (ISO8601 strings are
/// also tolerated); the chapter title/number live inside a nested
/// `continueReading` object (`title`/`number`/`page`/`chapterId`). `id` falls
/// back to "".
public struct HistoryEntry: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let image: String?
    public let chapterId: String?
    public let chapterTitle: String?
    public let chapterNumber: Double?
    public let readAt: Int?

    private struct ContinueReading: Decodable, Sendable {
        let chapterId: String?
        let title: String?
        let number: Double?
    }

    enum CodingKeys: String, CodingKey {
        case id, title, image, chapterId, chapterTitle, chapterNumber
        case readAt, continueReading
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        let nested = try c.decodeIfPresent(ContinueReading.self, forKey: .continueReading)
        chapterId = (try? c.decodeIfPresent(String.self, forKey: .chapterId)) ?? nil ?? nested?.chapterId
        chapterTitle = (try? c.decodeIfPresent(String.self, forKey: .chapterTitle)) ?? nil ?? nested?.title
        chapterNumber = nested?.number
        readAt = DateParsing.decodeEpochMs(c, forKey: .readAt)
    }

    public init(id: String, title: String? = nil, image: String? = nil,
                chapterId: String? = nil, chapterTitle: String? = nil,
                chapterNumber: Double? = nil, readAt: Int? = nil) {
        self.id = id
        self.title = title
        self.image = image
        self.chapterId = chapterId
        self.chapterTitle = chapterTitle
        self.chapterNumber = chapterNumber
        self.readAt = readAt
    }

    public var readAtDate: Date? { readAt.flatMap { $0.dateFromEpochMs } }
}

/// Tolerant user manga list. Verified live shape: the display name arrives
/// under the `title` key (mapped onto the app-facing `name` property); there
/// is no `itemCount`. `id` falls back to "".
public struct UserList: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name = "title", description
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
    }

    public init(id: String, name: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// Tolerant continue-reading item (HomeItem-shaped plus `medium`,
/// `bookmarkStatus`, and a `continueReading` progress object). `id` falls back
/// to "". `lastChapter` is omitted (not needed for the resume UI).
public struct ContinueReadingItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let image: String?
    public let medium: String?
    public let bookmarkStatus: String?
    public let continueReading: ContinueReadingProgress?

    public struct ContinueReadingProgress: Codable, Sendable {
        public let chapterId: String?
        public let page: Int?
        public let mode: String?

        public init(chapterId: String? = nil, page: Int? = nil, mode: String? = nil) {
            self.chapterId = chapterId
            self.page = page
            self.mode = mode
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, image
        case medium, bookmarkStatus, continueReading
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        medium = try c.decodeIfPresent(String.self, forKey: .medium)
        bookmarkStatus = try c.decodeIfPresent(String.self, forKey: .bookmarkStatus)
        continueReading = try c.decodeIfPresent(ContinueReadingProgress.self, forKey: .continueReading)
    }

    public init(id: String, title: String? = nil, image: String? = nil,
                medium: String? = nil, bookmarkStatus: String? = nil,
                continueReading: ContinueReadingProgress? = nil) {
        self.id = id
        self.title = title
        self.image = image
        self.medium = medium
        self.bookmarkStatus = bookmarkStatus
        self.continueReading = continueReading
    }
}