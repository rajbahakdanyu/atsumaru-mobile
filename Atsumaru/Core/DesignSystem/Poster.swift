import SwiftUI
import Kingfisher
import Core

struct Poster: View {
    let item: HomeItem
    var showsTitle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(ImageURLBuilder.poster(item.image))
                .resizable()
                .scaledToFill()
                .frame(width: 108, height: 154)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if showsTitle {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                    .frame(width: 108, height: 32, alignment: .topLeading)
                    .contentShape(Rectangle())
            }
        }
        .contentShape(Rectangle())
    }
}
