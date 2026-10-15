import Foundation

/// How background audio combines with the video's own sound.
enum AudioMode: String, Codable, CaseIterable, Identifiable {
    /// The background audio replaces the video's sound.
    case replace
    /// The background audio plays under the video's sound.
    case mix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replace: "Replace"
        case .mix: "Mix"
        }
    }
}

/// The background audio for a project. The file itself lives in `AudioStore`.
struct BackgroundAudio: Codable, Equatable {
    /// Path inside the audio folder, for example "Coldplay/Yellow.mp3".
    var relativePath: String
    var name: String
    var label: String
    var mode: AudioMode
    /// Background level when mixing, from 0 to 1. Replace always plays at full level.
    var volume: Float
}
