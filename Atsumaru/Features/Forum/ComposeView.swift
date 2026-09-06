import SwiftUI
import Core
import os

private let logger = Logger(subsystem: "dev.atsumaru.app", category: "compose")

@Observable
@MainActor
final class ComposeViewModel {
    var channels: [ForumChannel] = []
    var selectedChannel: ForumChannel?
    var tags: [ForumTag] = []
    var selectedTagIds: Set<String> = []
    var spoiler = false
    var title = ""
    var content = ""
    var isSubmitting = false
    var didSubmit = false
    var errorMessage: String?

    var usableTags: [ForumTag] {
        tags.filter { $0.modOnly != true && $0.terminal != true }
    }

    private let repository: any ForumRepository

    init(repository: any ForumRepository) {
        self.repository = repository
    }

    var canSubmit: Bool {
        guard let channel = selectedChannel else { return false }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if channel.tagsRequired == true && selectedTagIds.isEmpty { return false }
        if selectedTagIds.count > (channel.maxTagsPerPost ?? 3) { return false }
        return !isSubmitting
    }

    var tagsHint: String? {
        guard let channel = selectedChannel else { return nil }
        let max = channel.maxTagsPerPost ?? 3
        if selectedTagIds.count > max {
            return "Up to \(max) tags per post."
        }
        if channel.tagsRequired == true && selectedTagIds.isEmpty {
            return "This channel requires at least one tag."
        }
        return nil
    }

    func load(initialChannel: ForumChannel?) async {
        do {
            channels = try await repository.channels(includeAdult: true)
            logger.info("channels loaded: \(self.channels.count)")
        } catch {
            logger.error("channels failed to load: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't load channels. Please try again."
        }
        if selectedChannel == nil {
            selectedChannel = initialChannel ?? channels.first
        }
        await loadTags()
    }

    func select(channel: ForumChannel) async {
        guard channel.id != selectedChannel?.id else { return }
        selectedChannel = channel
        selectedTagIds = []
        await loadTags()
    }

    func toggle(tag: ForumTag) {
        let max = selectedChannel?.maxTagsPerPost ?? 3
        if selectedTagIds.contains(tag.id) {
            selectedTagIds.remove(tag.id)
        } else if selectedTagIds.count < max {
            selectedTagIds.insert(tag.id)
        }
    }

    func loadTags() async {
        guard let forumId = selectedChannel?.id else {
            tags = []
            return
        }
        tags = (try? await repository.tags(forumId: forumId)) ?? []
        logger.info("tags for \(forumId, privacy: .public): \(self.tags.count) usable \(self.usableTags.count)")
        selectedTagIds = selectedTagIds.filter { id in tags.contains(where: { $0.id == id }) }
    }

    func submit() async {
        guard let channel = selectedChannel else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !c.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await repository.createPost(
                forumId: channel.id, title: t, content: c,
                spoiler: spoiler, tagIds: Array(selectedTagIds)
            )
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
    var initialChannel: ForumChannel?
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
                viewModel = ComposeViewModel(repository: environment.forumRepository)
                await viewModel?.load(initialChannel: initialChannel)
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
                channelPicker(viewModel: viewModel)
                TextField("Title", text: $viewModel.title)
                    .font(.headline)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .body }
            }
            tagSection(viewModel: viewModel)
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
            Section {
                Toggle("Mark as spoiler", isOn: $viewModel.spoiler)
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

    @ViewBuilder
    private func channelPicker(viewModel: ComposeViewModel) -> some View {
        Picker("Channel", selection: Binding(
            get: { viewModel.selectedChannel?.id ?? "" },
            set: { newValue in
                guard let channel = viewModel.channels.first(where: { $0.id == newValue }) else { return }
                Task { await viewModel.select(channel: channel) }
            }
        )) {
            if viewModel.selectedChannel == nil {
                Text("Select a channel").tag("")
            }
            ForEach(viewModel.channels) { channel in
                Text(channel.name ?? "Untitled").tag(channel.id)
            }
        }
    }

    @ViewBuilder
    private func tagSection(viewModel: ComposeViewModel) -> some View {
        Section {
            if viewModel.usableTags.isEmpty {
                Text("No tags in this channel")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.usableTags) { tag in
                        Button {
                            viewModel.toggle(tag: tag)
                        } label: {
                            Label(tag.name ?? tag.id, systemImage: viewModel.selectedTagIds.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(viewModel.selectedTagIds.contains(tag.id) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .tint(viewModel.selectedTagIds.contains(tag.id) ? .accentColor : .primary)
                    }
                }
            }
        } header: {
            Text("Tags")
        } footer: {
            if let hint = viewModel.tagsHint {
                Text(hint)
            }
        }
    }
}
