import SwiftUI

/// A thumbnail for a Photos item, loaded by its identifier. Callers set the frame and clipping.
struct AssetThumbnail: View {
    let assetID: String
    /// Requested size in pixels, so thumbnails stay sharp on high-density screens.
    var pixelSide: CGFloat = 240

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .task(id: assetID) {
            guard let asset = PhotoLibrary.asset(withID: assetID) else { return }
            image = await PhotoLibrary.thumbnail(for: asset, pixelSide: pixelSide)
        }
    }
}
