import SwiftUI
import Core

/// "Add to list" sheet from the manga detail menu: lists the user's lists
/// (pinned ones starred); tapping a row adds the manga and shows a per-row
/// status ("Added" / "Already in list" / error).
struct AddToListView: View {
    let mangaId: String

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var lists: [UserList] = []
    @State private var isLoading = true
    @State private var loadError: ApiError?
    @State private var statuses: [String: String] = [:]
    @State private var inFlight: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if lists.isEmpty, let loadError {
                    ErrorStateView(error: loadError) { Task { await load() } }
                } else if lists.isEmpty {
                    ContentUnavailableView(
                        "No lists yet",
                        systemImage: "list.bullet",
                        description: Text("Create a list in the Library tab first.")
                    )
                } else {
                    List {
                        ForEach(lists) { list in
                            Button {
                                add(to: list)
                            } label: {
                                row(list)
                            }
                            .disabled(inFlight.contains(list.id))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add to list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { if isLoading { await load() } }
    }

    private func load() async {
        do {
            lists = try await environment.libraryRepository.lists()
            loadError = nil
        } catch {
            loadError = (error as? ApiError) ?? .decoding
        }
        isLoading = false
    }

    @ViewBuilder
    private func row(_ list: UserList) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name ?? "Untitled list")
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let status = statuses[list.id] {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if list.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func add(to list: UserList) {
        guard !inFlight.contains(list.id) else { return }
        inFlight.insert(list.id)
        statuses[list.id] = nil
        Task {
            defer { inFlight.remove(list.id) }
            do {
                let alreadyExists = try await environment.libraryRepository.addManga(
                    listId: list.id,
                    mangaId: mangaId
                )
                statuses[list.id] = alreadyExists ? "Already in list" : "Added"
            } catch {
                statuses[list.id] = "Couldn't add. Try again."
            }
        }
    }
}
