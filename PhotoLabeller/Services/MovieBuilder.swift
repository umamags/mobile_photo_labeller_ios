import AVFoundation
import UIKit

/// Stitches photos and videos into one MP4 at 1080×1920 with hard cuts between clips.
/// A clip's label is drawn over it for the whole time the clip is on screen.
enum MovieBuilder {
    static let outputSize = CGSize(width: 1080, height: 1920)
    static let frameRate: Int32 = 30

    enum Source {
        case photo(UIImage)
        case video(AVAsset)
    }

    struct Clip {
        let source: Source
        let label: String
    }

    enum BuildError: LocalizedError {
        case noClips
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noClips: "Choose at least one photo or video."
            case .failed(let reason): reason
            }
        }
    }

    /// Background audio for the movie.
    struct Background {
        let url: URL
        let mode: AudioMode
        let volume: Float
    }

    /// A label and the time range it is shown for.
    private struct Overlay {
        let image: CGImage
        let range: CMTimeRange
    }

    /// Each photo is shown for `lagSeconds`. Each video plays in full, with its sound.
    /// Background audio, if any, is cut to the movie's length and fades out at the end.
    static func build(clips: [Clip], lagSeconds: Int, background: Background? = nil) async throws -> URL {
        guard !clips.isEmpty else { throw BuildError.noClips }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw BuildError.failed("Could not create the movie tracks.")
        }
        // Created only when a video with sound is added. An empty audio track makes export fail for photo-only movies.
        var audioTrack: AVMutableCompositionTrack?

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let photoDuration = CMTime(seconds: Double(lagSeconds), preferredTimescale: 600)
        var cursor = CMTime.zero
        var overlays: [Overlay] = []

        for clip in clips {
            let asset: AVAsset
            let duration: CMTime
            switch clip.source {
            case .photo(let image):
                asset = AVURLAsset(url: try await writePhotoClip(image, duration: photoDuration))
                duration = photoDuration
            case .video(let video):
                asset = video
                duration = try await video.load(.duration)
            }

            guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else { continue }
            let range = CMTimeRange(start: .zero, duration: duration)
            try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)
            // In replace mode the video's own sound is left out.
            if background?.mode != .replace, let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                if audioTrack == nil {
                    audioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                             preferredTrackID: kCMPersistentTrackID_Invalid)
                }
                try audioTrack?.insertTimeRange(range, of: sourceAudio, at: cursor)
            }

            let naturalSize = try await sourceVideo.load(.naturalSize)
            let preferredTransform = try await sourceVideo.load(.preferredTransform)
            layer.setTransform(fitTransform(natural: naturalSize, preferred: preferredTransform), at: cursor)

            let text = clip.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, let image = labelImage(text) {
                overlays.append(Overlay(image: image, range: CMTimeRange(start: cursor, duration: duration)))
            }
            cursor = cursor + duration
        }

        guard cursor > .zero else { throw BuildError.noClips }

        // Background audio starts at the beginning and is cut to the movie's length.
        if let background, let musicTrack = composition.addMutableTrack(withMediaType: .audio,
                                                                        preferredTrackID: kCMPersistentTrackID_Invalid) {
            let musicAsset = AVURLAsset(url: background.url)
            let musicLength = min(try await musicAsset.load(.duration), cursor)
            // Replace plays the audio at full level; mix uses the chosen background level.
            let level = background.mode == .replace ? 1 : background.volume
            let prepared = AVURLAsset(url: try prepareMusic(background.url, length: musicLength.seconds, level: level))
            guard let preparedTrack = try await prepared.loadTracks(withMediaType: .audio).first else {
                throw BuildError.failed("Could not prepare the background audio.")
            }
            try musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: musicLength), of: preparedTrack, at: .zero)
        }

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: cursor)
        instruction.layerInstructions = [layer]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = outputSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: frameRate)
        videoComposition.instructions = [instruction]

        return try await render(composition, videoComposition: videoComposition, overlays: overlays)
    }

    /// Writes the background audio to a temporary M4A file, cut to `length`, at `level`, and faded
    /// out over the last 2 seconds. The gain is applied to each sample directly.
    private static func prepareMusic(_ source: URL, length: Double, level: Float) throws -> URL {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let sampleRate = format.sampleRate
        let channels = Int(format.channelCount)
        let output = try AVAudioFile(
            forWriting: temporaryURL(extension: "m4a"),
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: 192_000
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        let totalFrames = min(input.length, AVAudioFramePosition(length * sampleRate))
        let fadeStart = max(0, length - 2)
        let chunkSize: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize),
              let channelData = buffer.floatChannelData else {
            throw BuildError.failed("Could not read the background audio.")
        }

        var written: AVAudioFramePosition = 0
        while written < totalFrames {
            let wanted = AVAudioFrameCount(min(AVAudioFramePosition(chunkSize), totalFrames - written))
            try input.read(into: buffer, frameCount: wanted)
            let count = Int(buffer.frameLength)
            guard count > 0 else { break }

            for frame in 0..<count {
                let time = Double(written) + Double(frame)
                let seconds = time / sampleRate
                var gain = level
                if seconds > fadeStart {
                    gain *= Float(max(0, 1 - (seconds - fadeStart) / 2))
                }
                for channel in 0..<channels {
                    channelData[channel][frame] *= gain
                }
            }
            try output.write(from: buffer)
            written += AVAudioFramePosition(count)
        }
        return output.url
    }

    /// Maps a source video onto the output frame, keeping its shape and centring it with black bars.
    private static func fitTransform(natural: CGSize, preferred: CGAffineTransform) -> CGAffineTransform {
        let displayRect = CGRect(origin: .zero, size: natural).applying(preferred)
        let scale = min(outputSize.width / displayRect.width, outputSize.height / displayRect.height)
        let x = (outputSize.width - displayRect.width * scale) / 2
        let y = (outputSize.height - displayRect.height * scale) / 2
        return preferred
            .concatenating(CGAffineTransform(translationX: -displayRect.minX, y: -displayRect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: x, y: y))
    }

    /// The label drawn as white text on a dark rounded box, sized to fit its text.
    private static func labelImage(_ text: String) -> CGImage? {
        let boxWidth = outputSize.width - 120
        let textWidth = boxWidth - 40
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 52, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let textHeight = ceil((text as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        ).height)
        let size = CGSize(width: boxWidth, height: textHeight + 40)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.black.withAlphaComponent(0.55).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16).fill()
            (text as NSString).draw(
                with: CGRect(x: 20, y: 20, width: textWidth, height: textHeight),
                options: [.usesLineFragmentOrigin],
                attributes: attributes,
                context: nil
            )
        }
        return image.cgImage
    }

    /// Writes a still photo as a video of the given length, so it can join the other clips.
    private static func writePhotoClip(_ image: UIImage, duration: CMTime) async throws -> URL {
        let url = temporaryURL(extension: "mp4")
        let width = Int(outputSize.width)
        let height = Int(outputSize.height)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        guard writer.startWriting() else {
            throw BuildError.failed(writer.error?.localizedDescription ?? "Could not start writing the movie.")
        }
        writer.startSession(atSourceTime: .zero)

        // Every frame is the same picture, so one buffer is reused for all of them.
        let buffer = try pixelBuffer(for: image, width: width, height: height)
        let frameCount = Int64((duration.seconds * Double(frameRate)).rounded())
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: frame, timescale: frameRate)) else {
                throw BuildError.failed(writer.error?.localizedDescription ?? "Could not write a photo frame.")
            }
        }

        writer.endSession(atSourceTime: CMTime(value: frameCount, timescale: frameRate))
        input.markAsFinished()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.finishWriting {
                if writer.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: BuildError.failed(writer.error?.localizedDescription ?? "Could not finish the photo clip."))
                }
            }
        }
        return url
    }

    /// Draws the image centred on a black frame of the output size.
    private static func pixelBuffer(for image: UIImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        guard status == kCVReturnSuccess, let buffer else {
            throw BuildError.failed("Could not create a video frame.")
        }
        guard let cgImage = image.cgImage else {
            throw BuildError.failed("Could not read one of the photos.")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = bitmapContext(for: buffer) else {
            throw BuildError.failed("Could not draw a video frame.")
        }

        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(frame)

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let scale = min(frame.width / imageWidth, frame.height / imageHeight)
        let drawSize = CGSize(width: imageWidth * scale, height: imageHeight * scale)
        let drawRect = CGRect(
            x: (frame.width - drawSize.width) / 2,
            y: (frame.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        context.draw(cgImage, in: drawRect)
        return buffer
    }

    /// A drawing context over a 32-bit BGRA pixel buffer that is already locked.
    private static func bitmapContext(for buffer: CVPixelBuffer) -> CGContext? {
        CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
    }

    /// Draws the overlays that are on screen at this frame's time, straight into the frame.
    private static func drawOverlays(_ overlays: [Overlay], on sample: CMSampleBuffer) {
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        let active = overlays.filter { $0.range.containsTime(time) }
        guard !active.isEmpty, let buffer = CMSampleBufferGetImageBuffer(sample) else { return }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = bitmapContext(for: buffer) else { return }
        for overlay in active {
            // Bottom-left origin, so y is measured up from the bottom of the frame.
            context.draw(overlay.image, in: CGRect(x: 60, y: 140,
                                                   width: overlay.image.width,
                                                   height: overlay.image.height))
        }
    }

    /// Reads the composed movie frame by frame, draws the labels, and writes the MP4 with its sound.
    private static func render(_ composition: AVMutableComposition,
                               videoComposition: AVMutableVideoComposition,
                               overlays: [Overlay]) async throws -> URL {
        let url = temporaryURL(extension: "mp4")
        let reader = try AVAssetReader(asset: composition)

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: try await composition.loadTracks(withMediaType: .video),
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        videoOutput.videoComposition = videoComposition
        reader.add(videoOutput)

        // The audio mix output combines all audio tracks, with the background level and fade applied.
        var audioOutput: AVAssetReaderAudioMixOutput?
        let audioTracks = try await composition.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            let output = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ])
            reader.add(output)
            audioOutput = output
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 128_000
            ])
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioInput = input
        }

        guard reader.startReading(), writer.startWriting() else {
            throw BuildError.failed(reader.error?.localizedDescription ?? writer.error?.localizedDescription ?? "Could not start the export.")
        }
        writer.startSession(atSourceTime: .zero)

        // Video and audio are written on their own queues, so neither waits for the other.
        let group = DispatchGroup()
        let videoQueue = DispatchQueue(label: "movie.video")
        group.enter()
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
            while videoInput.isReadyForMoreMediaData {
                guard let sample = videoOutput.copyNextSampleBuffer() else {
                    videoInput.markAsFinished()
                    group.leave()
                    return
                }
                drawOverlays(overlays, on: sample)
                videoInput.append(sample)
            }
        }

        if let audioOutput, let audioInput {
            let audioQueue = DispatchQueue(label: "movie.audio")
            group.enter()
            audioInput.requestMediaDataWhenReady(on: audioQueue) {
                while audioInput.isReadyForMoreMediaData {
                    guard let sample = audioOutput.copyNextSampleBuffer() else {
                        audioInput.markAsFinished()
                        group.leave()
                        return
                    }
                    audioInput.append(sample)
                }
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            group.notify(queue: .main) { continuation.resume() }
        }

        if reader.status == .failed {
            throw BuildError.failed(reader.error?.localizedDescription ?? "Could not read the movie.")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.finishWriting {
                if writer.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: BuildError.failed(writer.error?.localizedDescription ?? "Could not finish the movie."))
                }
            }
        }
        return url
    }

    private static func temporaryURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
    }
}
