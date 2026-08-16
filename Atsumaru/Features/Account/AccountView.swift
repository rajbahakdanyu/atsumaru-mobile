import SwiftUI
import Core

struct AccountView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            if let user = environment.currentUser {
                LoggedInAccount(user: user) {
                    Task { try? await environment.logout() }
                }
            } else {
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
        }
        .sheet(isPresented: $showAuth) {
            AuthFlowView(onSuccess: { showAuth = false })
                .environment(environment)
        }
    }
}

private struct LoggedInAccount: View {
    let user: AuthUser
    let onLogout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let avatar = user.avatarUrl, let url = URL(string: avatar) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().frame(width: 120, height: 120)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit().frame(width: 120, height: 120)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit().frame(width: 120, height: 120)
                    .foregroundStyle(.secondary)
            }

            Text(user.username ?? "Member").font(.largeTitle)
            if let email = user.email { Text(email).foregroundStyle(.secondary) }

            Spacer()
            Button("Log out", role: .destructive, action: onLogout)
                .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Profile")
    }
}