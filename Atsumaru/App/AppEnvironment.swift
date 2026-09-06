import SwiftUI
import Core
import os

@Observable
@MainActor
final class AppEnvironment {
    private static let persistenceLog = Logger(subsystem: "dev.atsumaru.app", category: "persistence")

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
    let commentsRepository: any CommentsRepository
    let forumRepository: any ForumRepository
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
        commentsRepository = LiveCommentsRepository(client: apiClient)
        forumRepository = LiveForumRepository(client: apiClient)
        let downloadStore: DownloadStore?
        do { downloadStore = try DownloadStore() }
        catch {
            downloadStore = nil
            Self.persistenceLog.error("DownloadStore init failed: \(String(describing: error), privacy: .public)")
        }
        let downloadMgr = DownloadManager(
            readRepository: readRepository,
            novelRepository: novelRepository,
            store: downloadStore,
            allowsCellularAccess: UserDefaults.standard.bool(forKey: "dev.atsumaru.app.autoDownloadAnyNetwork")
        )
        downloadManager = downloadMgr
        backgroundScheduler = BackgroundScheduler(
            downloadManager: downloadMgr,
            libraryRepository: libraryRepository,
            mangaRepository: mangaRepository
        )
        let progressStore: ProgressStore?
        do { progressStore = try ProgressStore() }
        catch {
            progressStore = nil
            Self.persistenceLog.error("ProgressStore init failed: \(String(describing: error), privacy: .public)")
        }
        self.progressStore = progressStore
        backgroundScheduler.registerTasks()
    }

    func bootstrap() async {
        // Records left queued/downloading by a previous session can never
        // resume on their own; surface them as failed instead of stale
        // "Queued" rows.
        await downloadManager.restoreInterruptedDownloads()
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
        } catch let error as ApiError where error == .http(401) || error == .http(403) {
            currentUser = nil
        } catch {
            // Keep any cached user from the keychain on transient network errors.
        }
        if UserDefaults.standard.object(forKey: "dev.atsumaru.app.backgroundRefresh") == nil
            || UserDefaults.standard.bool(forKey: "dev.atsumaru.app.backgroundRefresh") {
            backgroundScheduler.scheduleRefresh()
            await backgroundScheduler.requestNotificationAuthorization()
        }
    }

    func login(identifier: String, password: String) async throws {
        currentUser = try await authRepository.login(identifier: identifier, password: password)
    }

    func logout() async throws {
        try await authRepository.logout()
        currentUser = nil
    }
}