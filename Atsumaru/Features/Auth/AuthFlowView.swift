import SwiftUI
import Core

struct AuthFlowView: View {
    let onSuccess: () -> Void

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