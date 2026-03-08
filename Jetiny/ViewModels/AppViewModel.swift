import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
class AppViewModel {
    var mediaItems: [MediaItem] = []
    var selectedItemIDs: Set<UUID> = []
    var settings = ConversionSettings()
    var batchService = BatchProcessingService()
    var showLargeImageAlert = false
    var largeImageItems: [MediaItem] = []
    var isLoadingFiles = false

    // Batch results
    var showBatchResults = false

    // Warnings
    var showLongVideoWarning = false
    var longVideoItems: [MediaItem] = []
    var insufficientDiskSpace = false
    var showNotWritableError = false

    var selectedItem: MediaItem? {
        guard selectedItemIDs.count == 1,
              let id = selectedItemIDs.first else { return nil }
        return mediaItems.first { $0.id == id }
    }

    var hasImages: Bool {
        mediaItems.contains { $0.mediaType == .image }
    }

    var hasVideos: Bool {
        mediaItems.contains { $0.mediaType == .video }
    }

    // MARK: - File Import

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = FileService.allSupportedTypes
        panel.message = L( "選擇要處理的圖片或影片")

        if panel.runModal() == .OK {
            addFilesAsync(urls: panel.urls)
        }
    }

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = L( "選擇包含圖片或影片的資料夾")

        if panel.runModal() == .OK {
            addFilesAsync(urls: panel.urls)
        }
    }

    /// Discover and add files off the main thread to avoid UI freezing
    private func addFilesAsync(urls: [URL]) {
        isLoadingFiles = true
        let existingURLs = Set(mediaItems.map(\.url))

        Task.detached(priority: .userInitiated) {
            let newItems = FileService.discoverFiles(at: urls)
            let uniqueItems = newItems.filter { !existingURLs.contains($0.url) }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.mediaItems.append(contentsOf: uniqueItems)
                self.isLoadingFiles = false

                // Check for large images (unless warning is disabled)
                if !self.settings.disableLargeImageWarning {
                    let large = uniqueItems.filter { $0.isLargeImage }
                    if !large.isEmpty {
                        self.largeImageItems = large
                        self.showLargeImageAlert = true
                    }
                }
            }
        }
    }

    // MARK: - Drag & Drop

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        Task {
            var urls: [URL] = []
            await withTaskGroup(of: URL?.self) { group in
                for provider in providers {
                    group.addTask {
                        await withCheckedContinuation { continuation in
                            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                if let data = item as? Data,
                                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                                    continuation.resume(returning: url)
                                } else {
                                    continuation.resume(returning: nil)
                                }
                            }
                        }
                    }
                }
                for await url in group {
                    if let url { urls.append(url) }
                }
            }
            addFilesAsync(urls: urls)
        }
        return true
    }

    // MARK: - Actions

    func clearAll() {
        // Cancel in-flight batch processing before clearing
        if batchService.isProcessing {
            batchService.cancel()
        }
        mediaItems.removeAll()
        selectedItemIDs.removeAll()
    }

    func removeSelected() {
        mediaItems.removeAll { selectedItemIDs.contains($0.id) }
        selectedItemIDs.removeAll()
    }

    func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L( "選擇輸出資料夾")

        if panel.runModal() == .OK {
            settings.outputDirectoryURL = panel.url
        }
    }

    // MARK: - Processing

    func startProcessing() async {
        guard !mediaItems.isEmpty else { return }

        // Check output directory is writable
        if let outputDir = settings.outputDirectoryURL {
            guard FileService.isWritable(outputDir) else {
                showNotWritableError = true
                return
            }
        }

        // Check disk space
        if !batchService.checkDiskSpace(items: mediaItems, settings: settings) {
            insufficientDiskSpace = true
            return
        }

        // Check for long videos (>30s) — load durations in parallel
        let videoItems = mediaItems.filter { $0.mediaType == .video }
        if !videoItems.isEmpty {
            let longVideos = await withTaskGroup(of: (MediaItem, TimeInterval).self) { group in
                for item in videoItems {
                    group.addTask {
                        let duration = await VideoProcessingService.videoDuration(url: item.url)
                        return (item, duration)
                    }
                }
                var result: [MediaItem] = []
                for await (item, duration) in group {
                    if duration > 30 {
                        result.append(item)
                    }
                }
                return result
            }
            if !longVideos.isEmpty {
                longVideoItems = longVideos
                showLongVideoWarning = true
                return
            }
        }

        await executeProcessing()
    }

    func confirmLongVideoProcessing() async {
        showLongVideoWarning = false
        await executeProcessing()
    }

    private func executeProcessing() async {
        await batchService.startBatch(items: mediaItems, settings: settings)
        showBatchResults = true
    }

    func cancelProcessing() {
        batchService.cancel()
    }

    // MARK: - Results

    func dismissBatchResults() {
        if settings.autoRemoveCompleted {
            let removeIDs = Set(batchService.tasks
                .filter { task in
                    if task.status.isCompleted { return true }
                    if !settings.keepFailedItems, case .failed = task.status { return true }
                    return false
                }
                .map { $0.mediaItem.id })
            mediaItems.removeAll { removeIDs.contains($0.id) }
            selectedItemIDs.subtract(removeIDs)
        }
        showBatchResults = false
    }

    func showOutputInFinder() {
        let outputURLs = batchService.tasks.compactMap { $0.result?.outputURL }
        guard !outputURLs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(outputURLs)
    }
}
