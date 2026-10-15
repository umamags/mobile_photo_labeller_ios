import AVFoundation
import MediaPlayer
import UniformTypeIdentifiers

/// Audio files the app can use. They live in Documents/Audio, which the Files app shows
/// under "On My iPhone › Photo Labeller", so they can be copied in or out there.
enum AudioStore {
    struct File: Identifiable {
        /// Path inside the audio folder, for example "Coldplay/Yellow.mp3".
        let relativePath: String
        let name: String
        /// Subfolder inside the audio folder, or "" for files at the top level.
        let folder: String

        var id: String { relativePath }
    }

    enum StoreError: LocalizedError {
        case protectedItem
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .protectedItem: "This song is protected and can't be used. Choose another song."
            case .failed(let reason): reason
            }
        }
    }

    static var root: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Audio", isDirectory: true)
    }

    static func url(for relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    /// Every audio file under the audio folder, including subfolders, sorted by path.
    static func files() -> [File] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [File] = []
        for case let url as URL in enumerator {
            guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .audio) else { continue }
            let parts = url.standardizedFileURL.pathComponents.dropFirst(root.standardizedFileURL.pathComponents.count)
            let relativePath = parts.joined(separator: "/")
            files.append(File(
                relativePath: relativePath,
                name: url.deletingPathExtension().lastPathComponent,
                folder: parts.dropLast().joined(separator: "/")
            ))
        }
        return files.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    /// The name to show for a file, without its folder or extension.
    static func displayName(for relativePath: String) -> String {
        ((relativePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    /// Copies a Music library song into the audio folder as an M4A file.
    static func importLibraryItem(_ item: MPMediaItem) async throws -> String {
        guard let assetURL = item.assetURL else { throw StoreError.protectedItem }
        let title = (item.title ?? "Song").replacingOccurrences(of: "/", with: "-")
        let relativePath = "Imported/\(title) \(UUID().uuidString.prefix(6)).m4a"
        let destination = url(for: relativePath)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        guard let exporter = AVAssetExportSession(asset: AVURLAsset(url: assetURL),
                                                  presetName: AVAssetExportPresetAppleM4A) else {
            throw StoreError.failed("This song can't be exported.")
        }
        exporter.outputURL = destination
        exporter.outputFileType = .m4a
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exporter.exportAsynchronously {
                if exporter.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: StoreError.failed(exporter.error?.localizedDescription ?? "The song could not be copied."))
                }
            }
        }
        return relativePath
    }

    /// A new file in Recordings for a recording to be written to.
    static func newRecordingURL() throws -> (url: URL, relativePath: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let relativePath = "Recordings/Recording \(formatter.string(from: Date())).m4a"
        let url = url(for: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (url, relativePath)
    }
}
