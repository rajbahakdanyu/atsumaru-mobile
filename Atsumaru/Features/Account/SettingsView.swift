import SwiftUI
import Core

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: SettingsViewModel?
    @AppStorage("appTheme") private var appTheme: AppTheme = .slate

    var body: some View {
        Form {
            themeSection
            usernameSection
            emailSection
            passwordSection
            Section {
                NavigationLink {
                    NotificationsView()
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(userRepository: environment.userRepository)
            }
        }
        .onDisappear {
            viewModel?.emailPassword = ""
            viewModel?.oldPassword = ""
            viewModel?.newPassword = ""
        }
    }

    @ViewBuilder
    private var themeSection: some View {
        Section("Theme") {
            Picker("Accent color", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.displayName, systemImage: "circle.fill")
                        .tint(theme.accent)
                        .tag(theme)
                }
            }
        }
    }

    @ViewBuilder
    private var usernameSection: some View {
        Section("Username") {
            TextField("New username", text: Binding(
                get: { viewModel?.username ?? "" },
                set: { viewModel?.username = $0 }
            ))
            .textContentType(.username)
            .autocorrectionDisabled()
            SecureField("Current password", text: Binding(
                get: { viewModel?.usernamePassword ?? "" },
                set: { viewModel?.usernamePassword = $0 }
            ))
            .textContentType(.password)
            Button {
                guard let vm = viewModel, !vm.username.isEmpty, !vm.usernamePassword.isEmpty else { return }
                Task {
                    if await vm.changeUsername(vm.username, password: vm.usernamePassword),
                       let me = try? await environment.authRepository.me() {
                        environment.currentUser = me
                    }
                }
            } label: {
                HStack {
                    if viewModel?.isSubmittingUsername == true { ProgressView() }
                    Text(viewModel?.isSubmittingUsername == true ? "Updating…" : "Update username")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel?.isSubmittingUsername == true || (viewModel?.username ?? "").isEmpty || (viewModel?.usernamePassword ?? "").isEmpty)
            if let msg = viewModel?.usernameMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(viewModel?.usernameError == true ? .red : .secondary)
            }
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        Section("Email") {
            TextField("New email", text: Binding(
                get: { viewModel?.email ?? "" },
                set: { viewModel?.email = $0.lowercased() }
            ))
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            SecureField("Current password", text: Binding(
                get: { viewModel?.emailPassword ?? "" },
                set: { viewModel?.emailPassword = $0 }
            ))
            .textContentType(.password)
            Button {
                guard let vm = viewModel, !vm.email.isEmpty, !vm.emailPassword.isEmpty else { return }
                Task {
                    if await vm.changeEmail(email: vm.email, password: vm.emailPassword),
                       let me = try? await environment.authRepository.me() {
                        environment.currentUser = me
                    }
                }
            } label: {
                HStack {
                    if viewModel?.isSubmittingEmail == true { ProgressView() }
                    Text(viewModel?.isSubmittingEmail == true ? "Updating…" : "Update email")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel?.isSubmittingEmail == true || (viewModel?.email ?? "").isEmpty || (viewModel?.emailPassword ?? "").isEmpty)
            if let msg = viewModel?.emailMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(viewModel?.emailError == true ? .red : .secondary)
            }
        }
    }

    @ViewBuilder
    private var passwordSection: some View {
        Section("Password") {
            SecureField("Current password", text: Binding(
                get: { viewModel?.oldPassword ?? "" },
                set: { viewModel?.oldPassword = $0 }
            ))
            .textContentType(.password)
            SecureField("New password", text: Binding(
                get: { viewModel?.newPassword ?? "" },
                set: { viewModel?.newPassword = $0 }
            ))
            .textContentType(.newPassword)
            SecureField("Confirm new password", text: Binding(
                get: { viewModel?.confirmPassword ?? "" },
                set: { viewModel?.confirmPassword = $0 }
            ))
            .textContentType(.newPassword)
            Button {
                guard let vm = viewModel, !vm.oldPassword.isEmpty, !vm.newPassword.isEmpty, !vm.confirmPassword.isEmpty else { return }
                Task { await vm.changePassword(oldPassword: vm.oldPassword, newPassword: vm.newPassword, confirmPassword: vm.confirmPassword) }
            } label: {
                HStack {
                    if viewModel?.isSubmittingPassword == true { ProgressView() }
                    Text(viewModel?.isSubmittingPassword == true ? "Updating…" : "Update password")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel?.isSubmittingPassword == true || (viewModel?.oldPassword ?? "").isEmpty || (viewModel?.newPassword ?? "").isEmpty || (viewModel?.confirmPassword ?? "").isEmpty)
            if let msg = viewModel?.passwordMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(viewModel?.passwordError == true ? .red : .secondary)
            }
        }
    }
}

@Observable @MainActor
final class SettingsViewModel {
    var username = ""
    var usernamePassword = ""
    var email = ""
    var emailPassword = ""
    var oldPassword = ""
    var newPassword = ""
    var confirmPassword = ""

    var isSubmittingUsername = false
    var usernameMessage: String?
    var usernameError = false

    var isSubmittingEmail = false
    var emailMessage: String?
    var emailError = false

    var isSubmittingPassword = false
    var passwordMessage: String?
    var passwordError = false

    private let userRepository: any UserRepository

    init(userRepository: any UserRepository) {
        self.userRepository = userRepository
    }

    func changeUsername(_ name: String, password: String) async -> Bool {
        isSubmittingUsername = true
        usernameMessage = nil
        defer { isSubmittingUsername = false }
        do {
            try await userRepository.changeUsername(name, password: password)
            usernameMessage = "Username updated."
            usernameError = false
            self.username = ""
            self.usernamePassword = ""
            return true
        } catch {
            usernameMessage = "Could not update username. Check your password."
            usernameError = true
            return false
        }
    }

    func changeEmail(email: String, password: String) async -> Bool {
        isSubmittingEmail = true
        emailMessage = nil
        defer { isSubmittingEmail = false }
        do {
            try await userRepository.changeEmail(email: email, password: password)
            emailMessage = "Email updated."
            emailError = false
            emailPassword = ""
            return true
        } catch {
            emailMessage = "Could not update email. Check your password."
            emailError = true
            return false
        }
    }

    func changePassword(oldPassword: String, newPassword: String, confirmPassword: String) async {
        isSubmittingPassword = true
        passwordMessage = nil
        defer { isSubmittingPassword = false }
        do {
            try await userRepository.changePassword(oldPassword: oldPassword, newPassword: newPassword, confirmPassword: confirmPassword)
            passwordMessage = "Password updated."
            passwordError = false
            self.oldPassword = ""
            self.newPassword = ""
            self.confirmPassword = ""
        } catch {
            passwordMessage = "Could not update password. Check your current password."
            passwordError = true
        }
    }
}