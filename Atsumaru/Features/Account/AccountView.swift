import SwiftUI
import Core
import Kingfisher

struct AccountView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showAuth = false
    @State private var showSignOutConfirmation = false
    @State private var viewModel: AccountViewModel?

    var body: some View {
        NavigationStack {
            if environment.currentUser != nil {
                signedInContent
            } else {
                signedOutContent
            }
        }
        .authSheet(isPresented: $showAuth, environment: environment)
        .onChange(of: environment.currentUser?.id) { _, _ in
            viewModel = nil
        }
    }

    @ViewBuilder
    private var signedOutContent: some View {
        SignedOutView(message: "Sign in to sync your library and progress.") {
            showAuth = true
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
                    } else if let error = viewModel?.error {
                        ErrorStateView(error: error) { Task { await viewModel?.load() } }
                    }
                    manageAccountButton
                    signOutButton
                }
            }
            .padding(.vertical, 20)
        }
        .navigationTitle("Profile")
        .task {
            if viewModel == nil {
                viewModel = AccountViewModel(userRepository: environment.userRepository)
            }
            await viewModel?.load()
        }
        .confirmationDialog(
            "Sign out of atsumaru?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                Task { try? await environment.logout() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll keep your downloads, but library sync pauses until you sign in again.")
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
                            .background(.quaternary, in: Capsule())
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
        let url = AccountView.pinnedAvatarURL(from: urlString)
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
            ("Comics read", profile.countMangaRead),
            ("Chapters read", profile.countChaptersRead),
            ("Bookmarks", profile.countBookmarks),
            ("Comments", profile.countComments),
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
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var manageAccountButton: some View {
        if let url = URL(string: "https://atsu.moe/profile/settings") {
            Link(destination: url) {
                Label("Manage account on atsu.moe", systemImage: "safari")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var signOutButton: some View {
        Button(role: .destructive) {
            showSignOutConfirmation = true
        } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 16)
    }

    private static func pinnedAvatarURL(from path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if URL(string: path)?.scheme != nil {
            return ImageURLBuilder.avatar(path)
        }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return ImageURLBuilder.avatar("https://atsu.moe/" + trimmed)
    }
}

@Observable @MainActor
final class AccountViewModel {
    var profile: PrivateProfile?
    var isLoading = false
    var error: ApiError?

    private let userRepository: any UserRepository

    init(userRepository: any UserRepository) {
        self.userRepository = userRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await userRepository.privateProfile()
            error = nil
        } catch {
            self.error = (error as? ApiError) ?? .decoding
        }
    }
}