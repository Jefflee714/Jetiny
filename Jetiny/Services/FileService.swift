import Foundation
import UniformTypeIdentifiers

struct FileService {
    static let supportedImageTypes: Set<UTType> = [
        .png, .jpeg, .gif, .tiff, .bmp, .heic, .heif, .webP, .rawImage
    ]

    static let supportedVideoTypes: Set<UTType> = [
        .mpeg4Movie, .quickTimeMovie, .movie, .avi
    ]

    /// Maximum number of files to discover from a single directory scan
    static let maxDiscoveredItems = 5_000

    /// All supported UTTypes for file pickers and drop validation
    static var allSupportedTypes: [UTType] {
        Array(supportedImageTypes) + Array(supportedVideoTypes)
    }

    // MARK: - File Discovery

    /// Discover media files from a list of URLs (files or directories)
    static func discoverFiles(at urls: [URL]) -> [MediaItem] {
        var items: [MediaItem] = []
        let fm = FileManager.default

        for url in urls {
            guard items.count < maxDiscoveredItems else { break }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                let remaining = maxDiscoveredItems - items.count
                items.append(contentsOf: discoverFilesInDirectory(url, limit: remaining))
            } else if isMediaFile(url) {
                items.append(MediaItem(url: url))
            }
        }
        return items
    }

    /// Recursively discover media files in a directory with a limit
    private static func discoverFilesInDirectory(_ directoryURL: URL, limit: Int) -> [MediaItem] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var items: [MediaItem] = []
        for case let fileURL as URL in enumerator {
            guard items.count < limit else { break }

            // Skip system files
            let name = fileURL.lastPathComponent
            if name.hasPrefix(".") || name == ".DS_Store" { continue }

            // Check if it's a regular file (not symlink to missing target, etc.)
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else { continue }

            if isMediaFile(fileURL) {
                items.append(MediaItem(url: fileURL))
            }
        }
        return items
    }

    /// Check if a URL points to a supported media file
    static func isMediaFile(_ url: URL) -> Bool {
        guard let utType = UTType(filenameExtension: url.pathExtension) else { return false }
        return supportedImageTypes.contains(where: { utType.conforms(to: $0) })
            || supportedVideoTypes.contains(where: { utType.conforms(to: $0) })
    }

    // MARK: - Output Path

    /// Lock to serialize outputURL generation, preventing TOCTOU race
    /// when multiple concurrent batch tasks request output paths simultaneously
    private static let outputURLLock = NSLock()

    /// Generate output URL with _jetiny suffix and correct extension.
    /// Thread-safe: uses a lock to prevent two concurrent tasks from
    /// getting the same output path.
    static func outputURL(for sourceURL: URL, format: String, outputDirectory: URL?) -> URL {
        outputURLLock.lock()
        defer { outputURLLock.unlock() }

        let dir = outputDirectory ?? sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var outputURL = dir.appendingPathComponent("\(baseName)_jetiny.\(format)")

        // Handle name collisions with a bounded loop
        let fm = FileManager.default
        var counter = 1
        let maxAttempts = 9_999
        while fm.fileExists(atPath: outputURL.path) && counter <= maxAttempts {
            outputURL = dir.appendingPathComponent("\(baseName)_jetiny_\(counter).\(format)")
            counter += 1
        }

        return outputURL
    }

    // MARK: - Temp Files

    /// Temporary directory for atomic writes
    static var tempDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Jetiny", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Clean up temp files from previous sessions
    static func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Jetiny", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Cloud Files

    /// Check if a file is an iCloud placeholder that hasn't been downloaded
    static func isCloudFileNotDownloaded(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]) else { return false }
        guard values.isUbiquitousItem == true else { return false }
        guard let status = values.ubiquitousItemDownloadingStatus else { return false }
        return status != URLUbiquitousItemDownloadingStatus.current
    }

    // MARK: - Disk Space

    /// Check available disk space at the given URL
    static func availableDiskSpace(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    // MARK: - Permissions

    /// Check if a directory is writable
    static func isWritable(_ url: URL) -> Bool {
        FileManager.default.isWritableFile(atPath: url.path)
    }
}
