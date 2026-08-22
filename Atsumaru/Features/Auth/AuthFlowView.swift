import SwiftUI
import Core

struct AuthFlowView: View {
    let onSuccess: () -> Void

    var body: some View {
        NavigationStack {
            LoginView(onSuccess: onSuccess)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
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
        VStack(spacing: 18) {
            Text("Sign in")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textCase(.lowercase)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCapsule()

                HStack(spacing: 8) {
                    Image(systemName: "lock")
                        .foregroundStyle(.secondary)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCapsule()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await signIn() }
            } label: {
                HStack {
                    if isLoading { ProgressView() }
                    Text(isLoading ? "Signing in…" : "Log in")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            HStack(spacing: 12) {
                NavigationLink("Create account") {
                    SignupView(onSuccess: onSuccess)
                }
                Spacer()
                NavigationLink("Forgot password?") {
                    ForgotPasswordView()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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