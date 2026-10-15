import Photos
import SwiftUI

struct MovieMakerView: View {
    let onHome: () -> Void

    @State private var clips: [MovieClip] = []
    @State private var lagSeconds = 3
    /// The saved project these clips came from, if any. Save updates it.
    @State private var project: MovieProject?
    /// The last movie built and saved, so Share can reuse it while nothing has changed.
    @State private var lastBuild: BuildRecord?

    @State private var isWorking = false
    @State private var alertText: String?
    @State private var shareItem: ShareItem?
    @State private var showGallery = false
    @State private var showProjects = false
    @State private var showProjectNameAlert = false
    @State private var projectNameDraft = ""
    @State private var labelEditing: LabelEditTarget?

    var body: some View {
        List {
            Section {
                Button {
                    showGallery = true
                } label: {
                    Label(clips.isEmpty ? "Choose photos and videos" : "Change selection",
                          systemImage: "photo.stack")
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                if clips.isEmpty {
                    Text("Nothing selected yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(clips) { clip in
                    Button {
                        labelEditing = LabelEditTarget(assetID: clip.assetID, label: clip.label)
                    } label: {
                        clipRow(clip)
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: moveClips)
                .onDelete(perform: deleteClips)
            } header: {
                Text("Order")
            } footer: {
                Text("Tap a clip to add a label. Tap Edit to drag clips into order or remove them.")
            }

            Section {
                Picker("Time per photo", selection: $lagSeconds) {
                    ForEach(1...5, id: \.self) { seconds in
                        Text("\(seconds) s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Each photo stays on screen for this long. Videos play in full.")
            }

            Section {
                if let project {
                    Text("Open project: \(project.name)")
                        .foregroundStyle(.secondary)
                }
                Button(action: saveProjectTapped) {
                    Label("Save Project", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    showProjects = true
                } label: {
                    Label("Open Project", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
            } header: {
                Text("Project")
            }
            .disabled(isWorking)

            Section {
                Button(action: createVideo) {
                    Label("Create Video", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                Button(action: share) {
                    Label("Share (WhatsApp, Google Drive…)", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Create Video saves the movie to your Photos library. Share saves it too, if it isn't saved yet.")
            }
            .disabled(clips.isEmpty || isWorking)
        }
        .navigationTitle("Create Video")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !clips.isEmpty {
                    EditButton()
                }
                Button(action: onHome) {
                    Label("Home", systemImage: "house")
                }
            }
        }
        .sheet(isPresented: $showGallery) {
            MediaGalleryView(initialSelection: clips.map(\.assetID), onDone: applySelection)
        }
        .sheet(isPresented: $showProjects) {
            ProjectListView(onOpen: openProject)
        }
        .sheet(item: $labelEditing) { target in
            LabelEditorView(initialText: target.label) { text in
                setLabel(text, for: target.assetID)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
        .alert("Save Project", isPresented: $showProjectNameAlert) {
            TextField("Project name", text: $projectNameDraft)
            Button("Save") { saveProject(named: projectNameDraft) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name this set of photos and videos.")
        }
        .alert("Create Video", isPresented: Binding(
            get: { alertText != nil },
            set: { if !$0 { alertText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertText ?? "")
        }
        .overlay {
            if isWorking {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Creating video…")
                        .font(.footnote)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func clipRow(_ clip: MovieClip) -> some View {
        HStack(spacing: 12) {
            AssetThumbnail(assetID: clip.assetID, pixelSide: 168)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.isVideo ? "Video" : "Photo")
                Text(clip.label.isEmpty ? "Tap to add a label" : clip.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if clip.isVideo {
                Image(systemName: "play.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Selection and labels

    /// Takes the gallery's choice and its order. Items that were already chosen keep their labels.
    private func applySelection(_ assets: [PHAsset]) {
        let existing = Dictionary(clips.map { ($0.assetID, $0) }, uniquingKeysWith: { first, _ in first })
        clips = assets.map { asset in
            existing[asset.localIdentifier] ?? MovieClip(
                assetID: asset.localIdentifier,
                isVideo: asset.mediaType == .video,
                label: ""
            )
        }
    }

    private func setLabel(_ text: String, for assetID: String) {
        guard let index = clips.firstIndex(where: { $0.assetID == assetID }) else { return }
        clips[index].label = text
    }

    private func moveClips(from offsets: IndexSet, to destination: Int) {
        clips.move(fromOffsets: offsets, toOffset: destination)
    }

    private func deleteClips(at offsets: IndexSet) {
        clips.remove(atOffsets: offsets)
    }

    // MARK: - Projects

    private func saveProjectTapped() {
        if let project {
            saveProject(named: project.name)
        } else {
            projectNameDraft = ""
            showProjectNameAlert = true
        }
    }

    private func saveProject(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertText = "Enter a name for the project."
            return
        }
        var updated = project ?? MovieProject(name: trimmed, lagSeconds: lagSeconds, clips: clips)
        updated.name = trimmed
        updated.lagSeconds = lagSeconds
        updated.clips = clips
        updated.updatedAt = Date()
        do {
            try ProjectStore.save(updated)
            project = updated
            alertText = "Saved “\(trimmed)”."
        } catch {
            alertText = "Could not save the project: \(error.localizedDescription)"
        }
    }

    private func openProject(_ opened: MovieProject) {
        project = opened
        clips = opened.clips
        lagSeconds = opened.lagSeconds
    }

    // MARK: - Building and sharing

    private func createVideo() {
        Task {
            if await buildAndSave() != nil {
                alertText = "The video is saved in your Photos library."
            }
        }
    }

    /// Shares the last saved video if nothing has changed since it was built. Otherwise builds and saves a new one first.
    private func share() {
        Task {
            if let lastBuild, lastBuild.signature == signature {
                shareItem = ShareItem(url: lastBuild.url)
            } else if let url = await buildAndSave() {
                shareItem = ShareItem(url: url)
            }
        }
    }

    /// Builds the movie, saves it to Photos and remembers it for Share.
    private func buildAndSave() async -> URL? {
        let current = signature
        isWorking = true
        defer { isWorking = false }
        do {
            let inputs = try await buildInputs()
            let url = try await MovieBuilder.build(clips: inputs, lagSeconds: lagSeconds)
            try await PhotoSaver.saveVideo(at: url)
            if let previous = lastBuild?.url {
                try? FileManager.default.removeItem(at: previous)
            }
            lastBuild = BuildRecord(signature: current, url: url)
            return url
        } catch {
            alertText = "Could not create the video: \(error.localizedDescription)"
            return nil
        }
    }

    /// Loads each clip's media from the Photos library, in order.
    private func buildInputs() async throws -> [MovieBuilder.Clip] {
        var inputs: [MovieBuilder.Clip] = []
        for clip in clips {
            guard let asset = PhotoLibrary.asset(withID: clip.assetID) else {
                throw InputError.missing
            }
            if clip.isVideo {
                guard let video = await PhotoLibrary.videoAsset(for: asset) else { throw InputError.unavailable }
                inputs.append(MovieBuilder.Clip(source: .video(video), label: clip.label))
            } else {
                guard let photo = await PhotoLibrary.photo(for: asset, pixelSide: 1920) else {
                    throw InputError.unavailable
                }
                inputs.append(MovieBuilder.Clip(source: .photo(photo), label: clip.label))
            }
        }
        return inputs
    }

    /// Describes the current clips, labels and lag. A saved movie is reused only while this matches.
    private var signature: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(MovieInput(clips: clips, lagSeconds: lagSeconds))) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}

private struct BuildRecord {
    let signature: String
    let url: URL
}

private struct MovieInput: Encodable {
    let clips: [MovieClip]
    let lagSeconds: Int
}

private struct LabelEditTarget: Identifiable {
    let assetID: String
    let label: String

    var id: String { assetID }
}

private enum InputError: LocalizedError {
    case missing
    case unavailable

    var errorDescription: String? {
        switch self {
        case .missing: "One of the photos or videos is no longer in your library."
        case .unavailable: "Could not load one of the photos or videos. Check your connection if it is stored in iCloud."
        }
    }
}
