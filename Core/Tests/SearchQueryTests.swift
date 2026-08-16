import Testing
@testable import Core

struct SearchQueryTests {
    @Test func buildsDefaultQuery() {
        let q = SearchQuery()
        let items = q.toQueryItems()
        #expect(items["q"] == "*")
        #expect(items["query_by"] == "title,otherNames")
        #expect(items["per_page"] == "30")
    }

    @Test func buildsFilteredQuery() {
        var q = SearchQuery()
        q.genres = ["5", "6"]
        q.sortBy = "mbRating:desc"
        let items = q.toQueryItems()
        #expect(items["filter_by"] == "genreIds:=[5,6]")
        #expect(items["sort_by"] == "mbRating:desc")
    }
}