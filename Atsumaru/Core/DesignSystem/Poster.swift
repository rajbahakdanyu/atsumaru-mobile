import SwiftUI
import Kingfisher
import Core

struct Poster: View {
    let item: HomeItem
    var showsTitle = false

    /// Single thumb-corner-radius token shared by every poster cell
    /// (Poster, detail header, resume rows, downloads cards, history thumbs).
    static let thumbCornerRadius: CGFloat = 10

    /// Convenience init for cells that hold a plain title/image pair
    /// (Library bookmarks, ListDetail items) so all poster cells share
    /// one archetype instead of three divergent ones.
    init(title: String, image: String?, showsTitle: Bool = true) {
        self.item = HomeItem(id: "", title: title, image: image ?? "", medium: "")
        self.showsTitle = showsTitle
    }

    init(item: HomeItem, showsTitle: Bool = false) {
        self.item = item
        self.showsTitle = showsTitle
    }

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage.poster(ImageURLBuilder.poster(item.image), displayScale: displayScale)
                .scaledToFill()
                .frame(width: 108, height: 154)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: Self.thumbCornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Self.thumbCornerRadius, style: .continuous))
            if showsTitle {
                Text(item.title)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                    // No fixed height: the frame grows with Dynamic Type and
                    // long titles wrap instead of clipping.
                    .frame(width: 108, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
            }
        }
        .contentShape(Rectangle())
    }
}
