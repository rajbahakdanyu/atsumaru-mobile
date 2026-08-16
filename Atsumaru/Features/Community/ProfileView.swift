import SwiftUI
import Core
import Kingfisher

@Observable
@MainActor
final class ProfileViewModel {
    let slug: String
    var profile: PublicProfile?
    var isLoading = false
    var loadFailed = false
    var isFollowing = false
    var followerCount: Int?
    var followBusy = false

    private let repository: any CommunityRepository

    init(slug: String, repository: any CommunityRepository) {
        self.slug = slug
        self.repository = repository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let p = try await repository.publicProfile(slug: slug)
            profile = p
            isFollowing = p.isFollowing ?? false
            followerCount = p.followerCount
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    func toggleFollow() async {
        guard let id = profile?.id, !followBusy else { return }
        let prev = isFollowing
        let prevCount = followerCount
        followBusy = true
        defer { followBusy = false }
        isFollowing = !prev
        if let c = followerCount {
            followerCount = max(0, c + (prev ? -1 : 1))
        }
        do {
            try await repository.follow(userId: id)
        } catch {
            isFollowing = prev
            followerCount = prevCount
        }
    }
}

struct ProfileView: View {
    let slug: String
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ProfileViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = ProfileViewModel(slug: slug, repository: environment.communityRepository)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(viewModel: ProfileViewModel) -> some View {
        if viewModel.isLoading && viewModel.profile == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.loadFailed && viewModel.profile == nil {
            ContentUnavailableView {
                Label("Couldn't load profile", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        } else if let profile = viewModel.profile {
            ScrollView {
                VStack(spacing: 18) {
                    header(viewModel: viewModel, profile: profile)
                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }
                    statsRow(viewModel: viewModel, profile: profile)
                    followButton(viewModel: viewModel)
                    navigationLinks(viewModel: viewModel)
                }
                .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private func header(viewModel: ProfileViewModel, profile: PublicProfile) -> some View {
        VStack(spacing: 10) {
            CommunityAvatar(urlString: profile.avatarUrl, size: 96)
            VStack(spacing: 4) {
                Text(profile.username ?? slug)
                    .font(.title2.bold())
                if let rep = profile.rep {
                    Text("\(rep) rep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func statsRow(viewModel: ProfileViewModel, profile: PublicProfile) -> some View {
        let stats: [(String, Int?)] = [
            ("Manga read", profile.countMangaRead),
            ("Chapters", profile.countChaptersRead),
            ("Followers", viewModel.followerCount ?? profile.followerCount),
            ("Following", profile.followingCount),
        ]
        HStack(spacing: 10) {
            ForEach(stats.indices, id: \.self) { index in
                let stat = stats[index]
                VStack(spacing: 3) {
                    Text("\(stat.1 ?? 0)")
                        .font(.headline.monospacedDigit())
                    Text(stat.0)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassCapsule()
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func followButton(viewModel: ProfileViewModel) -> some View {
        Button {
            Task { await viewModel.toggleFollow() }
        } label: {
            Text(viewModel.isFollowing ? "Following" : "Follow")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .modifier(ProminentToggleStyle(active: viewModel.isFollowing))
        .disabled(viewModel.followBusy)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func navigationLinks(viewModel: ProfileViewModel) -> some View {
        VStack(spacing: 12) {
            NavigationLink {
                FollowersView(slug: slug, mode: .followers)
            } label: {
                linkRow(label: "Followers",
                        count: viewModel.followerCount ?? viewModel.profile?.followerCount,
                        system: "person.2")
            }
            .buttonStyle(.plain)

            NavigationLink {
                FollowersView(slug: slug, mode: .following)
            } label: {
                linkRow(label: "Following",
                        count: viewModel.profile?.followingCount,
                        system: "person.2.crop.left.stack")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func linkRow(label: String, count: Int?, system: String) -> some View {
        HStack {
            Label(label, systemImage: system)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .glassCapsule()
    }
}

struct CommunityAvatar: View {
    let urlString: String?
    var size: CGFloat = 56

    var body: some View {
        KFImage(CommunityAvatar.url(from: urlString))
            .resizable()
            .placeholder {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    static func url(from path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "https://atsu.moe/" + trimmed)
    }
}