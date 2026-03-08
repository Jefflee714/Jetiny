import Foundation
import UniformTypeIdentifiers

@Observable
@MainActor
class BatchProcessingService {
    var tasks: [ProcessingTask] = []
    var overallProgress: Double = 0.0
    var isProcessing: Bool = false
    var completedCount: Int = 0
    var failedCount: Int = 0
    var totalCount: Int = 0

    private var isCancelled: Bool = false
    private var activityToken: NSObjectProtocol?
    private let imageService = ImageProcessingService()
    private let videoService = VideoProcessingService()

    // MARK: - Concurrency Control

    /// Determine max concurrency based on image sizes, RAW presence, and user settings
    private func maxConcurrency(for items: [MediaItem], settings: ConversionSettings) -> Int {
        // User manually set concurrency
        if settings.maxConcurrency > 0 {
            return settings.maxConcurrency
        }

        // Auto: RAW files use much more memory per pixel (16-bit), serialize them
        let hasRAW = items.contains { item in
            guard let utType = UTType(filenameExtension: item.url.pathExtension) else { return false }
            return utType.conforms(to: .rawImage)
        }

        let maxMP = items.compactMap({ $0.mediaType == .image ? $0.megapixels : nil }).max() ?? 0
        if hasRAW || maxMP > 30 { return 1 }
        if maxMP > 10 { return 2 }
        return 4
    }

    /// Check current process memory usage in MB
    private static func processMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = UInt32(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }

    // MARK: - Pre-checks

    /// Check if sufficient disk space is available
    func checkDiskSpace(items: [MediaItem], settings: ConversionSettings) -> Bool {
        let outputDir = settings.outputDirectoryURL ?? items.first?.url.deletingLastPathComponent()
        guard let dir = outputDir,
              let available = FileService.availableDiskSpace(at: dir) else { return true }
        let totalInputSize = items.reduce(Int64(0)) { $0 + $1.fileSize }
        return available > totalInputSize
    }

    // MARK: - Batch Processing

    func startBatch(items: [MediaItem], settings: ConversionSettings) async {
        isProcessing = true
        isCancelled = false
        completedCount = 0
        failedCount = 0
        tasks = items.map { ProcessingTask(mediaItem: $0) }
        totalCount = tasks.count
        overallProgress = 0.0

        // Prevent system sleep
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Jetiny batch processing"
        )

        let concurrency = maxConcurrency(for: items, settings: settings)
        let memoryBudget = Double(settings.effectiveMemoryMB)

        // Process with controlled concurrency
        await withTaskGroup(of: Void.self) { group in
            var taskIndex = 0

            for _ in 0..<min(concurrency, tasks.count) {
                let index = taskIndex
                taskIndex += 1
                group.addTask { [weak self] in
                    await self?.processTask(at: index, settings: settings)
                }
            }

            for await _ in group {
                if taskIndex < tasks.count && !isCancelled {
                    // Throttle if memory usage is high
                    if Self.processMemoryMB() > memoryBudget {
                        try? await Task.sleep(for: .milliseconds(500))
                    }

                    let index = taskIndex
                    taskIndex += 1
                    group.addTask { [weak self] in
                        await self?.processTask(at: index, settings: settings)
                    }
                }
            }
        }

        // End activity
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }

        isProcessing = false
    }

    // Already @MainActor — no need for MainActor.run wrappers
    private func processTask(at index: Int, settings: ConversionSettings) async {
        guard index < tasks.count else { return }
        let task = tasks[index]

        guard !isCancelled else {
            task.status = .cancelled
            return
        }

        // Check iCloud file availability
        if FileService.isCloudFileNotDownloaded(task.mediaItem.url) {
            task.status = .failed(error: "iCloud 檔案尚未下載，請先在 Finder 中下載此檔案")
            failedCount += 1
            updateOverallProgress()
            return
        }

        task.status = .processing(progress: 0.0)

        do {
            let result: ProcessingResult

            switch task.mediaItem.mediaType {
            case .image:
                result = try await imageService.processImage(
                    sourceURL: task.mediaItem.url,
                    settings: settings
                ) { progress in
                    Task { @MainActor in
                        task.status = .processing(progress: progress)
                    }
                }

            case .video:
                switch settings.outputVideoFormat {
                case .gif:
                    result = try await videoService.convertToGIF(
                        sourceURL: task.mediaItem.url,
                        settings: settings
                    ) { progress in
                        Task { @MainActor in
                            task.status = .processing(progress: progress)
                        }
                    }
                case .animatedWebP:
                    result = try await videoService.convertToAnimatedWebP(
                        sourceURL: task.mediaItem.url,
                        settings: settings
                    ) { progress in
                        Task { @MainActor in
                            task.status = .processing(progress: progress)
                        }
                    }
                }
            }

            task.status = .completed(result: result)
            completedCount += 1
            updateOverallProgress()
        } catch {
            task.status = .failed(error: error.localizedDescription)
            failedCount += 1
            updateOverallProgress()
        }
    }

    private func updateOverallProgress() {
        let done = tasks.filter {
            switch $0.status {
            case .completed, .failed, .cancelled: return true
            default: return false
            }
        }.count
        overallProgress = Double(done) / Double(max(totalCount, 1))
    }

    func cancel() {
        isCancelled = true
        for task in tasks {
            if case .pending = task.status {
                task.status = .cancelled
            }
        }
    }

    // MARK: - Results

    /// Total bytes saved across all completed tasks
    var totalSavedBytes: Int64 {
        tasks.compactMap { $0.result?.savedBytes }.reduce(0, +)
    }

    /// Total original size across all completed tasks
    var totalOriginalSize: Int64 {
        tasks.compactMap { $0.result?.originalSize }.reduce(0, +)
    }

    /// Total compressed size across all completed tasks
    var totalCompressedSize: Int64 {
        tasks.compactMap { $0.result?.compressedSize }.reduce(0, +)
    }
}
