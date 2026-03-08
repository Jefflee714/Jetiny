import Foundation
import UniformTypeIdentifiers

extension URL {
    var mediaType: MediaType? {
        guard let utType = UTType(filenameExtension: pathExtension) else { return nil }

        if FileService.supportedImageTypes.contains(where: { utType.conforms(to: $0) }) {
            return .image
        }
        if FileService.supportedVideoTypes.contains(where: { utType.conforms(to: $0) }) {
            return .video
        }
        return nil
    }

    var isMediaFile: Bool {
        mediaType != nil
    }
}
