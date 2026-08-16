import SwiftUI
import Core

struct AuthFlowView: View {
    let onSuccess: () -> Void
    static let providers = ["discord", "google", "anilist", "mangabaka"]

    var body: some View {
        NavigationStack {
            LoginView(onSuccess: onSuccess)
        }
    }
}

struct LoginView: View {
    let onSuccess: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textCase(.lowercase)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            Section {
                Button {
                    Task { await signIn() }
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Text(isLoading ? "Signing in…" : "Log in")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }
            Section {
                NavigationLink("Create an account") {
                    SignupView(onSuccess: onSuccess)
                }
                NavigationLink("Forgot password?") {
                    ForgotPasswordView()
                }
            }
            Section("Continue with") {
                OAuthButtons(onSuccess: onSuccess)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Sign in")
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.login(email: email, password: password)
            onSuccess()
            dismiss()
        } catch {
            errorMessage = "Sign in failed. Check your credentials."
        }
    }
}

struct OAuthButtons: View {
    let onSuccess: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @State private var coordinator: AuthCoordinator?
    @State private var status: String?
    @State private var isLoading = false

    var body: some View {
        ForEach(AuthFlowView.providers, id: \.self) { provider in
            Button("Continue with \(provider.capitalized)") {
                Task { await authenticate(provider: provider) }
            }
            .disabled(isLoading)
        }
        if let status {
            Text(status).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func authenticate(provider: String) async {
        isLoading = true
        defer { isLoading = false }
        if coordinator == nil {
            coordinator = AuthCoordinator(authRepository: environment.authRepository)
        }
        guard let coordinator else { return }
        do {
            try await coordinator.authenticate(provider: provider)
            // Best-effort: no documented token-exchange endpoint was provided,
            // so rely on shared session cookies and re-fetch identity.
            if let me = try? await environment.authRepository.me() {
                environment.currentUser = me
                onSuccess()
            } else {
                status = "OAuth did not complete sign-in."
            }
        } catch {
            status = "OAuth cancelled or failed."
        }
    }
}