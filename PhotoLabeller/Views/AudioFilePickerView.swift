import SwiftUI

/// Lists the audio files in the audio folder, including subfolders, grouped by folder.
struct AudioFilePickerView: View {
    let onPick: (AudioStore.File) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var files: [AudioStore.File] = []

    var body: some View {
        NavigationStack {
            List {
                if files.isEmpty {
                    ContentUnavailableView(
                        "No audio files",
                        systemImage: "waveform",
                        description: Text("Copy audio files into Photo Labeller › Audio in the Files app, under On My iPhone.")
                    )
                }
                ForEach(groups) { group in
                    Section(group.folder.isEmpty ? "Audio" : group.folder) {
                        ForEach(group.files) { file in
                            Button {
                                onPick(file)
                                dismiss()
                            } label: {
                                Text(file.name)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Audio files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { files = AudioStore.files() }
        }
    }

    private var groups: [FolderGroup] {
        Dictionary(grouping: files, by: \.folder)
            .map { FolderGroup(folder: $0.key, files: $0.value) }
            .sorted { $0.folder.localizedStandardCompare($1.folder) == .orderedAscending }
    }
}

private struct FolderGroup: Identifiable {
    let folder: String
    let files: [AudioStore.File]

    var id: String { folder }
}
