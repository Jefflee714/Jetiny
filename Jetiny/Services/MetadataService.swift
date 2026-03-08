import Foundation
import ImageIO

struct MetadataService {
    /// Read all metadata properties from an image file
    static func readMetadata(from url: URL) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    }

    /// Check if an image has EXIF data
    static func hasEXIF(url: URL) -> Bool {
        guard let metadata = readMetadata(from: url) else { return false }
        return metadata[kCGImagePropertyExifDictionary as String] != nil
    }

    /// Return metadata with EXIF, GPS, and IPTC data removed
    static func strippedProperties(from metadata: [String: Any]) -> [String: Any] {
        var cleaned = metadata
        cleaned.removeValue(forKey: kCGImagePropertyExifDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyIPTCDictionary as String)
        cleaned.removeValue(forKey: kCGImagePropertyMakerAppleDictionary as String)
        return cleaned
    }

    /// Get the EXIF orientation value (1-8)
    static func orientation(from url: URL) -> UInt32 {
        guard let metadata = readMetadata(from: url) else { return 1 }
        return metadata[kCGImagePropertyOrientation as String] as? UInt32 ?? 1
    }
}
