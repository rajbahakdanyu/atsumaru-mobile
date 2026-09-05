import SwiftUI
import Core

@Observable @MainActor
final class MangaDetailViewModel {
    var manga: MangaPage?
    var isLoading = false
    var loadFailed = false

    private let mangaId: String
    private let mangaRepository: any MangaRepository

    init(mangaId: String, mangaRepository: any MangaRepository) {
        self.mangaId = mangaId
        self.mangaRepository = mangaRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            manga = try await mangaRepository.page(id: mangaId)
            loadFailed = false
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            loadFailed = true
        }
    }
}
