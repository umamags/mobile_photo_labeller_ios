import Foundation

/// A saved set of photos and videos, with their order, labels and time per photo.
struct MovieProject: Identifiable, Codable {
    var id = UUID()
    var name: String
    var lagSeconds: Int
    var clips: [MovieClip]
    /// Optional, so projects saved before background audio existed still open.
    var audio: BackgroundAudio? = nil
    var updatedAt = Date()
}
