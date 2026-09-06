import SwiftUI
import Core

struct SearchSheet: View {
    @Bindable var viewModel: BrowseViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    TextField("Search manga", text: $text)
                        .focused($fieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { apply() }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // An empty search silently wiped every filter before;
                    // require text to search.
                    Button("Search") { apply() }
                        .bold()
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                fieldFocused = true
            }
        }
    }

    private func apply() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.query.q = trimmed.isEmpty ? "*" : trimmed
        if trimmed.isEmpty {
            viewModel.clearFilters()
        } else {
            viewModel.prepareFilteredReload()
        }
        dismiss()
    }
}
