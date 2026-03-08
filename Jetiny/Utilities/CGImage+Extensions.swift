import CoreGraphics
import ImageIO
import AppKit

extension CGImage {
    /// Generate a thumbnail efficiently without decoding the full image
    static func thumbnail(from url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: false
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

extension NSImage {
    /// Create NSImage from CGImage
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Load a thumbnail NSImage efficiently
    static func thumbnail(from url: URL, maxPixelSize: Int = 100) -> NSImage? {
        guard let cgImage = CGImage.thumbnail(from: url, maxPixelSize: maxPixelSize) else { return nil }
        return NSImage(cgImage: cgImage)
    }
}
