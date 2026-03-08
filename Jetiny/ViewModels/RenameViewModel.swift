import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
class RenameViewModel {
    var renameItems: [RenameItem] = []
    var selectedItemIDs: Set<UUID> = []
    var settings = RenameSettings()
    var previews: [RenamePreview] = []
    var isProcessing = false
    var results: [RenameResult] = []
    var showResults = false
    var isLoadingFiles = false
    var showConfirmAlert = false

    // Undo
    private(set) var undoRecord: RenameUndoRecord?
    var isUndoing = false

    private var previewTask: Task<Void, Never>?
    private var renameTask: Task<[RenameResult], Never>?
    private var undoTask: Task<(reverted: Int, failed: Int), Never>?

    // MARK: - Computed Properties

    var validCount: Int {
        previews.filter {
            !$0.isSkipped && !$0.isEmpty && !$0.hasConflict && !$0.existsOnDisk
            && !$0.isUnchanged && !$0.hasIllegalChars && !$0.isTooLong
        }.count
    }

    var hasConflicts: Bool {
        previews.contains { $0.hasConflict }
    }

    var conflictCount: Int {
        previews.filter { $0.hasConflict }.count
    }

    var existsOnDiskCount: Int {
        previews.filter { $0.existsOnDisk }.count
    }

    var skippedCount: Int {
        previews.filter { $0.isSkipped }.count
    }

    var unchangedCount: Int {
        previews.filter { $0.isUnchanged }.count
    }

    var emptyCount: Int {
        previews.filter { $0.isEmpty }.count
    }

    var illegalCharsCount: Int {
        previews.filter { $0.hasIllegalChars }.count
    }

    var tooLongCount: Int {
        previews.filter { $0.isTooLong }.count
    }

    var canUndo: Bool {
        undoRecord != nil && !isUndoing
    }

    var successCount: Int {
        results.filter { if case .success = $0.status { return true } else { return false } }.count
    }

    var failedResults: [RenameResult] {
        results.filter { if case .failed = $0.status { return true } else { return false } }
    }

    // MARK: - File Import (ALL file types)

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        // No allowedContentTypes — accept ALL files
        panel.message = L( "選擇要重新命名的檔案")

        if panel.runModal() == .OK {
            addFilesAsync(urls: panel.urls)
        }
    }

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L( "選擇包含要重新命名檔案的資料夾")

        if panel.runModal() == .OK {
            addFilesAsync(urls: panel.urls)
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        Task {
            var urls: [URL] = []
            for provider in providers {
                if let url = await loadURL(from: provider) {
                    urls.append(url)
                }
            }
            if !urls.isEmpty {
                addFilesAsync(urls: urls)
            }
        }
        return true
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func addFilesAsync(urls: [URL]) {
        isLoadingFiles = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let newItems = RenameService.discoverFiles(at: urls)
            await MainActor.run {
                guard let self else { return }
                // Deduplicate by URL
                let existingURLs = Set(self.renameItems.map(\.url))
                let unique = newItems.filter { !existingURLs.contains($0.url) }
                self.renameItems.append(contentsOf: unique)
                self.isLoadingFiles = false
                self.regeneratePreviews()
            }
        }
    }

    // MARK: - Item Management

    func clearAll() {
        // Cancel any in-flight operations
        previewTask?.cancel()
        renameTask?.cancel()
        undoTask?.cancel()
        renameItems.removeAll()
        selectedItemIDs.removeAll()
        previews.removeAll()
        isProcessing = false
        isUndoing = false
    }

    func removeSelected() {
        renameItems.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
        regeneratePreviews()
    }

    // MARK: - Preview Generation (debounced)

    func regeneratePreviews() {
        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }

            let items = renameItems
            let settings = settings

            let newPreviews = await Task.detached(priority: .medium) {
                RenameService.generatePreviews(items: items, settings: settings)
            }.value

            if !Task.isCancelled {
                previews = newPreviews
            }
        }
    }

    // MARK: - Execution

    /// Show confirmation alert before renaming
    func confirmStartRenaming() {
        showConfirmAlert = true
    }

    func startRenaming() async {
        guard validCount > 0, !hasConflicts, existsOnDiskCount == 0 else { return }
        isProcessing = true

        let currentPreviews = previews
        let task = Task.detached(priority: .userInitiated) {
            RenameService.executeRenames(previews: currentPreviews)
        }
        renameTask = task
        let renameResults = await task.value
        renameTask = nil

        results = renameResults
        isProcessing = false
        showResults = true

        // Build undo record from successful renames
        let undoEntries: [(newURL: URL, originalURL: URL)] = renameResults.compactMap { result in
            guard case .success = result.status, let newURL = result.newURL else { return nil }
            return (newURL: newURL, originalURL: result.originalURL)
        }
        if !undoEntries.isEmpty {
            undoRecord = RenameUndoRecord(entries: undoEntries, timestamp: Date())
        }

        // Update items to reflect new URLs
        var updatedItems: [RenameItem] = []
        for result in renameResults {
            if case .success = result.status, let newURL = result.newURL {
                updatedItems.append(RenameItem(url: newURL))
            } else {
                // Keep original item for failed/skipped items
                if let originalItem = renameItems.first(where: { $0.url == result.originalURL }) {
                    updatedItems.append(originalItem)
                }
            }
        }
        renameItems = updatedItems
        selectedItemIDs.removeAll()
        regeneratePreviews()
    }

    func dismissResults() {
        showResults = false
        results.removeAll()
    }

    // MARK: - Undo

    func undoLastRename() async {
        guard let record = undoRecord else { return }
        isUndoing = true

        let task = Task.detached(priority: .userInitiated) {
            RenameService.undoRenames(record: record)
        }
        undoTask = task
        let result = await task.value
        undoTask = nil

        isUndoing = false
        undoRecord = nil

        // Reload items from original URLs
        var restoredItems: [RenameItem] = []
        for entry in record.entries {
            // If revert succeeded, use original URL; otherwise keep new URL
            let url = FileManager.default.fileExists(atPath: entry.originalURL.path)
                ? entry.originalURL
                : entry.newURL
            restoredItems.append(RenameItem(url: url))
        }

        // Also keep any items that weren't part of the undo
        let undoNewURLs = Set(record.entries.map(\.newURL))
        let keptItems = renameItems.filter { !undoNewURLs.contains($0.url) }
        renameItems = keptItems + restoredItems

        selectedItemIDs.removeAll()
        regeneratePreviews()

        // Brief feedback — reuse results overlay concept is overkill for undo,
        // just log to let user know it's done
        _ = result // (reverted, failed) — already reflected in the updated file list
    }
}
