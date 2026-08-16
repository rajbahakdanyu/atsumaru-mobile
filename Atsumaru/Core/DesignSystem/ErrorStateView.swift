import SwiftUI
import Core

struct ErrorStateView: View {
    let error: ApiError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(Self.message(for: error))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.glassProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    static func message(for error: ApiError) -> String {
        switch error {
        case .http(401): "Session expired"
        case .http(403): "Permission denied"
        case .http(429): "Rate limited, try again later"
        case .offline: "You're offline"
        case .decoding: "Something went wrong"
        case .server(let message): message
        default: "Something went wrong"
        }
    }
}
