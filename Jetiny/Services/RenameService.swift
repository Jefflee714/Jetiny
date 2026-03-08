import Foundation

// MARK: - Preview Result

struct RenamePreview: Identifiable, Equatable {
    var id: UUID { item.id }
    let item: RenameItem
    let newName: String
    let hasConflict: Bool       // 批次內多個檔案產生相同名稱
    let existsOnDisk: Bool      // 目標檔名在磁碟上已存在
    let isSkipped: Bool
    let isEmpty: Bool
    let isUnchanged: Bool
    let hasIllegalChars: Bool
    let isTooLong: Bool
}

// MARK: - Undo Record

struct RenameUndoRecord: Sendable {
    let entries: [(newURL: URL, originalURL: URL)]
    let timestamp: Date
}

// MARK: - Execution Result

struct RenameResult: Identifiable {
    let id = UUID()
    let originalURL: URL
    let newURL: URL?
    let status: RenameResultStatus
}

enum RenameResultStatus {
    case success
    case skipped(reason: String)
    case failed(error: String)
}

// MARK: - Rename Service

enum RenameService {

    // MARK: - File Discovery (ALL file types)

    static let maxDiscoveredItems = 5_000

    /// Discover all regular files from URLs (files or directories).
    /// Unlike FileService, this accepts ALL file types.
    static func discoverFiles(at urls: [URL]) -> [RenameItem] {
        var items: [RenameItem] = []
        let fm = FileManager.default

        for url in urls {
            guard items.count < maxDiscoveredItems else { break }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                let remaining = maxDiscoveredItems - items.count
                items.append(contentsOf: discoverFilesInDirectory(url, limit: remaining))
            } else {
                items.append(RenameItem(url: url))
            }
        }
        return items
    }

    private static func discoverFilesInDirectory(_ directoryURL: URL, limit: Int) -> [RenameItem] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var items: [RenameItem] = []
        for case let fileURL as URL in enumerator {
            guard items.count < limit else { break }

            let name = fileURL.lastPathComponent
            if name.hasPrefix(".") || name == ".DS_Store" { continue }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else { continue }

            items.append(RenameItem(url: fileURL))
        }
        return items
    }

    // MARK: - Filename Validation

    /// Characters that are illegal in macOS filenames
    private static let illegalCharacters: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "/:")      // macOS filesystem illegal
        set.insert(Unicode.Scalar(0))       // null byte
        return set
    }()

    /// APFS filename byte limit (UTF-8)
    static let maxFileNameBytes = 255

    /// Check if a filename contains illegal characters
    static func containsIllegalChars(_ name: String) -> Bool {
        name.unicodeScalars.contains { illegalCharacters.contains($0) }
    }

    /// Check if a filename exceeds the byte limit
    static func isFileNameTooLong(_ name: String) -> Bool {
        name.utf8.count > maxFileNameBytes
    }

    // MARK: - Preview Generation

    /// Generate preview results for all items. Pure function, safe to call from any thread.
    static func generatePreviews(items: [RenameItem], settings: RenameSettings) -> [RenamePreview] {
        // Step 1: Compute new names
        var rawPreviews: [(item: RenameItem, newStem: String, skipped: Bool)] = []

        for (index, item) in items.enumerated() {
            switch settings.mode {
            case .format:
                let stem = formatName(index: index, settings: settings.formatSettings)
                rawPreviews.append((item, stem, false))

            case .replaceText:
                let result = replaceName(item: item, settings: settings.replaceSettings)
                rawPreviews.append((item, result.stem, result.skipped))

            case .addText:
                let stem = addTextName(item: item, settings: settings.addTextSettings)
                rawPreviews.append((item, stem, false))
            }
        }

        // Step 2: Build full filenames and detect issues
        var fullNames: [(item: RenameItem, newName: String, skipped: Bool, isEmpty: Bool, isUnchanged: Bool, hasIllegalChars: Bool, isTooLong: Bool)] = []

        for entry in rawPreviews {
            let trimmedStem = entry.newStem.trimmingCharacters(in: .whitespaces)
            let ext = entry.item.fileExtension
            let newName: String
            if ext.isEmpty {
                newName = trimmedStem
            } else {
                newName = trimmedStem.isEmpty ? "" : "\(trimmedStem).\(ext)"
            }

            let isEmpty = trimmedStem.isEmpty && !entry.skipped
            let isUnchanged = newName == entry.item.fileName

            // Validate filename
            let hasIllegal = !entry.skipped && !isEmpty && !isUnchanged && containsIllegalChars(newName)
            let tooLong = !entry.skipped && !isEmpty && !isUnchanged && isFileNameTooLong(newName)

            fullNames.append((entry.item, newName, entry.skipped, isEmpty, isUnchanged, hasIllegal, tooLong))
        }

        // Step 3: Detect conflicts (same directory + same new name, case-insensitive)
        var nameGroups: [String: Int] = [:]
        for entry in fullNames where !entry.skipped && !entry.isEmpty && !entry.isUnchanged {
            let key = "\(entry.item.directoryURL.path)/\(entry.newName.lowercased())"
            nameGroups[key, default: 0] += 1
        }

        // Step 4: Build final previews (includes disk existence check)
        let fm = FileManager.default
        // Build set of all source URLs to avoid false positives
        // (e.g., file A renamed to B, file B renamed to A — B exists but it's being moved)
        let sourceURLs = Set(items.map(\.url))

        return fullNames.map { entry in
            let key = "\(entry.item.directoryURL.path)/\(entry.newName.lowercased())"
            let hasConflict = !entry.skipped && !entry.isEmpty && !entry.isUnchanged
                && (nameGroups[key] ?? 0) > 1

            // Check if target file already exists on disk AND is not one of the source files
            let existsOnDisk: Bool
            if !entry.skipped && !entry.isEmpty && !entry.isUnchanged && !hasConflict {
                let targetURL = entry.item.directoryURL.appendingPathComponent(entry.newName)
                existsOnDisk = fm.fileExists(atPath: targetURL.path) && !sourceURLs.contains(targetURL)
            } else {
                existsOnDisk = false
            }

            return RenamePreview(
                item: entry.item,
                newName: entry.newName,
                hasConflict: hasConflict,
                existsOnDisk: existsOnDisk,
                isSkipped: entry.skipped,
                isEmpty: entry.isEmpty,
                isUnchanged: entry.isUnchanged,
                hasIllegalChars: entry.hasIllegalChars,
                isTooLong: entry.isTooLong
            )
        }
    }

    // MARK: - Name Computation Helpers

    private static func formatName(index: Int, settings: FormatSettings) -> String {
        let number = settings.startNumber + index
        let padded = String(format: "%0\(settings.digitCount)d", number)
        if settings.customText.isEmpty {
            return padded
        }
        return settings.customText + settings.separator + padded
    }

    private static func replaceName(
        item: RenameItem,
        settings: ReplaceTextSettings
    ) -> (stem: String, skipped: Bool) {
        let stem = item.nameWithoutExtension

        // Empty find text → nothing to do
        guard !settings.findText.isEmpty else {
            return (stem, true)
        }

        let options: String.CompareOptions = settings.caseSensitive ? [] : [.caseInsensitive]
        if stem.range(of: settings.findText, options: options) != nil {
            let replaced = stem.replacingOccurrences(
                of: settings.findText,
                with: settings.replaceText,
                options: options
            )
            return (replaced, false)
        }

        return (stem, true) // not found → skip
    }

    private static func addTextName(item: RenameItem, settings: AddTextSettings) -> String {
        settings.prefix + item.nameWithoutExtension + settings.suffix
    }

    // MARK: - Execution

    /// Execute file renames sequentially. Returns results for each preview.
    static func executeRenames(previews: [RenamePreview]) -> [RenameResult] {
        let fm = FileManager.default
        var results: [RenameResult] = []

        for preview in previews {
            // Skip items that shouldn't be renamed
            if preview.isSkipped {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .skipped(reason: "搜尋文字不存在")
                ))
                continue
            }

            if preview.isEmpty {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .skipped(reason: "新名稱為空")
                ))
                continue
            }

            if preview.hasConflict {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .skipped(reason: "批次內名稱衝突")
                ))
                continue
            }

            if preview.existsOnDisk {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .failed(error: "目標檔名在磁碟上已存在")
                ))
                continue
            }

            if preview.isUnchanged {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .skipped(reason: "名稱未改變")
                ))
                continue
            }

            if preview.hasIllegalChars {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .failed(error: "檔名含有非法字元（/ 或 :）")
                ))
                continue
            }

            if preview.isTooLong {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .failed(error: "檔名超過 255 bytes 上限")
                ))
                continue
            }

            // Execute rename
            let newURL = preview.item.directoryURL.appendingPathComponent(preview.newName)

            // Check if destination already exists on disk
            if fm.fileExists(atPath: newURL.path) {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .failed(error: "目標檔案已存在")
                ))
                continue
            }

            do {
                try fm.moveItem(at: preview.item.url, to: newURL)
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: newURL,
                    status: .success
                ))
            } catch {
                results.append(RenameResult(
                    originalURL: preview.item.url,
                    newURL: nil,
                    status: .failed(error: error.localizedDescription)
                ))
            }
        }

        return results
    }

    // MARK: - Undo

    /// Reverse a batch of renames. Returns the number of successfully reverted files.
    static func undoRenames(record: RenameUndoRecord) -> (reverted: Int, failed: Int) {
        let fm = FileManager.default
        var reverted = 0
        var failed = 0

        // Reverse in opposite order to handle any potential dependencies
        for entry in record.entries.reversed() {
            do {
                try fm.moveItem(at: entry.newURL, to: entry.originalURL)
                reverted += 1
            } catch {
                failed += 1
            }
        }

        return (reverted, failed)
    }
}
