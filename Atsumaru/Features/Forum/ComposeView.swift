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
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await repository.createPost(forumId: channel.id, title: t, content: c)
            didSubmit = true
        } catch {
        }
    }
}

struct ComposeView: View {
    let channel: ForumChannel
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ComposeViewModel?

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
    }

    @ViewBuilder
    private func content(viewModel: ComposeViewModel) -> some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(channel.name ?? "Forum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Title", text: $viewModel.title, axis: .vertical)
                    .lineLimit(1...2)
                    .textFieldStyle(.plain)
                    .font(.body.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassCapsule()
                Text("Body (Markdown)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.content)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .padding(8)
                    .glassCapsule()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}