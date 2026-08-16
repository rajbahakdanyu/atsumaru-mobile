import SwiftUI
import Core
import Kingfisher

struct AccountView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showAuth = false
    @State private var viewModel: AccountViewModel?

    var body: some View {
        NavigationStack {
            if environment.currentUser != nil {
                signedInContent
            } else {
                signedOutContent
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthFlowView(onSuccess: { showAuth = false })
                .environment(environment)
        }
    }

    @ViewBuilder
    private var signedOutContent: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Not signed in",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Sign in to sync your library and progress.")
            )
            Button("Sign in") { showAuth = true }
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Profile")
    }

    @ViewBuilder
    private var signedInContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let user = environment.currentUser {
                    header(user: user, profile: viewModel?.profile)
                    if let profile = viewModel?.profile {
                        statsGrid(profile)
                    } else if viewModel?.isLoading == true {
                        ProgressView().padding(.vertical, 8)
                    } else if viewModel?.loadFailed == true {
                        Text("Couldn't load profile stats.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    navigationLinks
                    signOutButton
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Profile")
        .onAppear {
            if viewModel == nil {
                viewModel = AccountViewModel(userRepository: environment.userRepository)
            }
            Task { await viewModel?.load() }
        }
    }

    @ViewBuilder
    private func header(user: AuthUser, profile: PrivateProfile?) -> some View {
        VStack(spacing: 12) {
            avatarView(urlString: profile?.avatarUrl ?? user.avatarUrl)
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(profile?.username ?? user.username ?? "Member")
                        .font(.title2.bold())
                    if profile?.premium == true || user.premium == true {
                        Text("Premium")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .glassCapsule()
                    }
                }
                if let rep = profile?.rep ?? user.rep {
                    Text("\(rep) rep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func avatarView(urlString: String?) -> some View {
        let url = AccountView.avatarURL(from: urlString)
        KFImage(url)
            .resizable()
            .placeholder { placeholderAvatar }
            .scaledToFit()
            .frame(width: 112, height: 112)
            .clipShape(Circle())
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 112, height: 112)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func statsGrid(_ profile: PrivateProfile) -> some View {
        let stats: [(String, Int?)] = [
            ("Manga read", profile.countMangaRead),
            ("Chapters read", profile.countChaptersRead),
            ("Following", profile.countFollowing),
            ("Followers", profile.countFollowers),
        ]
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(stats.indices, id: \.self) { index in
                let stat = stats[index]
                if let value = stat.1 {
                    VStack(spacing: 4) {
                        Text("\(value)")
                            .font(.title3.bold())
                        Text(stat.0)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassCapsule()
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var navigationLinks: some View {
        VStack(spacing: 12) {
            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .glassCapsule()
            }
            .buttonStyle(.plain)

            NavigationLink {
                NotificationsView()
            } label: {
                HStack {
                    Label("Notifications", systemImage: "bell")
                    Spacer()
                    if let unread = viewModel?.unreadCount, unread > 0 {
                        Text("\(unread)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .glassCapsule()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .glassCapsule()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var signOutButton: some View {
        Button(role: .destructive) {
            Task { try? await environment.logout() }
        } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 16)
    }

    private static func avatarURL(from path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if let url = URL(string: path), url.scheme != nil { return url }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: "https://atsu.moe/" + trimmed)
    }
}

@Observable @MainActor
final class AccountViewModel {
    var profile: PrivateProfile?
    var unreadCount: Int?
    var isLoading = false
    var loadFailed = false

    private let userRepository: any UserRepository

    init(userRepository: any UserRepository) {
        self.userRepository = userRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        async let profileTask = try? userRepository.privateProfile()
        async let countTask = try? userRepository.notificationCount()
        let (loadedProfile, loadedCount) = await (profileTask, countTask)
        profile = loadedProfile
        unreadCount = loadedCount
        loadFailed = loadedProfile == nil
    }
}