import SwiftUI

/// Draws the photo with the text label on top.
///
/// Used both for the interactive preview (with drag support) and for the
/// export render, so the exported image looks exactly like the preview.
struct LabelCanvas: View {
    let image: UIImage
    let label: TextLabel
    let size: CGSize
    var onMove: (CGPoint) -> Void = { _ in }

    @State private var dragOrigin: CGPoint?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .frame(width: size.width, height: size.height)

            LabelBadge(label: label, canvasWidth: size.width)
                .offset(x: label.position.x * size.width, y: label.position.y * size.height)
                .gesture(dragGesture)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let origin = dragOrigin ?? label.position
                dragOrigin = origin
                onMove(
                    CGPoint(
                        x: clamp(origin.x + value.translation.width / size.width),
                        y: clamp(origin.y + value.translation.height / size.height)
                    )
                )
            }
            .onEnded { _ in
                dragOrigin = nil
            }
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

/// The styled text box itself.
struct LabelBadge: View {
    let label: TextLabel
    let canvasWidth: CGFloat

    var body: some View {
        let fontSize = label.sizeRatio * canvasWidth

        Text(label.text.isEmpty ? " " : label.text)
            .font(label.font.font(size: fontSize))
            .foregroundStyle(label.textColor.color)
            .padding(.horizontal, fontSize * 0.3)
            .padding(.vertical, fontSize * 0.15)
            .background(label.background.color ?? .clear, in: RoundedRectangle(cornerRadius: fontSize * 0.2))
    }
}
