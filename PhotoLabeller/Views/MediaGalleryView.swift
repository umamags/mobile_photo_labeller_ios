import Photos
import SwiftUI

/// A grid of the photo library for choosing photos and videos. Tap to select; the number
/// on each selected item is its position in the movie.
struct MediaGalleryView: View {
    let initialSelection: [String]
    let onDone: ([PHAsset]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var assets: [PHAsset] = []
    @State private var selectedIDs: [String]
    @State private var accessDenied = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    init(initialSelection: [String], onDone: @escaping ([PHAsset]) -> Void) {
        self.initialSelection = initialSelection
        self.onDone = onDone
        _selectedIDs = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            Group {
                if accessDenied {
                    ContentUnavailableView(
                        "No access to Photos",
                        systemImage: "lock",
                        description: Text("Allow access to Photos in Settings → Photo Labeller.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                GalleryCell(
                                    asset: asset,
                                    order: selectedIDs.firstIndex(of: asset.localIdentifier).map { $0 + 1 }
                                )
                                .onTapGesture { toggle(asset.localIdentifier) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let byID = Dictionary(assets.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
                        onDone(selectedIDs.compactMap { byID[$0] })
                        dismiss()
                    }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            try await PhotoLibrary.requestAccess()
            assets = PhotoLibrary.fetchMedia()
        } catch {
            accessDenied = true
        }
    }

    private func toggle(_ id: String) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }
}

private struct GalleryCell: View {
    let asset: PHAsset
    /// Position in the movie, or nil when not selected.
    let order: Int?

    var body: some View {
        // A square cell sets the size; the thumbnail is an overlay so its own size can't stretch the grid.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AssetThumbnail(assetID: asset.localIdentifier, pixelSide: 300)
            }
            .clipped()
            .overlay {
                if order != nil {
                    Color.black.opacity(0.25)
                }
            }
            .overlay(alignment: .topTrailing) {
                selectionBadge
                    .padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                if asset.mediaType == .video {
                    Text(durationText)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(4)
                }
            }
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if let order {
            Text("\(order)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
        } else {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
    }

    private var durationText: String {
        let seconds = Int(asset.duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
