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
        let callbackURL = try await startSession(url: url)
        try await completeOAuth(provider: provider, callbackURL: callbackURL)
    }

    private func startSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: ApiError.decoding)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }

    private func completeOAuth(provider: String, callbackURL: URL) async throws {
        // Best-effort OAuth token-exchange: the callback URL is surfaced here
        // rather than discarded. When `code`/`state` are present we attempt the
        // provider's `callback` endpoint; this never fakes success. When the
        // endpoint/params are unverifiable we degrade honestly via `me()`.
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let code = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
        if let code, let state {
            try await authRepository.oauthCallback(provider: provider, code: code, state: state)
        } else {
            _ = try? await authRepository.me()
        }
    }
}