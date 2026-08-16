import Testing
@testable import Core

struct SearchQueryTests {
    @Test func buildsDefaultQuery() {
        let q = SearchQuery()
        let items = q.toQueryItems()
        #expect(items["q"] == "*")
        #expect(items["query_by"] == "title,otherNames")
        #expect(items["per_page"] == "30")
        #expect(items["filter_by"] == nil)
        #expect(items["sort_by"] == nil)
    }

    @Test func buildsFilteredQuery() {
        var q = SearchQuery()
        q.genres = ["39", "5"]
        q.statuses = ["Ongoing"]
        q.types = ["Manga"]
        q.minChapters = 100
        q.sortBy = "mbRating:desc"
        let items = q.toQueryItems()
        #expect(items["filter_by"] == "genreIds:=[39,5] && status:=[Ongoing] && type:=[Manga] && chapterCount:>=100")
        #expect(items["sort_by"] == "mbRating:desc")
    }

    @Test func buildsTagAndMediumFilter() {
        var q = SearchQuery()
        q.tags = ["250"]
        q.mediums = ["Novel"]
        let items = q.toQueryItems()
        #expect(items["filter_by"] == "tagIds:=[250] && medium:=[Novel]")
    }
}
