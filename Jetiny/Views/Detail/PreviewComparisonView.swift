import SwiftUI

struct PreviewComparisonView: View {
    let item: MediaItem
    @Environment(AppViewModel.self) private var appVM
    @State private var originalImage: NSImage?
    @State private var compressedImage: NSImage?
    @State private var compressedSize: Int64?
    @State private var debounceTask: Task<Void, Never>?
    @State private var isGenerating = false

    var body: some View {
        GroupBox("預覽對比") {
            VStack(spacing: 12) {
                if originalImage != nil || compressedImage != nil {
                    HStack(spacing: 16) {
                        // Original
                        VStack(spacing: 4) {
                            Text("原圖")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let originalImage {
                                Image(nsImage: originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            Text(item.formattedSize)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)

                        // Compressed
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Text("壓縮後")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if isGenerating {
                                    ProgressView()
                                        .controlSize(.mini)
                                }
                            }
                            if let compressedImage {
                                Image(nsImage: compressedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay {
                                        if isGenerating {
                                            ProgressView()
                                        } else {
                                            Text("調整設定後顯示")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                            }
                            if let compressedSize {
                                Text(compressedSize.formattedFileSize)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Savings summary
                    if let compressedSize, item.fileSize > 0 {
                        let saved = Double(item.fileSize - compressedSize) / Double(item.fileSize) * 100
                        HStack {
                            Text("\(item.formattedSize) → \(compressedSize.formattedFileSize)")
                            if saved > 0 {
                                Text("(節省 \(String(format: "%.0f", saved))%)")
                                    .foregroundStyle(.green)
                            } else {
                                Text("(增大 \(String(format: "%.0f", -saved))%)")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                    }
                } else {
                    ProgressView()
                        .frame(height: 200)
                }
            }
            .padding(4)
        }
        .task(id: item.id) {
            originalImage = await loadThumbnail()
            await generateCompressedPreview()
        }
        .onChange(of: appVM.settings.quality) { _, _ in debouncedGenerate() }
        .onChange(of: appVM.settings.outputImageFormat) { _, _ in debouncedGenerate() }
        .onChange(of: appVM.settings.maxWidth) { _, _ in debouncedGenerate() }
        .onChange(of: appVM.settings.watermark) { _, _ in debouncedGenerate() }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
        }
    }

    private func debouncedGenerate() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await generateCompressedPreview()
        }
    }

    private func loadThumbnail() async -> NSImage? {
        let url = item.url
        return await Task.detached(priority: .medium) {
            NSImage.thumbnail(from: url, maxPixelSize: 512)
        }.value
    }

    private func generateCompressedPreview() async {
        isGenerating = true
        defer { isGenerating = false }

        let settings = appVM.settings
        let url = item.url
        let previewTempDir = FileService.tempDirectory

        let result: (NSImage?, Int64?) = await Task.detached(priority: .medium) {
            let service = ImageProcessingService()

            // Cap preview resolution to 800px to save memory and CPU
            let previewMaxWidth = min(settings.maxWidth ?? 800, 800)

            do {
                let result = try await service.processImage(
                    sourceURL: url,
                    settings: ConversionSettings(
                        outputImageFormat: settings.outputImageFormat,
                        quality: settings.quality,
                        maxWidth: previewMaxWidth,
                        stripEXIF: settings.stripEXIF,
                        watermark: settings.watermark,
                        outputDirectoryURL: previewTempDir
                    ),
                    progressHandler: { _ in }
                )

                let image = NSImage(contentsOf: result.outputURL)
                let size = result.compressedSize

                // Clean up temp file immediately
                try? FileManager.default.removeItem(at: result.outputURL)

                return (image, size)
            } catch {
                return (nil, nil)
            }
        }.value

        compressedImage = result.0
        compressedSize = result.1
    }
}
