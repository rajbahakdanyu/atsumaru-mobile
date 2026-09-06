import SwiftUI
import Core

@Observable @MainActor
final class LibraryViewModel {
    enum Segment: String, CaseIterable, Identifiable {
        case continueReading, bookmarks, history, lists
        var id: String { rawValue }
        var label: String {
            switch self {
            case .continueReading: "Continue"
            case .bookmarks: "Bookmarks"
            case .history: "History"
            case .lists: "Lists"
            }
        }
    }

    var segment: Segment = .continueReading
    var continueReading: [ContinueReadingItem] = []
    var bookmarks: [Bookmark] = []
    var history: [HistoryEntry] = []
    var lists: [UserList] = []
    var isLoading = false
    var creatingList = false
    var newListName = ""
    var error: ApiError?
    var actionError: String?

    private let repository: any LibraryRepository
    private var loaded = false

    init(repository: any LibraryRepository) {
        self.repository = repository
    }

    var hasNothing: Bool {
        continueReading.isEmpty && bookmarks.isEmpty && history.isEmpty && lists.isEmpty
    }

    func load(force: Bool = false) async {
        guard !loaded || force else { return }
        loaded = true
        isLoading = true
        defer { isLoading = false }

        async let cr = repository.continueReading()
        async let bm = repository.bookmarks(offset: 0, limit: 40)
        async let hi = repository.history()
        async let li = repository.lists()

        var firstError: ApiError?
        do { continueReading = try await cr } catch { firstError = firstError ?? (error as? ApiError) ?? .decoding }
        do { bookmarks = try await bm } catch { firstError = firstError ?? (error as? ApiError) ?? .decoding }
        do { history = try await hi } catch { firstError = firstError ?? (error as? ApiError) ?? .decoding }
        do { lists = try await li } catch { firstError = firstError ?? (error as? ApiError) ?? .decoding }
        self.error = firstError
    }

    func createList() async {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        creatingList = true
        defer { creatingList = false }
        do {
            try await repository.createList(name: name)
            newListName = ""
            actionError = nil
            if let refreshed = try? await repository.lists() { lists = refreshed }
        } catch {
            actionError = "Couldn't create list. Try again."
        }
    }

    func deleteList(_ list: UserList) async {
        do {
            try await repository.deleteList(id: list.id)
            lists.removeAll { $0.id == list.id }
            actionError = nil
        } catch {
            actionError = "Couldn't delete list. Try again."
        }
    }

    func setPinned(_ list: UserList, _ pinned: Bool) async {
        do {
            try await repository.setPinned(listId: list.id, pinned: pinned)
            actionError = nil
            if let refreshed = try? await repository.lists() { lists = refreshed }
        } catch {
            actionError = "Couldn't update the list. Try again."
        }
    }
}