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
    public let usernameSlug: String?
    public let email: String?
    public let premium: Bool?
    public let rep: Int?
    public let avatarUrl: String?
    public let discordUsername: String?
    public let anilistUsername: String?
    public let countMangaRead: Int?
    public let countChaptersRead: Int?
    public let countFollowing: Int?
    public let countFollowers: Int?
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
            let usernameSlug: String?
            let email: String?
            let premium: Bool?
            let reputation: Int?
            let pfp: String?
            let mangaRead: Int?
            let chaptersRead: Int?
            let followingCount: Int?
            let followersCount: Int?
            let bookmarkCount: Int?
            let commentCount: Int?
        }
    }

    public init(from decoder: Decoder) throws {
        if let env = try? Envelope(from: decoder), let u = env.profilePage?.user {
            id = u.id
            username = u.username
            usernameSlug = u.usernameSlug
            email = u.email
            premium = u.premium
            rep = u.reputation
            avatarUrl = u.pfp
            countMangaRead = u.mangaRead
            countChaptersRead = u.chaptersRead
            countFollowing = u.followingCount
            countFollowers = u.followersCount
            countBookmarks = u.bookmarkCount
            countComments = u.commentCount
            discordUsername = nil
            anilistUsername = nil
            return
        }

        // Legacy flat shape (used by earlier tests / callers).
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        usernameSlug = try c.decodeIfPresent(String.self, forKey: .usernameSlug)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        premium = try c.decodeIfPresent(Bool.self, forKey: .premium)
        rep = try c.decodeIfPresent(Int.self, forKey: .rep)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        discordUsername = try c.decodeIfPresent(String.self, forKey: .discordUsername)
        anilistUsername = try c.decodeIfPresent(String.self, forKey: .anilistUsername)
        countMangaRead = try c.decodeIfPresent(Int.self, forKey: .countMangaRead)
        countChaptersRead = try c.decodeIfPresent(Int.self, forKey: .countChaptersRead)
        countFollowing = try c.decodeIfPresent(Int.self, forKey: .countFollowing)
        countFollowers = try c.decodeIfPresent(Int.self, forKey: .countFollowers)
        countBookmarks = nil
        countComments = nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, username, usernameSlug, email, premium, rep, avatarUrl
        case discordUsername, anilistUsername
        case countMangaRead, countChaptersRead, countFollowing, countFollowers
    }

    public init(
        id: String? = nil,
        username: String? = nil,
        usernameSlug: String? = nil,
        email: String? = nil,
        premium: Bool? = nil,
        rep: Int? = nil,
        avatarUrl: String? = nil,
        discordUsername: String? = nil,
        anilistUsername: String? = nil,
        countMangaRead: Int? = nil,
        countChaptersRead: Int? = nil,
        countFollowing: Int? = nil,
        countFollowers: Int? = nil,
        countBookmarks: Int? = nil,
        countComments: Int? = nil
    ) {
        self.id = id
        self.username = username
        self.usernameSlug = usernameSlug
        self.email = email
        self.premium = premium
        self.rep = rep
        self.avatarUrl = avatarUrl
        self.discordUsername = discordUsername
        self.anilistUsername = anilistUsername
        self.countMangaRead = countMangaRead
        self.countChaptersRead = countChaptersRead
        self.countFollowing = countFollowing
        self.countFollowers = countFollowers
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
    public let smallImage: String?
    public let mediumImage: String?
    public let largeImage: String?
    public let type: String?
    public let medium: String?
    public let bookmarkStatus: String?
    public let isAdult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, image, smallImage, mediumImage, largeImage
        case type, medium, bookmarkStatus, isAdult
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        image = try c.decodeIfPresent(String.self, forKey: .image)
        smallImage = try c.decodeIfPresent(String.self, forKey: .smallImage)
        mediumImage = try c.decodeIfPresent(String.self, forKey: .mediumImage)
        largeImage = try c.decodeIfPresent(String.self, forKey: .largeImage)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        medium = try c.decodeIfPresent(String.self, forKey: .medium)
        bookmarkStatus = try c.decodeIfPresent(String.self, forKey: .bookmarkStatus)
        isAdult = try c.decodeIfPresent(Bool.self, forKey: .isAdult)
    }

    public init(id: String, title: String, image: String? = nil, smallImage: String? = nil,
                mediumImage: String? = nil, largeImage: String? = nil, type: String? = nil,
                medium: String? = nil, bookmarkStatus: String? = nil, isAdult: Bool? = nil) {
        self.id = id
        self.title = title
        self.image = image
        self.smallImage = smallImage
        self.mediumImage = mediumImage
        self.largeImage = largeImage
        self.type = type
        self.medium = medium
        self.bookmarkStatus = bookmarkStatus
        self.isAdult = isAdult
    }
}

