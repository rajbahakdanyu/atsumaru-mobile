import SwiftUI
import Core

@Observable
@MainActor
final class ComposeViewModel {
    let channel: ForumChannel
    var title = ""
    var content = ""
    var isSubmitting = false
    var didSubmit = false
    var errorMessage: String?

    private let repository: any ForumRepository

    init(channel: ForumChannel, repository: any ForumRepository) {
        self.channel = channel
        self.repository = repository
    }

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    func submit() async {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !c.isEmpty else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await repository.createPost(forumId: channel.id, title: t, content: c)
            didSubmit = true
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            errorMessage = "Couldn't post. Please try again."
        }
    }
}

struct ComposeView: View {
    let channel: ForumChannel
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ComposeViewModel?
    @FocusState private var focusedField: Field?

    private enum Field { case title, body }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel: viewModel)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel?.submit()
                            if viewModel?.didSubmit == true { dismiss() }
                        }
                    } label: {
                        if viewModel?.isSubmitting == true {
                            ProgressView()
                        } else {
                            Text("Post").fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel?.canSubmit == false)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            focusedField = nil
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ComposeViewModel(
                    channel: channel,
                    repository: environment.forumRepository
                )
            }
        }
        .onAppear {
            focusedField = .title
        }
        .interactiveDismissDisabled(viewModel?.isSubmitting == true)
    }

    @ViewBuilder
    private func content(viewModel: ComposeViewModel) -> some View {
        @Bindable var viewModel = viewModel
        Form {
            Section {
                TextField("Title", text: $viewModel.title)
                    .font(.headline)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .body }
            }
            Section {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.content)
                        .focused($focusedField, equals: .body)
                        .frame(minHeight: 180)
                        .scrollDismissesKeyboard(.interactively)
                    if viewModel.content.isEmpty {
                        Text("Start writing…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            } header: {
                Text("Body")
            } footer: {
                Text("Markdown formatting is supported.")
            }
        }
        .alert(
            "Couldn't post",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
