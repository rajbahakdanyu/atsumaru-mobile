import SwiftUI
import Core

@Observable
@MainActor
final class AppEnvironment {
    let apiClient = APIClient()
    // Repositories are created lazily in their phase; for now the client exists.
}