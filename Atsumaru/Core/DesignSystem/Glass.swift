import SwiftUI

struct GlassCapsule: ViewModifier {
    var interactive: Bool

    func body(content: Content) -> some View {
        content
            .glassEffect(
                interactive
                    ? .regular.tint(Color.white.opacity(0.06)).interactive()
                    : .regular.tint(Color.white.opacity(0.06)),
                in: .capsule
            )
    }
}

extension View {
    /// Glass capsule reserved for floating chrome (safeAreaInset bars,
    /// composers, floating sliders). Inline elements must not use it.
    func glassCapsule(interactive: Bool = false) -> some View {
        modifier(GlassCapsule(interactive: interactive))
    }
}
