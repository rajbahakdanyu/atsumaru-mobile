import SwiftUI
import Core

@Observable
@MainActor
final class AppEnvironment {
    let apiClient = APIClient()
    let keychainStore = KeychainStore(service: "dev.atsumaru.app")
    let homeRepository: any HomeRepository
    let browseRepository: any BrowseRepository
    let mangaRepository: any MangaRepository
    let readRepository: any ReadRepository
    let novelRepository: any NovelRepository
    let authRepository: any AuthRepository
    let userRepository: any UserRepository
    let libraryRepository: any LibraryRepository
    let downloadManager: DownloadManager
    let backgroundScheduler: BackgroundScheduler
    var currentUser: AuthUser?
    let progressStore: ProgressStore?

    init() {
        homeRepository = LiveHomeRepository(client: apiClient)
        browseRepository = LiveBrowseRepository(client: apiClient)
        mangaRepository = LiveMangaRepository(client: apiClient)
        readRepository = LiveReadRepository(client: apiClient)
        novelRepository = LiveNovelRepository(client: apiClient)
        authRepository = LiveAuthRepository(client: apiClient, keychain: keychainStore)
        userRepository = LiveUserRepository(client: apiClient)
        libraryRepository = LiveLibraryRepository(client: apiClient)
        let store = try? DownloadStore()
        let downloadMgr = DownloadManager(readRepository: readRepository, store: store)
        downloadManager = downloadMgr
        backgroundScheduler = BackgroundScheduler(
            downloadManager: downloadMgr,
            libraryRepository: libraryRepository,
            mangaRepository: mangaRepository
        )
        progressStore = try? ProgressStore()
    }

    func bootstrap() async {
        if let saved = keychainStore.load(key: "auth-user"),
           let user = try? JSONDecoder().decode(AuthUser.self, from: saved) {
            currentUser = user
        }
        do {
            if let me = try await authRepository.me() {
                currentUser = me
            } else {
                currentUser = nil
            }
        } catch {
            // Keep any cached user from the keychain on transient network errors.
        }
        backgroundScheduler.registerTasks()
        if UserDefaults.standard.object(forKey: "dev.atsumaru.app.backgroundRefresh") == nil
            || UserDefaults.standard.bool(forKey: "dev.atsumaru.app.backgroundRefresh") {
            backgroundScheduler.scheduleRefresh()
            await backgroundScheduler.requestNotificationAuthorization()
        }
    }

    func login(email: String, password: String) async throws {
        try await authRepository.login(email: email, password: password)
        if let me = try? await authRepository.me() { currentUser = me }
    }

    func signup(email: String, username: String, password: String) async throws {
        try await authRepository.signup(email: email, username: username, password: password)
        if let me = try? await authRepository.me() { currentUser = me }
    }

    func logout() async throws {
        try await authRepository.logout()
        currentUser = nil
    }
}