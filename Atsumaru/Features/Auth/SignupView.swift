import SwiftUI
import Core

struct SignupView: View {
    let onSuccess: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showVerify = false

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textCase(.lowercase)
                    .autocorrectionDisabled()
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
            }
            Section {
                Button {
                    Task { await signUp() }
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Text(isLoading ? "Creating…" : "Create account")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading || email.isEmpty || username.isEmpty || password.isEmpty)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Sign up")
        .navigationDestination(isPresented: $showVerify) {
            VerifyEmailView()
        }
    }

    private func signUp() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await environment.signup(email: email, username: username, password: password)
            // If signup auto-logs us in, dismiss; otherwise go to verify state.
            if environment.currentUser != nil {
                onSuccess()
                dismiss()
            } else {
                showVerify = true
            }
        } catch {
            errorMessage = "Signup failed. Try a different username or email."
        }
    }
}