import SwiftUI

struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(Color.white.opacity(0.06)).interactive(), in: .capsule)
    }
}

extension View {
    func glassCapsule() -> some View { modifier(GlassCapsule()) }
}