import Photos
import UIKit

enum PhotoSaver {
    enum SaveError: LocalizedError {
        case accessDenied

        var errorDescription: String? {
            "Allow photo access in Settings → Photo Labeller to save images to your library."
        }
    }

    /// Saves the image to the photo library using add-only access.
    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.accessDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
