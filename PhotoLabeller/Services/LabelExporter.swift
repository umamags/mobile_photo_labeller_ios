import SwiftUI

enum LabelExporter {
    /// Renders the photo with the label at the photo's original pixel resolution.
    @MainActor
    static func render(image: UIImage, label: TextLabel) -> UIImage? {
        let canvas = LabelCanvas(image: image, label: label, size: image.size)
        let renderer = ImageRenderer(content: canvas)
        // Points x scale = pixels, so the output matches the original photo's size.
        renderer.scale = image.scale
        return renderer.uiImage
    }
}
