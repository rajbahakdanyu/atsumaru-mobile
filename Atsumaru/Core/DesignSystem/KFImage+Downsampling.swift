import SwiftUI
import Kingfisher

extension KFImage {
    /// Poster thumbnail downsampled to at most 216×308 pt (2× the 108×154
    /// grid cell) at the display scale, so full-resolution posters are never
    /// fully decoded. All poster call sites share this one processor identity,
    /// letting Kingfisher cache a single processed variant per source image.
    /// Keeps the default cache/fade behavior; only adds decode capping.
    static func poster(_ source: URL?, displayScale: CGFloat) -> KFImage {
        KFImage(source)
            .downsampling(size: CGSize(width: 216, height: 308))
            .scaleFactor(max(displayScale, 1))
            .resizable()
    }

    /// Reader page downsampled so the decoded buffer's width matches the
    /// fit-to-width render width (`viewportWidth` × displayScale). Kingfisher's
    /// downsampler caps the LONG side at max(w, h) × scale, so the cap height
    /// is derived from the page aspect: for portrait pages (aspect < 1) the
    /// height is the long side (viewportWidth / aspect), making the decoded
    /// width exactly viewportWidth × scale; for landscape pages (aspect ≥ 1)
    /// viewportWidth stays the long side, so the decoded width is still
    /// viewportWidth × scale without over-decoding the height. A nil/zero or
    /// non-finite aspect falls back to the square cap.
    static func readerPage(_ source: URL?, viewportWidth: CGFloat, aspectRatio: Double?, displayScale: CGFloat) -> KFImage {
        let width = max(viewportWidth, 1)
        let capHeight: CGFloat
        if let aspectRatio, aspectRatio.isFinite, aspectRatio > 0 {
            capHeight = max(width / CGFloat(aspectRatio), 1)
        } else {
            capHeight = width
        }
        return KFImage(source)
            .downsampling(size: CGSize(width: width, height: capHeight))
            .scaleFactor(max(displayScale, 1))
            .resizable()
    }
}
