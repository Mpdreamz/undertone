import AVFoundation
import CoreVideo
import Foundation

/// A picture in motion, written as a movie: a seamless loop of the picture drifting, and a settle that slows the
/// drift to a stop on the still picture, so the last frame is exactly what the desktop shows.
public enum Movie {
    /// The moments of a loop: `seconds` long at `fps`, one cycle of every drift.
    public static func loop(seconds: Double, fps: Int) -> [Motion] {
        let count = max(Int(seconds * Double(fps)), 1)
        return (0 ..< count).map { Motion(time: Float($0) / Float(count), amount: 1) }
    }

    /// The moments of a settle, starting where a loop of `loopSeconds` is at `time`: the drift keeps going but slows,
    /// and its reach shrinks to nothing, over `seconds`. Its last moment is the still picture.
    public static func settle(from time: Float, loopSeconds: Double, seconds: Double, fps: Int) -> [Motion] {
        let count = max(Int(seconds * Double(fps)), 2)
        var t = time
        let step = Float(1 / (loopSeconds * Double(fps)))
        return (0 ..< count).map { i in
            let p = Float(i) / Float(count - 1)
            // Speed and reach both ease out: fast at first, gently onto the still.
            let left = 1 - p
            t += step * left * left
            return i == count - 1 ? .still : Motion(time: t, amount: left * left * left * (2 - left))
        }
    }

    public enum Codec: String, Sendable {
        case hevc, h264

        var avCodec: AVVideoCodecType {
            self == .hevc ? .hevc : .h264
        }
    }

    public struct Failure: Error, CustomStringConvertible {
        public let description: String
    }

    /// Draws every moment of `motions` and writes them to `url` (an .mp4 or .mov) at `fps`. `progress` hears the
    /// number of frames written.
    public static func write(
        _ recipe: Recipe, width: Int, height: Int, scale: Float, motions: [Motion], fps: Int, codec: Codec = .hevc,
        to url: URL, progress: (Int) -> Void = { _ in }
    ) throws {
        try? FileManager.default.removeItem(at: url)
        let type: AVFileType = url.pathExtension.lowercased() == "mov" ? .mov : .mp4
        let writer = try AVAssetWriter(outputURL: url, fileType: type)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: codec.avCodec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: width * height * 4],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw Failure(description: "cannot write \(codec.rawValue) video") }
        writer.add(input)
        guard writer.startWriting() else {
            throw Failure(description: writer.error.map(String.init(describing:)) ?? "cannot start writing")
        }
        writer.startSession(atSourceTime: .zero)

        for (index, motion) in motions.enumerated() {
            let picture = Renderer.render(recipe, width: width, height: height, scale: scale, motion: motion)
            guard let pool = adaptor.pixelBufferPool else { throw Failure(description: "no pixel buffers") }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw Failure(description: "no pixel buffer") }
            fill(buffer, with: picture)
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps))
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw Failure(description: writer.error.map(String.init(describing:)) ?? "frame \(index) failed")
            }
            progress(index + 1)
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        if writer.status != .completed {
            throw Failure(description: writer.error.map(String.init(describing:)) ?? "the movie did not finish")
        }
    }

    /// RGBA rows into a BGRA pixel buffer.
    private static func fill(_ buffer: CVPixelBuffer, with picture: Picture) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) else { return }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        picture.pixels.withUnsafeBufferPointer { source in
            for y in 0 ..< picture.height {
                let row = base + y * stride
                let from = y * picture.width * 4
                for x in 0 ..< picture.width {
                    let i = from + x * 4, o = x * 4
                    row[o] = source[i + 2]
                    row[o + 1] = source[i + 1]
                    row[o + 2] = source[i]
                    row[o + 3] = 255
                }
            }
        }
    }
}
