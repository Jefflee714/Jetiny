import Foundation
import UniformTypeIdentifiers

enum OutputImageFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case webp = "WebP"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        }
    }

    var utType: UTType? {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .webp: return nil // WebP encoding handled separately
        }
    }

    /// Whether this format supports transparency
    var supportsAlpha: Bool {
        switch self {
        case .png, .webp: return true
        case .jpeg: return false
        }
    }

    /// Whether this format supports lossy compression quality setting
    var supportsQuality: Bool {
        switch self {
        case .jpeg, .webp: return true
        case .png: return false
        }
    }
}

enum OutputVideoFormat: String, CaseIterable, Identifiable {
    case gif = "GIF"
    case animatedWebP = "WebP"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .gif: return "gif"
        case .animatedWebP: return "webp"
        }
    }
}

enum MediaType: Sendable {
    case image
    case video
}