/// Tolerant history entry. Field names for `chapterId`/`chapterTitle`/`readAt`
/// are best-effort (UNVERIFIED from the site client); all are optional so
/// shape drift won't break decoding. `id` falls back to "".
public struct HistoryEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let mangaId: String?
    public let title: String?
    public let image: String?
    public let medium: String?
    public let chapterId: String?
    public let chapterTitle: String?
    public let readAt: String?

    enum CodingKeys: String, CodingKey {
        case id, mangaId, title, image, medium, chapterId, chapterTitle, readAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        mangaId = try c.decodeIfPresent(String.self, forKey: .mangaId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        medium = try c.decodeIfPresent(String.self, forKey: .medium)
        chapterId = try c.decodeIfPresent(String.self, forKey: .chapterId)
        chapterTitle = try c.decodeIfPresent(String.self, forKey: .chapterTitle)
        readAt = try c.decodeIfPresent(String.self, forKey: .readAt)
    }

    public init(id: String, mangaId: String? = nil, title: String? = nil, image: String? = nil,
                medium: String? = nil, chapterId: String? = nil, chapterTitle: String? = nil,
                readAt: String? = nil) {
        self.id = id
        self.mangaId = mangaId
        self.title = title
        self.image = image
        self.medium = medium
        self.chapterId = chapterId
        self.chapterTitle = chapterTitle
        self.readAt = readAt
    }
}

/// Tolerant user manga list. `itemCount`/`isPublic` key names are
/// UNVERIFIED from the site client; kept optional. `id` falls back to "".
public struct UserList: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let description: String?
    public let itemCount: Int?
    public let isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, itemCount, isPublic
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        itemCount = try c.decodeIfPresent(Int.self, forKey: .itemCount)
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic)
    }

    public init(id: String, name: String? = nil, description: String? = nil,
                itemCount: Int? = nil, isPublic: Bool? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.itemCount = itemCount
        self.isPublic = isPublic
    }
}

/// Tolerant continue-reading item (HomeItem-shaped plus `medium`,
/// `bookmarkStatus`, and a `continueReading` progress object). `id` falls back
/// to "". `lastChapter` is omitted (not needed for the resume UI).
public struct ContinueReadingItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    public let image: String?
    public let smallImage: String?
    public let mediumImage: String?
    public let largeImage: String?
    public let medium: String?
    public let bookmarkStatus: String?
    public let continueReading: ContinueReadingProgress?

    public struct ContinueReadingProgress: Codable, Sendable {
        public let chapterId: String?
        public let page: Int?
        public let ts: Int?
        public let mode: String?

        public init(chapterId: String? = nil, page: Int? = nil, ts: Int? = nil, mode: String? = nil) {
            self.chapterId = chapterId
            self.page = page
            self.ts = ts
            self.mode = mode
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, image, smallImage, mediumImage, largeImage
        case medium, bookmarkStatus, continueReading
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        smallImage = try c.decodeIfPresent(String.self, forKey: .smallImage)
        mediumImage = try c.decodeIfPresent(String.self, forKey: .mediumImage)
        largeImage = try c.decodeIfPresent(String.self, forKey: .largeImage)
        medium = try c.decodeIfPresent(String.self, forKey: .medium)
        bookmarkStatus = try c.decodeIfPresent(String.self, forKey: .bookmarkStatus)
        continueReading = try c.decodeIfPresent(ContinueReadingProgress.self, forKey: .continueReading)
    }

    public init(id: String, title: String? = nil, image: String? = nil, smallImage: String? = nil,
                mediumImage: String? = nil, largeImage: String? = nil, medium: String? = nil,
                bookmarkStatus: String? = nil, continueReading: ContinueReadingProgress? = nil) {
        self.id = id
        self.title = title
        self.image = image
        self.smallImage = smallImage
        self.mediumImage = mediumImage
        self.largeImage = largeImage
        self.medium = medium
        self.bookmarkStatus = bookmarkStatus
        self.continueReading = continueReading
    }
}