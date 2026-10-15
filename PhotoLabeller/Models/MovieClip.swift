import Foundation

/// One photo or video in a movie. The media itself stays in the Photos library and is
/// found again by `assetID`, which is what lets a saved project be reopened.
struct MovieClip: Identifiable, Codable, Equatable {
    /// The Photos library identifier.
    let assetID: String
    let isVideo: Bool
    var label: String

    var id: String { assetID }
}
