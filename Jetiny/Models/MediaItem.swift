import Foundation
import UniformTypeIdentifiers
import AppKit
import ImageIO

struct MediaItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileSize: Int64
    let mediaType: MediaType
    let pixelWidth: Int
    let pixelHeight: Int

    var megapixels: Double {
        Double(pixelWidth * pixelHeight) / 1_000_000.0
    }

    var isLargeImage: Bool {
        megapixels > 30
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var dimensionText: String {
        "\(pixelWidth) × \(pixelHeight)"
    }

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        self.fileSize = Int64(resourceValues?.fileSize ?? 0)

        let utType = UTType(filenameExtension: url.pathExtension)
        if let utType, FileService.supportedVideoTypes.contains(where: { utType.conforms(to: $0) }) {
            self.mediaType = .video
            self.pixelWidth = 0
            self.pixelHeight = 0
        } else {
            self.mediaType = .image
            let dimensions = MediaItem.readImageDimensions(from: url)
            self.pixelWidth = dimensions.width
            self.pixelHeight = dimensions.height
        }
    }

    private static func readImageDimensions(from url: URL) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return (0, 0)
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (0, 0)
        }
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0

        // Check EXIF orientation — swap width/height for rotated images
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        if orientation >= 5 && orientation <= 8 {
            return (height, width)
        }
        return (width, height)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}
