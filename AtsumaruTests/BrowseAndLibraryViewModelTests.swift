import Foundation
import Testing
@testable import Core
@testable import Atsumaru

@Suite
@MainActor
struct BrowseAndLibraryViewModelTests {
    @Test func filteredPaginationDeduplicatesAndAdvancesPages() async {
        let requestedPages = Box<[Int]>([])
        let firstItems = (0..<30).map { HomeItem(id: "m\($0)", title: "M\($0)", image: "", medium: "Comic") }
        let secondItems = [firstItems[29], HomeItem(id: "m30", title: "M30", image: "", medium: "Comic")]
        let responses = Box([
            SearchResult(found: 31, hits: firstItems.map(SearchHit.init(document:))),
            SearchResult(found: 31, hits: secondItems.map(SearchHit.init(document:))),
        ])
        let browse = BrowseRepositoryStub { query in
            requestedPages.value.append(query.page)
            var pending = responses.value
            let response = pending.removeFirst()
            responses.value = pending
            return response
        }
        let viewModel = BrowseViewModel(
            browseRepository: browse,
            homeRepository: HomeRepositoryStub()
        )

        await viewModel.reloadFiltered()
        await viewModel.loadMoreFiltered()

        #expect(requestedPages.value == [1, 2])
        #expect(viewModel.filteredResults.count == 31)
        #expect(Set(viewModel.filteredResults.map(\.id)).count == 31)
        #expect(!viewModel.filteredHasMore)
    }

    @Test func clearFiltersResetsEveryFilterAndSort() {
        let viewModel = BrowseViewModel(
            browseRepository: BrowseRepositoryStub(),
            homeRepository: HomeRepositoryStub()
        )
        viewModel.query.q = "query"
        viewModel.query.genres = ["g"]
        viewModel.query.tags = ["t"]
        viewModel.query.types = ["Manga"]
        viewModel.query.statuses = ["Ongoing"]
        viewModel.query.mediums = ["Comic"]
        viewModel.query.minChapters = 10
        viewModel.sort = .viewsDesc

        viewModel.clearFilters()

        #expect(viewModel.query.q == "*")
        #expect(viewModel.query.genres.isEmpty)
        #expect(viewModel.query.tags.isEmpty)
        #expect(viewModel.query.types.isEmpty)
        #expect(viewModel.query.statuses.isEmpty)
        #expect(viewModel.query.mediums.isEmpty)
        #expect(viewModel.query.minChapters == nil)
        #expect(viewModel.sort == .relevance)
    }

    @Test func libraryLoadKeepsSuccessfulSectionsAndReportsFailure() async throws {
        let bookmark: Bookmark = try decode(from: #"{"id":"m1","title":"Saved","medium":"Comic"}"#)
        let repository = LibraryRepositoryStub(
            bookmarks: { [bookmark] },
            history: { throw ApiError.offline }
        )
        let viewModel = LibraryViewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.bookmarks.map(\.id) == ["m1"])
        #expect(viewModel.history.isEmpty)
        #expect(viewModel.error == .offline)
        #expect(!viewModel.isLoading)
    }

    @Test func createListTrimsNameAndRefreshesLists() async throws {
        let createdName = Box<String?>(nil)
        let list: UserList = try decode(from: #"{"id":"l1","title":"Favorites"}"#)
        let repository = LibraryRepositoryStub(
            lists: { [list] },
            create: { createdName.value = $0 }
        )
        let viewModel = LibraryViewModel(repository: repository)
        viewModel.newListName = "  Favorites  "

        await viewModel.createList()

        #expect(createdName.value == "Favorites")
        #expect(viewModel.newListName.isEmpty)
        #expect(viewModel.lists.map(\.id) == ["l1"])
        #expect(viewModel.actionError == nil)
    }

    @Test func accountLoadPublishesProfileAndError() async throws {
        let profile: PrivateProfile = try decode(from: #"{"id":"u1","username":"dan"}"#)
        let successful = AccountViewModel(userRepository: UserRepositoryStub { profile })
        await successful.load()
        #expect(successful.profile?.id == "u1")
        #expect(successful.error == nil)

        let failing = AccountViewModel(userRepository: UserRepositoryStub { throw ApiError.offline })
        await failing.load()
        #expect(failing.profile == nil)
        #expect(failing.error == .offline)
        }
    }
