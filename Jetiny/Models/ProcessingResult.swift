import Foundation

struct ProcessingResult: Equatable, Sendable {
    let outputURL: URL
    let originalSize: Int64
    let compressedSize: Int64

    var compressionRatio: Double {
        guard originalSize > 0 else { return 1.0 }
        return Double(compressedSize) / Double(originalSize)
    }

    var savedBytes: Int64 {
        originalSize - compressedSize
    }

    var savedPercentage: Double {
        (1.0 - compressionRatio) * 100.0
    }

    var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }
}
