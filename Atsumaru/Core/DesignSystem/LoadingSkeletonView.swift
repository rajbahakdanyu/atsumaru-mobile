import SwiftUI

struct LoadingSkeletonView: View {
    @State private var pulsing = false

    private let widths: [CGFloat] = [220, 280, 200, 260, 240, 180]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<widths.count, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: widths[index], height: 16)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(pulsing ? 0.4 : 0.9)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}
