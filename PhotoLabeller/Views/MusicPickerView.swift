import MediaPlayer
import SwiftUI

/// The system Music picker. Returns one song from the Music library, or nil if cancelled.
struct MusicPickerView: UIViewControllerRepresentable {
    let onFinish: (MPMediaItem?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let onFinish: (MPMediaItem?) -> Void

        init(onFinish: @escaping (MPMediaItem?) -> Void) {
            self.onFinish = onFinish
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            onFinish(mediaItemCollection.items.first)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            onFinish(nil)
        }
    }
}
