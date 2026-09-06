import SwiftUI
import Core

struct ForgotPasswordView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var email = ""
    @State private var isLoading = false
    @State private var didSend = false
    @State private var errorMessage: String?
    @State private var showReset = false
    @State private var resetToken = ""
    @State private var newPassword = ""

    var body: some View {
        Form {
            if didSend {
                Section {
                    Text("If an account exists for \(email), a reset link has been sent.")
                        .foregroundStyle(.secondary)
                }
                Section("Reset password") {
                    TextField("Reset token", text: $resetToken)
                        .autocorrectionDisabled()
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                    NavigationLink("Reset") {
                        ResetPasswordView(token: resetToken, newPassword: newPassword)
                    }
                    .disabled(resetToken.isEmpty || newPassword.isEmpty)
                }
            } else {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textCase(.lowercase)
                        .autocorrectionDisabled()
                }
                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(isLoading ? "Sending…" : "Send reset link")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading || email.isEmpty)
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Forgot password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.authRepository.sendPasswordReset(email: email)
            didSend = true
        } catch {
            errorMessage = "Could not send reset email. Try again."
        }
    }
}

struct ResetPasswordView: View {
    let token: String
    let newPassword: String
    @Environment(AppEnvironment.self) private var environment
    @State private var isLoading = false
    @State private var done = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if done {
                Section {
                    Label("Password updated. You can now sign in.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Button {
                        Task { await reset() }
                    } label: {
                        HStack {
                            if isLoading { ProgressView() }
                            Text(isLoading ? "Resetting…" : "Reset password")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isLoading)
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Reset password")
    }

    private func reset() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.authRepository.resetPassword(
                token: token,
                newPassword: newPassword,
                confirmPassword: newPassword
            )
            done = true
        } catch {
            errorMessage = "Reset failed. The token may have expired."
        }
    }
}