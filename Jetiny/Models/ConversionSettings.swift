import Foundation

struct ConversionSettings: Sendable {
    // Image settings
    var outputImageFormat: OutputImageFormat = .jpeg
    var quality: Double = 80.0  // 0-100
    var maxWidth: Int? = nil    // nil = keep original
    var stripEXIF: Bool = false

    // Video settings
    var outputVideoFormat: OutputVideoFormat = .gif
    var frameRate: Double = 10.0  // frames per second
    var videoMaxWidth: Int? = nil

    // Watermark
    var watermark: WatermarkSettings = WatermarkSettings()

    // Performance
    var maxMemoryMB: Int = 0        // 0 = auto (system RAM * 5%)
    var maxConcurrency: Int = 0     // 0 = auto (smart detection by image size)

    // General (persisted via UserDefaults)
    var autoRemoveCompleted: Bool = UserDefaults.standard.bool(forKey: "autoRemoveCompleted") {
        didSet { UserDefaults.standard.set(autoRemoveCompleted, forKey: "autoRemoveCompleted") }
    }
    var keepFailedItems: Bool = {
        UserDefaults.standard.object(forKey: "keepFailedItems") != nil
            ? UserDefaults.standard.bool(forKey: "keepFailedItems")
            : true  // default: true
    }() {
        didSet { UserDefaults.standard.set(keepFailedItems, forKey: "keepFailedItems") }
    }
    var disableLargeImageWarning: Bool = UserDefaults.standard.bool(forKey: "disableLargeImageWarning") {
        didSet { UserDefaults.standard.set(disableLargeImageWarning, forKey: "disableLargeImageWarning") }
    }

    // Output
    var outputDirectoryURL: URL? = nil  // nil = same directory as source

    /// Effective memory budget in MB (auto-detect if 0)
    var effectiveMemoryMB: Int {
        if maxMemoryMB > 0 { return maxMemoryMB }
        let systemRAM = ProcessInfo.processInfo.physicalMemory
        return max(200, Int(systemRAM / (1024 * 1024)) / 20)  // 5% of system RAM, min 200MB
    }

    /// Quality as 0.0-1.0 for Core Graphics APIs
    var qualityNormalized: CGFloat {
        CGFloat(quality / 100.0)
    }
}
