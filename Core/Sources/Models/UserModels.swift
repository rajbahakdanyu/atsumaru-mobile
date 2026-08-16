import Foundation

/// Tolerant private-profile model. All fields optional except where the server
/// is documented to provide them; unknown keys are ignored by the decoder so
/// shape drift won't break decoding.
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
    /// UNVERIFIED key name: following/followers counts were noted in the brief
    /// but the exact field names could not be confirmed from the site client.
    public let countFollowing: Int?
    /// UNVERIFIED key name (see countFollowing).
    public let countFollowers: Int?

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
        countFollowers: Int? = nil
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
    }
}

/// Tolerant notification-preferences model. Exact toggle keys are unverified
/// from the site client, so preferences are decoded generically into a
/// `[String: Bool]`. Non-bool values are dropped (decode never throws on them),
/// keeping the model resilient to shape drift. Round-trips back to the same
/// JSON object shape for the PUT endpoint.
public struct NotificationPreferences: Codable, Sendable, Equatable {
    public var keys: [String: Bool]

    public init(keys: [String: Bool] = [:]) { self.keys = keys }

    private struct TolerantBool: Decodable, Encodable {
        let value: Bool?
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            value = try? c.decode(Bool.self)
        }
        func encode(to e: Encoder) throws {
            var c = e.singleValueContainer()
            if let v = value { try c.encode(v) } else { try c.encodeNil() }
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode([String: TolerantBool].self)
        keys = raw.compactMapValues { $0.value }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(keys)
    }
}

/// Tolerant notification-list item. `id` defaults to "" if the server omits it
/// so the item remains `Identifiable`. `createdAt` accepts either an Int
/// epoch-millis value or an ISO8601 string (converted to epoch millis).
public struct NotificationItem: Decodable, Sendable, Identifiable, Equatable {
    public let id: String
    public let type: String?
    public let title: String?
    public let body: String?
    public let createdAt: Int?
    /// UNVERIFIED key name: read-state field is a best-effort extra for unread
    /// styling. Absent on the server → nil (no special styling).
    public let read: Bool?

    enum CodingKeys: String, CodingKey { case id, type, title, body, createdAt, read }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        read = try c.decodeIfPresent(Bool.self, forKey: .read)
        if let int = try? c.decodeIfPresent(Int.self, forKey: .createdAt) {
            createdAt = int
        } else if let str = try c.decodeIfPresent(String.self, forKey: .createdAt),
                  let ms = Self.epochMs(fromISO8601: str) {
            createdAt = ms
        } else {
            createdAt = nil
        }
    }

    private static func epochMs(fromISO8601 s: String) -> Int? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return Int(d.timeIntervalSince1970 * 1000) }
        return nil
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