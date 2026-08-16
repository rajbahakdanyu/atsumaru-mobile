import SwiftUI
import Core

struct VerifyEmailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var token = ""
    @State private var isLoading = false
    @State private var didVerify = false
    @State private var resendStatus: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("Enter the verification token from your email.")
                    .foregroundStyle(.secondary)
                TextField("Token", text: $token)
                    .autocorrectionDisabled()
            }
            Section {
                Button {
                    Task { await verify() }
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Text(isLoading ? "Verifying…" : "Verify email")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading || token.isEmpty)

                if didVerify {
                    Text("Email verified. You can sign in.").foregroundStyle(.green)
                }
            }
            Section {
                Button("Resend verification email") {
                    Task { await resend() }
                }
                if let resendStatus {
                    Text(resendStatus).font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Verify email")
    }

    private func verify() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.authRepository.verifyEmail(token: token)
            didVerify = true
        } catch {
            errorMessage = "Verification failed. The token may be invalid or expired."
        }
    }

    private func resend() async {
        do {
            try await environment.authRepository.sendVerification()
            resendStatus = "Sent. Check your inbox."
        } catch {
            resendStatus = "Could not resend. Try again later."
        }
    }
}