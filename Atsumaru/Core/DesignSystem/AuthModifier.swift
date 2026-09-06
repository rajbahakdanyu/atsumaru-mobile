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

/// Shared poster-grid column definition used by Browse, Library, and
/// ListDetailView. `spacing` is the single grid-gutter token for the same
/// poster grid everywhere (audit: Browse 16 vs ListDetail 12 drift).
enum PosterGrid {
    static let spacing: CGFloat = 16
    static let columns: [GridItem] = [GridItem(.adaptive(minimum: 108), spacing: spacing)]
}
