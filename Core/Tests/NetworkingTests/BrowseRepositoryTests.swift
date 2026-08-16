import Foundation
import Testing
@testable import Core

@Suite(.serialized) struct BrowseRepositoryTests {
    @Test func searchDecodesHits() async throws {
        let json = #"{"found":1,"hits":[{"document":{"id":"x","title":"Test","image":"posters/p.jpg","smallImage":"posters/p.jpg","mediumImage":"posters/p.jpg","largeImage":"posters/p.jpg","isAdult":false,"type":"Manga","medium":"Comic","mbRating":7.0,"views":null}}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/collections/manga/documents/search")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/collections/manga/documents/search")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveBrowseRepository(client: client)
        let result = try await repo.search(SearchQuery())
        #expect(result.found == 1)
        #expect(result.hits.count == 1)
        #expect(result.hits.first?.document.title == "Test")
    }

    @Test func searchDecodesRealDocumentShape() async throws {
        // The live search endpoint returns documents with `poster`/`posterSmall`/
        // `posterMedium` and an Int `views`, not the HomeItem `image` fields.
        let json = #"{"found":1,"hits":[{"document":{"id":"2VgNt","title":"Witch Hat Atelier","poster":"/static/posters/N3HO30V76uWZV9iG.jpg","posterSmall":"/static/posters/N3HO30V76uWZV9iG-small.avif","posterMedium":"/static/posters/N3HO30V76uWZV9iG-medium.avif","isAdult":false,"type":"Manga","medium":"Comic","mbRating":8.478094285714281,"views":68254041}}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/collections/manga/documents/search")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveBrowseRepository(client: client)
        let result = try await repo.search(SearchQuery())
        let item = try #require(result.hits.first?.document)
        #expect(item.title == "Witch Hat Atelier")
        #expect(item.image == "/static/posters/N3HO30V76uWZV9iG.jpg")
        #expect(item.views == "68254041")
    }

    @Test func availableFiltersDecodes() async throws {
        let json = #"{"genres":[{"id":"5","name":"Action"}],"tags":[{"id":"adaptation","name":"Adaptation"}],"types":[{"id":"Manga","name":"Manga"}],"statuses":[{"id":"ongoing","name":"Ongoing"}]}"#
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { request in
            #expect(request.url?.path == "/api/explore/availableFilters")
            let resp = HTTPURLResponse(url: URL(string: "https://atsu.moe/api/explore/availableFilters")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }
        let client = APIClient(session: URLSession(configuration: config))
        let repo = LiveBrowseRepository(client: client)
        let filters = try await repo.availableFilters()
        #expect(filters.genres.first?.name == "Action")
        #expect(filters.tags.first?.id == "adaptation")
        #expect(filters.types.first?.name == "Manga")
        #expect(filters.statuses.first?.id == "ongoing")
    }
}