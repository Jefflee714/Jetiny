import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

actor VideoProcessingService {
    enum VideoError: LocalizedError {
        case cannotLoadAsset
        case cannotCreateOutput
        case cannotFinalize
        case noFramesExtracted
        case animatedWebPNotSupported

        var errorDescription: String? {
            switch self {
            case .cannotLoadAsset: return "無法載入影片檔案"
            case .cannotCreateOutput: return "無法建立輸出檔案"
            case .cannotFinalize: return "無法完成檔案寫入"
            case .noFramesExtracted: return "無法從影片中擷取任何畫面"
            case .animatedWebPNotSupported: return "動態 WebP 輸出尚未支援，請改用 GIF 格式"
            }
        }
    }

    /// Maximum frames to extract (safety limit)
    private static let maxFrames = 1000

    /// Memory safety limit for GIF frame buffering (1.5 GB)
    private static let maxGIFMemoryBytes: UInt64 = 1_500_000_000

    /// Check current process memory usage in bytes
    private static func processMemoryBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = UInt32(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }

    /// Get video duration in seconds
    static func videoDuration(url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 0 }
        return CMTimeGetSeconds(duration)
    }

    func convertToGIF(
        sourceURL: URL,
        settings: ConversionSettings,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> ProcessingResult {
        let asset = AVURLAsset(url: sourceURL)

        guard let duration = try? await asset.load(.duration) else {
            throw VideoError.cannotLoadAsset
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds > 0 else { throw VideoError.cannotLoadAsset }

        let fps = settings.frameRate
        let rawFrameCount = Int(durationSeconds * fps)
        let totalFrames = min(max(rawFrameCount, 1), Self.maxFrames)

        // Configure image generator
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        if let maxWidth = settings.videoMaxWidth, maxWidth > 0 {
            generator.maximumSize = CGSize(width: CGFloat(maxWidth), height: CGFloat(maxWidth))
        }

        // Prepare output paths
        let outputURL = FileService.outputURL(
            for: sourceURL,
            format: "gif",
            outputDirectory: settings.outputDirectoryURL
        )
        let tempURL = FileService.tempDirectory.appendingPathComponent(UUID().uuidString + ".gif")

        // Create GIF destination
        guard let destination = CGImageDestinationCreateWithURL(
            tempURL as CFURL,
            UTType.gif.identifier as CFString,
            totalFrames,
            nil
        ) else {
            throw VideoError.cannotCreateOutput
        }

        // Set GIF loop properties (infinite loop)
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameDelay = 1.0 / fps
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
            ]
        ]

        // Extract and add frames one by one with memory monitoring
        var framesAdded = 0
        for i in 0..<totalFrames {
            // Check memory pressure every 50 frames — CGImageDestination
            // retains all added frames until finalization
            if i > 0 && i % 50 == 0 {
                let memoryUsed = Self.processMemoryBytes()
                if memoryUsed > Self.maxGIFMemoryBytes {
                    // Stop adding frames to prevent OOM on low-memory systems
                    break
                }
            }

            let time = CMTime(seconds: Double(i) / fps, preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: time)
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                framesAdded += 1
            } catch {
                continue // Skip frames that fail to extract
            }

            progressHandler(Double(i + 1) / Double(totalFrames))
        }

        guard framesAdded > 0 else {
            try? FileManager.default.removeItem(at: tempURL)
            throw VideoError.noFramesExtracted
        }

        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw VideoError.cannotFinalize
        }

        // Atomic move to final location
        try FileManager.default.moveItem(at: tempURL, to: outputURL)

        // Build result
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0
        let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

        return ProcessingResult(
            outputURL: outputURL,
            originalSize: originalSize,
            compressedSize: outputSize
        )
    }

    func convertToAnimatedWebP(
        sourceURL: URL,
        settings: ConversionSettings,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> ProcessingResult {
        throw VideoError.animatedWebPNotSupported
    }
}
