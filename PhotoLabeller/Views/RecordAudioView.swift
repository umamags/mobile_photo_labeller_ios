import AVFoundation
import SwiftUI

/// Records audio into Recordings in the audio folder. "Use Recording" makes it the project's background audio.
struct RecordAudioView: View {
    let onDone: (BackgroundAudio) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder: AVAudioRecorder?
    @State private var recordedPath: String?
    @State private var elapsed: TimeInterval = 0
    @State private var isRecording = false
    @State private var errorText: String?

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Text(timeText)
                    .font(.system(size: 56, weight: .light).monospacedDigit())

                Button(action: isRecording ? stop : start) {
                    Image(systemName: isRecording ? "stop.fill" : "circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(Circle().fill(.red))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRecording ? "Stop" : "Record")

                if recordedPath != nil && !isRecording {
                    Text("Recording saved. Use it as the background audio, or discard it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .navigationTitle("Record audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        discard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Recording") {
                        guard let recordedPath else { return }
                        onDone(BackgroundAudio(
                            relativePath: recordedPath,
                            name: AudioStore.displayName(for: recordedPath),
                            label: "",
                            mode: .mix,
                            volume: 0.6
                        ))
                        dismiss()
                    }
                    .disabled(recordedPath == nil || isRecording)
                }
            }
            .onReceive(ticker) { _ in
                if let recorder, recorder.isRecording {
                    elapsed = recorder.currentTime
                }
            }
        }
    }

    private var timeText: String {
        let seconds = Int(elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func start() {
        Task {
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard granted else {
                errorText = "Allow microphone access in Settings → Photo Labeller to record."
                return
            }
            do {
                // A new recording replaces any earlier take that hasn't been used yet.
                discard()
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default)
                try session.setActive(true)

                let target = try AudioStore.newRecordingURL()
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                let newRecorder = try AVAudioRecorder(url: target.url, settings: settings)
                guard newRecorder.record() else {
                    errorText = "Could not start recording."
                    return
                }
                recorder = newRecorder
                recordedPath = target.relativePath
                elapsed = 0
                isRecording = true
                errorText = nil
            } catch {
                errorText = "Could not start recording: \(error.localizedDescription)"
            }
        }
    }

    private func stop() {
        recorder?.stop()
        if let recorder {
            elapsed = recorder.currentTime
        }
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Deletes the current take, if any.
    private func discard() {
        if isRecording { stop() }
        if let recordedPath {
            try? FileManager.default.removeItem(at: AudioStore.url(for: recordedPath))
        }
        recorder = nil
        recordedPath = nil
        elapsed = 0
    }
}
