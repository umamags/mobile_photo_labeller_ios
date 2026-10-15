import PhotosUI
import SwiftUI

struct EditorView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var label = TextLabel()
    @State private var isWorking = false
    @State private var alertText: String?
    @State private var shareItem: ShareItem?

    let onHome: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(photo == nil ? "Choose photo" : "Choose another photo",
                          systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let photo {
                    canvas(for: photo)
                    Text("Drag the label to move it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabelControls(label: $label)
                    actionButtons
                } else {
                    ContentUnavailableView(
                        "No photo selected",
                        systemImage: "photo",
                        description: Text("Pick a photo from your library to start labelling.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Photo Labeller")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onHome) {
                    Label("Home", systemImage: "house")
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            loadPhoto(from: newItem)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
        .alert("Photo Labeller", isPresented: Binding(
            get: { alertText != nil },
            set: { if !$0 { alertText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertText ?? "")
        }
        .overlay {
            if isWorking {
                ProgressView()
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    /// Keeps the photo's aspect ratio and lays the label over it.
    private func canvas(for photo: UIImage) -> some View {
        Color.clear
            .aspectRatio(photo.size, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    LabelCanvas(image: photo, label: label, size: geometry.size) { position in
                        label.position = position
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveToPhotos) {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: share) {
                Label("Share (WhatsApp, Google Drive…)", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .disabled(isWorking)
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    alertText = "Could not read that photo. Please try another one."
                    return
                }
                photo = image
            } catch {
                alertText = "Could not load that photo: \(error.localizedDescription)"
            }
        }
    }

    private func saveToPhotos() {
        guard let photo, let output = LabelExporter.render(image: photo, label: label) else {
            alertText = "Could not create the labelled image."
            return
        }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                try await PhotoSaver.save(output)
                alertText = "The labelled photo is in your Photos library."
            } catch {
                alertText = error.localizedDescription
            }
        }
    }

    private func share() {
        guard let photo, let output = LabelExporter.render(image: photo, label: label),
              let data = output.pngData() else {
            alertText = "Could not create the labelled image."
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("labelled-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            shareItem = ShareItem(url: url)
        } catch {
            alertText = "Could not prepare the image for sharing: \(error.localizedDescription)"
        }
    }
}
