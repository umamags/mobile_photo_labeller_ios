import SwiftUI

struct HomeView: View {
    let onOpenPhotoLabeller: () -> Void
    let onCreateMovie: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Text("Welcome to my utils")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 36) {
                HomeTile(
                    title: "Photo Labeller",
                    systemImage: "text.below.photo",
                    colors: [.blue, .indigo],
                    action: onOpenPhotoLabeller
                )
                HomeTile(
                    title: "Create Video",
                    systemImage: "film",
                    colors: [.orange, .pink],
                    action: onCreateMovie
                )
            }
        }
        .padding()
        .frame(maxWidth: 420)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A tappable app icon: a coloured rounded tile with a symbol, and its name underneath.
private struct HomeTile: View {
    let title: String
    let systemImage: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .shadow(color: (colors.first ?? .blue).opacity(0.3), radius: 6, y: 3)

                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 110)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
