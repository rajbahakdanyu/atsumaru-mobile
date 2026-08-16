import SwiftUI
import Kingfisher
import Core

struct Poster: View {
    let item: HomeItem
    var body: some View {
        KFImage(ImageURLBuilder.poster(item.image))
            .resizable()
            .scaledToFill()
            .frame(width: 108, height: 154)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}