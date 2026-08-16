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

    private let repository: any LibraryRepository
    private var loaded = false

    init(repository: any LibraryRepository) {
        self.repository = repository
    }

    func load(force: Bool = false) async {
        guard !loaded || force else { return }
        loaded = true
        isLoading = true
        defer { isLoading = false }

        async let cr = try? repository.continueReading()
        async let bm = try? repository.bookmarks(offset: 0, limit: 40)
        async let hi = try? repository.history()
        async let li = try? repository.lists()

        if let value = await cr { continueReading = value }
        if let value = await bm { bookmarks = value }
        if let value = await hi { history = value }
        if let value = await li { lists = value }
    }

    func createList() async {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        creatingList = true
        defer { creatingList = false }
        do {
            try await repository.createList(name: name)
            newListName = ""
            if let refreshed = try? await repository.lists() { lists = refreshed }
        } catch {
            // best-effort: leave existing lists; surface nothing for now
        }
    }

    func deleteList(_ list: UserList) async {
        do {
            try await repository.deleteList(id: list.id)
            lists.removeAll { $0.id == list.id }
        } catch {
            // best-effort: keep the list
        }
    }
}