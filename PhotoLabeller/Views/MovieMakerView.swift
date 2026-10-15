import AVFoundation
import MediaPlayer
import Photos
import SwiftUI

struct MovieMakerView: View {
    let onHome: () -> Void

    @State private var clips: [MovieClip] = []
    @State private var lagSeconds = 3
    /// Background audio, shown at the top of the list. Nil when the project has none.
    @State private var background: BackgroundAudio?
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
    @State private var showMusicPicker = false
    @State private var showAudioFiles = false
    @State private var showRecorder = false

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
                if let background {
                    Button {
                        labelEditing = LabelEditTarget(kind: .audio, label: background.label)
                    } label: {
                        audioRow(background)
                    }
                    .buttonStyle(.plain)
                }
                if clips.isEmpty && background == nil {
                    Text("Nothing selected yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(clips) { clip in
                    Button {
                        labelEditing = LabelEditTarget(kind: .clip(clip.assetID), label: clip.label)
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
                Text("Tap a clip or the audio to add a label. Tap Edit to drag clips into order or remove them. The audio stays at the top.")
            }

            Section {
                Menu {
                    Button { chooseFromMusicLibrary() } label: {
                        Label("Music library", systemImage: "music.note")
                    }
                    Button { showAudioFiles = true } label: {
                        Label("Audio files", systemImage: "folder")
                    }
                    Button { showRecorder = true } label: {
                        Label("Record", systemImage: "mic")
                    }
                } label: {
                    Label(background == nil ? "Add background audio" : "Change background audio",
                          systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }

                if background != nil {
                    Picker("Audio mode", selection: modeBinding) {
                        ForEach(AudioMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if background?.mode == .mix {
                        HStack {
                            Text("Background")
                            Slider(value: volumeBinding, in: 0.1...1)
                            Text("\(Int((background?.volume ?? 0) * 100))%")
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                    }

                    Button(role: .destructive) {
                        background = nil
                    } label: {
                        Label("Remove audio", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            } header: {
                Text("Background audio")
            } footer: {
                Text("Replace plays this audio instead of the videos' sound. Mix plays it under their sound. The audio is cut to the movie's length and fades out over its last 2 seconds.")
            }
            .disabled(isWorking)

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
        .sheet(isPresented: $showMusicPicker) {
            MusicPickerView { item in
                showMusicPicker = false
                importMusic(item)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showAudioFiles) {
            AudioFilePickerView { file in
                background = BackgroundAudio(relativePath: file.relativePath,
                                             name: file.name,
                                             label: "",
                                             mode: .mix,
                                             volume: 0.6)
            }
        }
        .sheet(isPresented: $showRecorder) {
            RecordAudioView { audio in
                background = audio
            }
        }
        .sheet(item: $labelEditing) { target in
            LabelEditorView(initialText: target.label) { text in
                setLabel(text, for: target.kind)
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
            Text("Name this set of photos, videos and audio.")
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

    private func audioRow(_ audio: BackgroundAudio) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(audio.name)
                    .lineLimit(1)
                Text(audio.label.isEmpty ? "Tap to add a label" : audio.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(audio.mode.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
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

    // MARK: - Bindings

    private var modeBinding: Binding<AudioMode> {
        Binding(
            get: { background?.mode ?? .mix },
            set: { mode in updateBackground { $0.mode = mode } }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(background?.volume ?? 0.6) },
            set: { volume in updateBackground { $0.volume = Float(volume) } }
        )
    }

    private func updateBackground(_ change: (inout BackgroundAudio) -> Void) {
        guard var audio = background else { return }
        change(&audio)
        background = audio
    }

    // MARK: - Selection, labels and audio

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

    private func setLabel(_ text: String, for kind: LabelEditTarget.Kind) {
        switch kind {
        case .audio:
            updateBackground { $0.label = text }
        case .clip(let assetID):
            guard let index = clips.firstIndex(where: { $0.assetID == assetID }) else { return }
            clips[index].label = text
        }
    }

    private func moveClips(from offsets: IndexSet, to destination: Int) {
        clips.move(fromOffsets: offsets, toOffset: destination)
    }

    private func deleteClips(at offsets: IndexSet) {
        clips.remove(atOffsets: offsets)
    }

    /// Asks for Music library access, then opens the Music picker.
    private func chooseFromMusicLibrary() {
        Task {
            let status = await MPMediaLibrary.requestAuthorization()
            guard status == .authorized else {
                alertText = "Allow Media & Apple Music access in Settings → Photo Labeller to choose songs."
                return
            }
            showMusicPicker = true
        }
    }

    private func importMusic(_ item: MPMediaItem?) {
        guard let item else { return }
        Task {
            do {
                let path = try await AudioStore.importLibraryItem(item)
                background = BackgroundAudio(relativePath: path,
                                             name: item.title ?? AudioStore.displayName(for: path),
                                             label: "",
                                             mode: .mix,
                                             volume: 0.6)
            } catch {
                alertText = error.localizedDescription
            }
        }
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
        updated.audio = background
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
        background = opened.audio
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
            let url = try await MovieBuilder.build(clips: inputs, lagSeconds: lagSeconds, background: try backgroundInput())
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

    private func backgroundInput() throws -> MovieBuilder.Background? {
        guard let background else { return nil }
        let url = AudioStore.url(for: background.relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { throw InputError.missingAudio }
        return MovieBuilder.Background(url: url, mode: background.mode, volume: background.volume)
    }

    /// Describes the current clips, labels, audio and lag. A saved movie is reused only while this matches.
    private var signature: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(MovieInput(clips: clips, lagSeconds: lagSeconds, background: background))) ?? Data()
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
    let background: BackgroundAudio?
}

private struct LabelEditTarget: Identifiable {
    enum Kind: Equatable {
        case clip(String)
        case audio
    }

    let kind: Kind
    let label: String

    var id: String {
        switch kind {
        case .clip(let assetID): assetID
        case .audio: "background-audio"
        }
    }
}

private enum InputError: LocalizedError {
    case missing
    case unavailable
    case missingAudio

    var errorDescription: String? {
        switch self {
        case .missing: "One of the photos or videos is no longer in your library."
        case .unavailable: "Could not load one of the photos or videos. Check your connection if it is stored in iCloud."
        case .missingAudio: "The background audio file is missing. Choose the audio again."
        }
    }
}
