import SwiftUI
import Core

struct CommunityView: View {
    @State private var slug = ""

    var body: some View {
        Form {
            Section("Groups") {
                NavigationLink {
                    GroupsView()
                } label: {
                    Label("Browse groups", systemImage: "person.3.fill")
                }
            }
            Section("Profile lookup") {
                TextField("Username or slug", text: $slug)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                let trimmed = slug.trimmingCharacters(in: .whitespaces)
                NavigationLink {
                    ProfileView(slug: trimmed)
                } label: {
                    Label("View profile", systemImage: "person.crop.circle")
                }
                .disabled(trimmed.isEmpty)
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProminentToggleStyle: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.buttonStyle(.bordered)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}