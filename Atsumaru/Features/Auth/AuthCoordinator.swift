import AuthenticationServices
import UIKit
import Core

@MainActor
final class AuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let callbackScheme = "atsumaru"

    private let authRepository: any AuthRepository
    private var session: ASWebAuthenticationSession?

    init(authRepository: any AuthRepository) {
        self.authRepository = authRepository
        super.init()
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows where window.isKeyWindow {
                    return window
                }
            }
            return ASPresentationAnchor()
        }
    }

    func authenticate(provider: String) async throws {
        let urlString = try await authRepository.oauthURL(provider: provider)
        guard let url = URL(string: urlString) else { throw ApiError.invalidURL }
        try await startSession(url: url)
    }

    private func startSession(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            session.start()
        }
    }
}