import AVFoundation
import Photos
import UIKit

/// Reads photos and videos from the Photos library, by identifier, for thumbnails and movies.
enum PhotoLibrary {
    enum AccessError: LocalizedError {
        case denied

        var errorDescription: String? {
            "Allow access to Photos in Settings → Photo Labeller to use your photos and videos."
        }
    }

    /// Asks for read and write access. Read access lets a saved project find the same items again.
    static func requestAccess() async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { throw AccessError.denied }
    }

    /// Every photo and video in the library, newest first.
    static func fetchMedia() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                        PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        var assets: [PHAsset] = []
        PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    static func asset(withID id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    /// A square thumbnail. `pixelSide` is the size in pixels.
    static func thumbnail(for asset: PHAsset, pixelSide: CGFloat) async -> UIImage? {
        await request(asset, pixelSide: pixelSide, contentMode: .aspectFill, resizeMode: .fast)
    }

    /// The photo scaled to fit inside `pixelSide` pixels, for movie frames.
    static func photo(for asset: PHAsset, pixelSide: CGFloat) async -> UIImage? {
        await request(asset, pixelSide: pixelSide, contentMode: .aspectFit, resizeMode: .exact)
    }

    /// The video, downloaded from iCloud first if needed.
    static func videoAsset(for asset: PHAsset) async -> AVAsset? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }

    private static func request(_ asset: PHAsset,
                                pixelSide: CGFloat,
                                contentMode: PHImageContentMode,
                                resizeMode: PHImageRequestOptionsResizeMode) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = resizeMode
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: pixelSide, height: pixelSide),
                contentMode: contentMode,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
