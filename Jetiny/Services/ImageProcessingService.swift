import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import AppKit
import WebP

actor ImageProcessingService {
    enum ImageError: LocalizedError {
        case cannotCreateSource
        case cannotCreateImage
        case cannotCreateDestination
        case cannotFinalize
        case unsupportedFormat
        case outputDirectoryNotWritable
        case webpEncodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .cannotCreateSource: return "無法讀取圖片檔案"
            case .cannotCreateImage: return "無法解碼圖片"
            case .cannotCreateDestination: return "無法建立輸出檔案"
            case .cannotFinalize: return "無法完成圖片寫入"
            case .unsupportedFormat: return "不支援的輸出格式"
            case .outputDirectoryNotWritable: return "輸出目錄沒有寫入權限"
            case .webpEncodingFailed(let detail): return "WebP 編碼失敗：\(detail)"
            }
        }
    }

    func processImage(
        sourceURL: URL,
        settings: ConversionSettings,
        progressHandler: @Sendable (Double) -> Void
    ) async throws -> ProcessingResult {
        progressHandler(0.1)

        // 1. Load image with orientation applied
        let cgImage = try loadImage(from: sourceURL)
        progressHandler(0.3)

        // 2. Resize first if needed (before compression — saves memory)
        // Guard: maxWidth <= 0 is treated as "no limit"
        let resized: CGImage
        if let maxWidth = settings.maxWidth, maxWidth > 0, cgImage.width > maxWidth {
            resized = resizeImage(cgImage, maxWidth: maxWidth)
        } else {
            resized = cgImage
        }
        progressHandler(0.4)

        // 2.5 Apply watermark if enabled
        let watermarked: CGImage
        if settings.watermark.mode != .none {
            watermarked = WatermarkService.applyWatermark(to: resized, settings: settings.watermark)
        } else {
            watermarked = resized
        }
        progressHandler(0.5)

        // 3. Prepare metadata (not applicable for WebP — WebP strips metadata)
        let metadata: [String: Any]?
        if settings.stripEXIF || settings.outputImageFormat == .webp {
            metadata = nil
        } else {
            if let sourceMeta = MetadataService.readMetadata(from: sourceURL) {
                var cleaned = sourceMeta
                // Remove orientation from all levels — pixels are already rotated by loadImage
                cleaned.removeValue(forKey: kCGImagePropertyOrientation as String)
                if var tiff = cleaned[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    tiff.removeValue(forKey: kCGImagePropertyTIFFOrientation as String)
                    cleaned[kCGImagePropertyTIFFDictionary as String] = tiff
                }
                metadata = cleaned
            } else {
                metadata = nil
            }
        }
        progressHandler(0.6)

        // 4. Determine output path
        let outputDir = settings.outputDirectoryURL ?? sourceURL.deletingLastPathComponent()
        guard FileService.isWritable(outputDir) else {
            throw ImageError.outputDirectoryNotWritable
        }

        let outputURL = FileService.outputURL(
            for: sourceURL,
            format: settings.outputImageFormat.fileExtension,
            outputDirectory: settings.outputDirectoryURL
        )

        // 5. Encode to target format (atomic write via temp file)
        let tempURL = FileService.tempDirectory.appendingPathComponent(UUID().uuidString + "." + settings.outputImageFormat.fileExtension)

        switch settings.outputImageFormat {
        case .png:
            try encodeToPNG(watermarked, metadata: metadata, outputURL: tempURL)
        case .jpeg:
            try encodeToJPEG(watermarked, quality: settings.qualityNormalized, metadata: metadata, outputURL: tempURL)
        case .webp:
            try encodeToWebP(watermarked, quality: Float(settings.quality), outputURL: tempURL)
        }
        progressHandler(0.9)

        // 6. Atomic move from temp to final location
        try FileManager.default.moveItem(at: tempURL, to: outputURL)

        // 7. Preserve original file's modification date
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            try? FileManager.default.setAttributes(
                [.modificationDate: modDate],
                ofItemAtPath: outputURL.path
            )
        }
        progressHandler(1.0)

        // 8. Build result
        let outputSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0

        return ProcessingResult(
            outputURL: outputURL,
            originalSize: (try? FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0,
            compressedSize: outputSize
        )
    }

    // MARK: - Image Loading

    private func loadImage(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageError.cannotCreateSource
        }

        // Check if this is a RAW image
        let isRAW: Bool = {
            guard let sourceType = CGImageSourceGetType(source) as String? else { return false }
            return UTType(sourceType)?.conforms(to: .rawImage) ?? false
        }()

        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false
        ]

        if isRAW {
            // Force full-resolution RAW demosaicing (not embedded preview)
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let maxDim = max(width, height)
            if maxDim > 0 {
                options[kCGImageSourceThumbnailMaxPixelSize] = maxDim
            }
            options[kCGImageSourceShouldAllowFloat] = true
        }

        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return cgImage
        }

        // Fallback: direct image creation (no orientation fix)
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceShouldAllowFloat: true
        ] as CFDictionary) else {
            throw ImageError.cannotCreateImage
        }
        return image
    }

    // MARK: - Resize

    private func resizeImage(_ image: CGImage, maxWidth: Int) -> CGImage {
        let originalWidth = image.width
        let originalHeight = image.height

        guard originalWidth > maxWidth else { return image }

        let scale = CGFloat(maxWidth) / CGFloat(originalWidth)
        let newWidth = maxWidth
        let newHeight = Int(CGFloat(originalHeight) * scale)

        guard newWidth > 0, newHeight > 0 else { return image }

        // For high bit-depth images (RAW 16-bit), convert to 8-bit sRGB
        // to reduce memory and ensure encoder compatibility
        let bpc: Int
        let colorSpace: CGColorSpace
        let bitmapInfo: UInt32

        if image.bitsPerComponent > 8 {
            bpc = 8
            colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        } else {
            bpc = image.bitsPerComponent
            colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
            bitmapInfo = image.bitmapInfo.rawValue
        }

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: bpc,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage() ?? image
    }

    // MARK: - Encoding

    private func encodeToPNG(_ image: CGImage, metadata: [String: Any]?, outputURL: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1, nil
        ) else {
            throw ImageError.cannotCreateDestination
        }

        CGImageDestinationAddImage(destination, image, metadata as CFDictionary?)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageError.cannotFinalize
        }
    }

    private func encodeToWebP(_ image: CGImage, quality: Float, outputURL: URL) throws {
        let encoder = WebPEncoder()

        // Detect pixel format to skip expensive RGBA conversion when possible
        if let (directImage, format) = detectWebPPixelFormat(image) {
            var config = WebPEncoderConfig.preset(.photo, quality: quality)
            config.method = 2       // 0=fast, 6=slow; 2 is ~2-3x faster than default 4
            config.threadLevel = 1  // enable multi-threaded encoding
            do {
                let data = try encoder.encode(directImage, format: format, config: config)
                try data.write(to: outputURL, options: .atomic)
                return
            } catch {
                // Fall through to ensureRGBA path
            }
        }

        // Fallback: convert to guaranteed RGBA format
        let rgbaImage = try ensureRGBA(image)
        var config = WebPEncoderConfig.preset(.photo, quality: quality)
        config.method = 2
        config.threadLevel = 1
        do {
            let data = try encoder.encode(rgbaImage, config: config)
            try data.write(to: outputURL, options: .atomic)
        } catch {
            throw ImageError.webpEncodingFailed(error.localizedDescription)
        }
    }

    /// Detect if a CGImage can be passed directly to WebP encoder
    /// without an expensive RGBA conversion.
    /// Returns the image and its pixel format, or nil if conversion is needed.
    private func detectWebPPixelFormat(_ image: CGImage) -> (CGImage, WebPEncodePixelFormat)? {
        // Must be 8 bits per component
        guard image.bitsPerComponent == 8 else { return nil }
        // Must be 4 bytes per pixel (32-bit)
        guard image.bitsPerPixel == 32 else { return nil }

        let alphaInfo = CGImageAlphaInfo(
            rawValue: image.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        )
        let byteOrder = CGBitmapInfo(
            rawValue: image.bitmapInfo.rawValue & CGBitmapInfo.byteOrderMask.rawValue
        )

        // RGBA byte order: big-endian or default with last/noneSkipLast alpha
        if alphaInfo == .premultipliedLast || alphaInfo == .last || alphaInfo == .noneSkipLast {
            if byteOrder == [] || byteOrder == .byteOrder32Big {
                return (image, .rgba)
            }
        }

        // BGRA byte order: little-endian with first/noneSkipFirst alpha
        // This is very common on macOS (Apple's preferred internal format)
        if alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst {
            if byteOrder == .byteOrder32Little {
                return (image, .bgra)
            }
        }

        return nil
    }

    /// Convert CGImage to standard 8-bit RGBA format (required by WebP encoder)
    private func ensureRGBA(_ image: CGImage) throws -> CGImage {
        let width = image.width
        let height = image.height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ImageError.cannotCreateImage
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ImageError.cannotCreateImage
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let result = context.makeImage() else {
            throw ImageError.cannotCreateImage
        }
        return result
    }

    private func encodeToJPEG(_ image: CGImage, quality: CGFloat, metadata: [String: Any]?, outputURL: URL) throws {
        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        if let metadata {
            for (key, value) in metadata {
                properties[key as CFString] = value
            }
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1, nil
        ) else {
            throw ImageError.cannotCreateDestination
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageError.cannotFinalize
        }
    }
}
