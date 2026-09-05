import SwiftUI

extension View {
    /// Presents the sign-in sheet bound to `isPresented`, dismissing it on
    /// success. Shared across Library, Forum, and Account to avoid three copies.
    func authSheet(isPresented: Binding<Bool>, environment: AppEnvironment) -> some View {
        sheet(isPresented: isPresented) {
            AuthFlowView(onSuccess: { isPresented.wrappedValue = false })
                .environment(environment)
        }
    }
}

/// Shared poster-grid column definition used by Browse and Library.
enum PosterGrid {
    static let columns: [GridItem] = [GridItem(.adaptive(minimum: 108), spacing: 12)]
}
