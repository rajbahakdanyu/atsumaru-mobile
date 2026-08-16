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

    @Test func buildsQueryWithSearchText() {
        var q = SearchQuery()
        q.q = "witch hat"
        let items = q.toQueryItems()
        #expect(items["q"] == "witch hat")
    }
}