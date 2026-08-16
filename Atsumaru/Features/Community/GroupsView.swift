import SwiftUI
import Core

@Observable
@MainActor
final class GroupsViewModel {
    var groups: [CommunityGroup] = []
    var isLoading = false
    var error: ApiError?
    private let repository: any CommunityRepository
    private var loaded = false

    init(repository: any CommunityRepository) {
        self.repository = repository
    }

    func load(force: Bool = false) async {
        guard !loaded || force else { return }
        loaded = true
        isLoading = true
        defer { isLoading = false }
        do {
            groups = try await repository.groups(page: 0)
            error = nil
        } catch {
            self.error = (error as? ApiError) ?? .decoding
        }
    }
}

struct GroupsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: GroupsViewModel?
    @State private var showingCreate = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                LoadingSkeletonView()
            }
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = GroupsViewModel(repository: environment.communityRepository)
            }
            await viewModel?.load()
        }
        .refreshable { await viewModel?.load(force: true) }
        .sheet(isPresented: $showingCreate) {
            CreateGroupView { Task { await viewModel?.load(force: true) } }
                .environment(environment)
        }
    }

    @ViewBuilder
    private func content(viewModel: GroupsViewModel) -> some View {
        if viewModel.isLoading && viewModel.groups.isEmpty {
            LoadingSkeletonView()
        } else if let error = viewModel.error, viewModel.groups.isEmpty {
            ErrorStateView(error: error) { Task { await viewModel.load(force: true) } }
        } else {
            List {
                if viewModel.groups.isEmpty {
                    EmptyStateView(message: "No groups yet")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.groups) { group in
                        NavigationLink {
                            GroupDetailView(group: group)
                        } label: {
                            groupRow(group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func groupRow(_ group: CommunityGroup) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name ?? "Untitled")
                        .font(.body.bold())
                    if let tag = group.tag, !tag.isEmpty {
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let bio = group.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let count = group.memberCount {
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@Observable
@MainActor
final class GroupDetailViewModel {
    let group: CommunityGroup
    var detail: CommunityGroup?
    var isLoading = false
    var loadFailed = false
    var isMember = false
    var joinBusy = false

    private let repository: any CommunityRepository

    init(group: CommunityGroup, repository: any CommunityRepository) {
        self.group = group
        self.repository = repository
        self.isMember = group.isMember ?? false
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let g = try await repository.group(id: group.id)
            detail = g
            isMember = g.isMember ?? isMember
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    func toggleMembership() async {
        let prev = isMember
        guard !joinBusy else { return }
        joinBusy = true
        defer { joinBusy = false }
        isMember = !prev
        do {
            if prev {
                try await repository.leaveGroup(id: group.id)
            } else {
                try await repository.joinGroup(id: group.id)
            }
        } catch {
            isMember = prev
        }
    }
}

struct GroupDetailView: View {
    let group: CommunityGroup
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: GroupDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(group.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = GroupDetailViewModel(group: group, repository: environment.communityRepository)
            }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func content(viewModel: GroupDetailViewModel) -> some View {
        if viewModel.loadFailed && viewModel.detail == nil {
            ContentUnavailableView {
                Label("Couldn't load group", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Retry") { Task { await viewModel.load() } }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let display = viewModel.detail ?? group
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(display.name ?? "Untitled")
                                .font(.title3.bold())
                            if let tag = display.tag, !tag.isEmpty {
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let type = display.type, !type.isEmpty {
                                Text(type.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .glassCapsule()
                            }
                        }
                        if let count = display.memberCount {
                            Text("\(count) members")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let bio = display.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        Task { await viewModel.toggleMembership() }
                    } label: {
                        Text(viewModel.isMember ? "Leave group" : "Join group")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .modifier(ProminentToggleStyle(active: viewModel.isMember))
                    .disabled(viewModel.joinBusy)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }
}

@Observable
@MainActor
final class CreateGroupViewModel {
    var name = ""
    var tag = ""
    var type = "open"
    var bio = ""
    var isSaving = false
    var saveFailed = false

    private let repository: any CommunityRepository
    let onComplete: () -> Void

    init(repository: any CommunityRepository, onComplete: @escaping () -> Void) {
        self.repository = repository
        self.onComplete = onComplete
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.createGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                tag: tag.trimmingCharacters(in: .whitespaces),
                type: type,
                bio: bio
            )
            saveFailed = false
            onComplete()
        } catch {
            saveFailed = true
        }
    }
}

struct CreateGroupView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateGroupViewModel?
    let onCreated: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: nameBinding)
                    TextField("Tag (no #)", text: tagBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Type") {
                    Picker("Type", selection: typeBinding) {
                        Text("Open").tag("open")
                        Text("Closed").tag("closed")
                        Text("Private").tag("private")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Bio") {
                    TextField("Describe your group", text: bioBinding, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let vm = viewModel, vm.saveFailed {
                    Section {
                        Text("Couldn't create group. Try again.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        guard let viewModel else { return }
                        Task {
                            await viewModel.save()
                            if !viewModel.saveFailed { dismiss() }
                        }
                    }
                    .disabled(viewModel?.canSave == false)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CreateGroupViewModel(
                    repository: environment.communityRepository,
                    onComplete: onCreated
                )
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { viewModel?.name ?? "" }, set: { viewModel?.name = $0 })
    }
    private var tagBinding: Binding<String> {
        Binding(get: { viewModel?.tag ?? "" }, set: { viewModel?.tag = $0 })
    }
    private var typeBinding: Binding<String> {
        Binding(get: { viewModel?.type ?? "open" }, set: { viewModel?.type = $0 })
    }
    private var bioBinding: Binding<String> {
        Binding(get: { viewModel?.bio ?? "" }, set: { viewModel?.bio = $0 })
    }
}