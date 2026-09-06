import SwiftUI
import Core

/// Retryable load-failure state, native ContentUnavailableView so it styles
/// correctly in ScrollViews and List rows without a heavy glass card
/// (audit: glass card + glassProminent Retry = glass-on-glass).
struct ErrorStateView: View {
    let error: ApiError
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(Self.title(for: error), systemImage: "exclamationmark.triangle")
        } description: {
            Text(Self.message(for: error))
        } actions: {
            Button("Retry", action: retry)
        }
        .frame(maxWidth: .infinity)
    }

    static func title(for error: ApiError) -> String {
        switch error {
        case .offline: "You're offline"
        case .http(401): "Session expired"
        default: "Something went wrong"
        }
    }

    static func message(for error: ApiError) -> String {
        switch error {
        case .offline: "Check your connection and try again."
        case .http(401): "Sign in again to continue."
        case .http(403): "You don't have permission to view this."
        case .http(429): "Rate limited, try again later."
        case .decoding: "Please try again."
        case .server(let message): message
        default: "Please try again."
        }
    }
}
