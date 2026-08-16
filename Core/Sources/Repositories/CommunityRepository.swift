import Foundation

public protocol CommunityRepository: Sendable {
    func publicProfile(slug: String) async throws -> PublicProfile
    func follow(userId: String) async throws
    func followers(slug: String, page: Int) async throws -> [UserSummary]
    func following(slug: String, page: Int) async throws -> [UserSummary]
    func groups(page: Int) async throws -> [CommunityGroup]
    func group(id: String) async throws -> CommunityGroup
    func joinGroup(id: String) async throws
    func leaveGroup(id: String) async throws
    func createGroup(name: String, tag: String, type: String, bio: String) async throws
    func poll(ids: [String]) async throws -> [Poll]
    func votePoll(pollId: String, optionIds: [String]) async throws
}

public struct LiveCommunityRepository: CommunityRepository {
    private let client: APIClient
    public init(client: APIClient) { self.client = client }

    private struct ItemsEnvelope: Decodable { let items: [UserSummary]? }
    private struct UsersEnvelope: Decodable { let users: [UserSummary]? }
    private struct ListEnvelope: Decodable { let list: [UserSummary]? }
    private struct GroupsEnvelope: Decodable { let groups: [CommunityGroup] }
    private struct GroupEnvelope: Decodable { let group: CommunityGroup? }
    private struct PollsEnvelope: Decodable { let polls: [Poll]? }
    private struct ProfileEnvelopeAlt: Decodable { let user: PublicProfile? }
    private struct ProfileEnvelopeAlt2: Decodable { let profile: PublicProfile? }

    private struct FollowBody: Encodable { let userId: String }
    private struct GroupIdBody: Encodable { let groupId: String }
    private struct CreateGroupBody: Encodable {
        let name: String
        let tag: String
        let type: String
        let bio: String
    }
    private struct VotePollBody: Encodable {
        let pollId: String
        let optionIds: [String]
    }

    public func publicProfile(slug: String) async throws -> PublicProfile {
        let data = try await client.getData("/api/user/publicProfile", query: ["slug": slug])
        if let p = try? JSONDecoder().decode(PublicProfile.self, from: data) {
            return p
        }
        if let env = try? JSONDecoder().decode(ProfileEnvelopeAlt.self, from: data), let p = env.user {
            return p
        }
        if let env = try? JSONDecoder().decode(ProfileEnvelopeAlt2.self, from: data), let p = env.profile {
            return p
        }
        throw ApiError.decoding
    }

    public func follow(userId: String) async throws {
        try await client.postVoid("/api/user/follow", json: FollowBody(userId: userId))
    }

    public func followers(slug: String, page: Int) async throws -> [UserSummary] {
        let data = try await client.getData("/api/user/followers", query: ["slug": slug, "page": "\(page)"])
        return try Self.decodeUserList(data)
    }

    public func following(slug: String, page: Int) async throws -> [UserSummary] {
        let data = try await client.getData("/api/user/following", query: ["slug": slug, "page": "\(page)"])
        return try Self.decodeUserList(data)
    }

    public func groups(page: Int) async throws -> [CommunityGroup] {
        let data = try await client.getData("/api/groups/list", query: ["page": "\(page)"])
        if let env = try? JSONDecoder().decode(GroupsEnvelope.self, from: data) {
            return env.groups
        }
        if let arr = try? JSONDecoder().decode([CommunityGroup].self, from: data) {
            return arr
        }
        throw ApiError.decoding
    }

    public func group(id: String) async throws -> CommunityGroup {
        let data = try await client.getData("/api/groups/page", query: ["id": id])
        if let env = try? JSONDecoder().decode(GroupEnvelope.self, from: data), let g = env.group {
            return g
        }
        if let g = try? JSONDecoder().decode(CommunityGroup.self, from: data) {
            return g
        }
        throw ApiError.decoding
    }

    public func joinGroup(id: String) async throws {
        try await client.postVoid("/api/groups/join", json: GroupIdBody(groupId: id))
    }

    public func leaveGroup(id: String) async throws {
        try await client.postVoid("/api/groups/leave", json: GroupIdBody(groupId: id))
    }

    public func createGroup(name: String, tag: String, type: String, bio: String) async throws {
        try await client.postVoid(
            "/api/groups/create",
            json: CreateGroupBody(name: name, tag: tag, type: type, bio: bio)
        )
    }

    public func poll(ids: [String]) async throws -> [Poll] {
        let data = try await client.getData("/api/polls/get", query: ["ids": ids.joined(separator: ",")])
        if let env = try? JSONDecoder().decode(PollsEnvelope.self, from: data) {
            return env.polls ?? []
        }
        if let arr = try? JSONDecoder().decode([Poll].self, from: data) {
            return arr
        }
        throw ApiError.decoding
    }

    public func votePoll(pollId: String, optionIds: [String]) async throws {
        try await client.postVoid(
            "/api/polls/vote",
            json: VotePollBody(pollId: pollId, optionIds: optionIds)
        )
    }

    private static func decodeUserList(_ data: Data) throws -> [UserSummary] {
        if let env = try? JSONDecoder().decode(ItemsEnvelope.self, from: data), let items = env.items {
            return items
        }
        if let env = try? JSONDecoder().decode(UsersEnvelope.self, from: data), let users = env.users {
            return users
        }
        if let env = try? JSONDecoder().decode(ListEnvelope.self, from: data), let list = env.list {
            return list
        }
        if let arr = try? JSONDecoder().decode([UserSummary].self, from: data) {
            return arr
        }
        throw ApiError.decoding
    }
}