import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsPanel: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var watermarkPreviewImage: NSImage?
    @State private var watermarkPreviewTask: Task<Void, Never>?
    @State private var isGeneratingPreview = false

    var body: some View {
        @Bindable var vm = appVM

        // Image settings (only when images are present)
        if appVM.hasImages {
        GroupBox("圖片設定") {
            VStack(alignment: .leading, spacing: 14) {
                // Output format
                HStack {
                    Text("輸出格式")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $vm.settings.outputImageFormat) {
                        ForEach(OutputImageFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Alpha warning for JPEG
                if appVM.settings.outputImageFormat == .jpeg {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("JPEG 不支援透明背景，透明區域會變成白色")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Quality slider (only for lossy formats)
                if appVM.settings.outputImageFormat.supportsQuality {
                    HStack {
                        Text("品質")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $vm.settings.quality, in: 1...100, step: 1)
                        Text("\(Int(appVM.settings.quality))%")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }

                    // Quality 100% warning
                    if appVM.settings.quality >= 100 {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Text("品質 100% 輸出檔案可能比原圖更大")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Max width
                HStack {
                    Text("最大寬度")
                        .frame(width: 80, alignment: .leading)
                    TextField("不限制", value: $vm.settings.maxWidth, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: appVM.settings.maxWidth) { _, newValue in
                            // Clamp invalid values: 0 or negative → nil (no limit)
                            if let v = newValue, v <= 0 {
                                appVM.settings.maxWidth = nil
                            }
                        }
                    Text("px")
                        .foregroundStyle(.secondary)
                    if appVM.settings.maxWidth != nil {
                        Button("清除") {
                            appVM.settings.maxWidth = nil
                        }
                        .font(.caption)
                    }
                }

                // Strip EXIF
                HStack {
                    Text("EXIF")
                        .frame(width: 80, alignment: .leading)
                    Toggle("移除 EXIF 資訊（GPS、裝置等）", isOn: $vm.settings.stripEXIF)
                        .toggleStyle(.checkbox)
                }
            }
            .padding(8)
        }
        }

        // Watermark settings (only when images are present)
        if appVM.hasImages {
        GroupBox("浮水印設定") {
            HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                // Mode picker
                HStack {
                    Text("浮水印")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $vm.settings.watermark.mode) {
                        ForEach(WatermarkMode.allCases) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if appVM.settings.watermark.mode != .none {

                    // --- Text-specific controls ---
                    if appVM.settings.watermark.mode == .text {
                        // Text input
                        HStack {
                            Text("文字")
                                .frame(width: 80, alignment: .leading)
                            TextField("浮水印文字", text: $vm.settings.watermark.textSettings.text)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Font family
                        HStack {
                            Text("字體")
                                .frame(width: 80, alignment: .leading)
                            Picker("", selection: $vm.settings.watermark.textSettings.fontName) {
                                ForEach(Self.commonFontNames, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .labelsHidden()
                        }

                        // Font size
                        HStack {
                            Text("字體大小")
                                .frame(width: 80, alignment: .leading)
                            Slider(value: $vm.settings.watermark.textSettings.fontSize, in: 12...200, step: 1)
                            Text("\(Int(appVM.settings.watermark.textSettings.fontSize))")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                        }

                        // Font weight
                        HStack {
                            Text("粗細")
                                .frame(width: 80, alignment: .leading)
                            Slider(value: $vm.settings.watermark.textSettings.fontWeight, in: -1...1, step: 0.1)
                            let w = appVM.settings.watermark.textSettings.fontWeight
                            Text(w < -0.3 ? LocalizedStringKey("細") : w > 0.3 ? LocalizedStringKey("粗") : LocalizedStringKey("標準"))
                                .frame(width: 40, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }

                        // Color
                        HStack {
                            Text("顏色")
                                .frame(width: 80, alignment: .leading)
                            ColorPicker("", selection: watermarkColorBinding)
                                .labelsHidden()
                        }

                        // Shadow
                        HStack {
                            Text("陰影")
                                .frame(width: 80, alignment: .leading)
                            Toggle("啟用文字陰影", isOn: $vm.settings.watermark.textSettings.shadowEnabled)
                                .toggleStyle(.checkbox)
                        }
                    }

                    // --- Image-specific controls ---
                    if appVM.settings.watermark.mode == .image {
                        // Image file picker
                        HStack {
                            Text("圖片")
                                .frame(width: 80, alignment: .leading)
                            if let url = appVM.settings.watermark.imageSettings.imageURL {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.secondary)
                                Button("清除") {
                                    appVM.settings.watermark.imageSettings.imageURL = nil
                                }
                                .font(.caption)
                            } else {
                                Text("未選擇")
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button("選擇...") {
                                selectWatermarkImage()
                            }
                        }

                        // Size
                        HStack {
                            Text("大小")
                                .frame(width: 80, alignment: .leading)
                            Slider(value: $vm.settings.watermark.imageSettings.sizePercent, in: 1...80, step: 1)
                            Text("\(Int(appVM.settings.watermark.imageSettings.sizePercent))%")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }

                    // --- Shared controls ---
                    // Opacity
                    HStack {
                        Text("透明度")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $vm.settings.watermark.opacity, in: 0...100, step: 1)
                        Text("\(Int(appVM.settings.watermark.opacity))%")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }

                    // Rotation
                    HStack {
                        Text("旋轉")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $vm.settings.watermark.rotation, in: -180...180, step: 1)
                        Text("\(Int(appVM.settings.watermark.rotation))°")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }

                    // Tile toggle
                    HStack {
                        Text("平鋪")
                            .frame(width: 80, alignment: .leading)
                        Toggle("重複鋪滿整張圖片", isOn: $vm.settings.watermark.tileEnabled)
                            .toggleStyle(.checkbox)
                    }

                    // Tile spacing (only when tiling)
                    if appVM.settings.watermark.tileEnabled {
                        HStack {
                            Text("間距")
                                .frame(width: 80, alignment: .leading)
                            Slider(value: $vm.settings.watermark.tileSpacingPercent, in: 5...50, step: 1)
                            Text("\(Int(appVM.settings.watermark.tileSpacingPercent))%")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }

                    // Margin (single mode only)
                    if !appVM.settings.watermark.tileEnabled {
                        HStack {
                            Text("邊距")
                                .frame(width: 80, alignment: .leading)
                            Slider(value: $vm.settings.watermark.marginPercent, in: 0...20, step: 0.5)
                            Text("\(String(format: "%.1f", appVM.settings.watermark.marginPercent))%")
                                .frame(width: 50, alignment: .trailing)
                                .monospacedDigit()
                        }

                        // Position (3x3 anchor grid, single mode only)
                        HStack(alignment: .top) {
                            Text("位置")
                                .frame(width: 80, alignment: .leading)
                            AnchorGridView(selectedAnchor: $vm.settings.watermark.anchor)
                        }
                    }
                }
            }

            // Watermark preview (right side)
            if appVM.settings.watermark.mode != .none {
                Divider()
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("預覽")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isGeneratingPreview {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    if let watermarkPreviewImage {
                        Image(nsImage: watermarkPreviewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.08))
                            .frame(minHeight: 120)
                            .overlay {
                                if isGeneratingPreview {
                                    ProgressView()
                                } else {
                                    Text("無圖片可預覽")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                    }
                }
                .frame(minWidth: 180, maxWidth: 280)
            }
            }
            .padding(8)
        }
        .onChange(of: appVM.settings.watermark) { _, _ in
            generateWatermarkPreview()
        }
        .task {
            generateWatermarkPreview()
        }
        .onDisappear {
            watermarkPreviewTask?.cancel()
            watermarkPreviewTask = nil
        }
        }

        // Video settings (only when videos are present)
        if appVM.hasVideos {
            GroupBox("影片設定") {
                VStack(alignment: .leading, spacing: 14) {
                    // Video output format
                    HStack {
                        Text("輸出格式")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $vm.settings.outputVideoFormat) {
                            ForEach(OutputVideoFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Animated WebP warning
                    if appVM.settings.outputVideoFormat == .animatedWebP {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text("動態 WebP 尚未支援，影片檔案將會處理失敗")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Frame rate
                    HStack {
                        Text("幀率")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $vm.settings.frameRate, in: 1...30, step: 1)
                        Text("\(Int(appVM.settings.frameRate)) fps")
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }

                    // High frame rate warning
                    if appVM.settings.frameRate >= 20 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("高幀率 GIF 會產生超大檔案並佔用大量記憶體")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Video max width
                    HStack {
                        Text("最大寬度")
                            .frame(width: 80, alignment: .leading)
                        TextField("不限制", value: $vm.settings.videoMaxWidth, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: appVM.settings.videoMaxWidth) { _, newValue in
                                if let v = newValue, v <= 0 {
                                    appVM.settings.videoMaxWidth = nil
                                }
                            }
                        Text("px")
                            .foregroundStyle(.secondary)
                        if appVM.settings.videoMaxWidth != nil {
                            Button("清除") {
                                appVM.settings.videoMaxWidth = nil
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(8)
            }
        }

        // Performance settings
        GroupBox("效能設定") {
            VStack(alignment: .leading, spacing: 14) {
                // Memory limit
                HStack {
                    Text("記憶體")
                        .frame(width: 80, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(appVM.settings.maxMemoryMB) },
                            set: { appVM.settings.maxMemoryMB = Int($0) }
                        ),
                        in: 0...2000,
                        step: 100
                    )
                    if appVM.settings.maxMemoryMB == 0 {
                        Text("自動 (\(appVM.settings.effectiveMemoryMB) MB)")
                            .frame(width: 120, alignment: .trailing)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(appVM.settings.maxMemoryMB) MB")
                            .frame(width: 120, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                // Max concurrency
                HStack {
                    Text("並發數")
                        .frame(width: 80, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(appVM.settings.maxConcurrency) },
                            set: { appVM.settings.maxConcurrency = Int($0) }
                        ),
                        in: 0...8,
                        step: 1
                    )
                    if appVM.settings.maxConcurrency == 0 {
                        Text("自動")
                            .frame(width: 120, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(appVM.settings.maxConcurrency)")
                            .frame(width: 120, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
            .padding(8)
        }

        // Output settings
        GroupBox("輸出設定") {
            VStack(alignment: .leading, spacing: 14) {
                // Output directory
                HStack {
                    Text("輸出路徑")
                        .frame(width: 80, alignment: .leading)
                    if let dir = appVM.settings.outputDirectoryURL {
                        Text(dir.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("清除") {
                            appVM.settings.outputDirectoryURL = nil
                        }
                        .font(.caption)
                    } else {
                        Text("與原始檔案相同")
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("選擇...") {
                        appVM.selectOutputDirectory()
                    }
                }

                // File count summary
                HStack {
                    Text("檔案數")
                        .frame(width: 80, alignment: .leading)
                    let imageCount = appVM.mediaItems.filter { $0.mediaType == .image }.count
                    let videoCount = appVM.mediaItems.filter { $0.mediaType == .video }.count
                    if imageCount > 0 {
                        Text("\(imageCount) 張圖片")
                            .foregroundStyle(.secondary)
                    }
                    if videoCount > 0 {
                        Text("\(videoCount) 個影片")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
        }

        // General settings
        GroupBox("一般設定") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("完成後自動移除已處理的檔案", isOn: $vm.settings.autoRemoveCompleted)
                    .toggleStyle(.checkbox)

                if appVM.settings.autoRemoveCompleted {
                    Toggle("保留失敗的項目", isOn: $vm.settings.keepFailedItems)
                        .toggleStyle(.checkbox)
                        .padding(.leading, 20)
                }

                Toggle("不顯示大圖片（>30MP）警告", isOn: $vm.settings.disableLargeImageWarning)
                    .toggleStyle(.checkbox)
            }
            .padding(8)
        }
    }

    // MARK: - Watermark Helpers

    private static let commonFontNames: [String] = [
        "Helvetica Neue", "Helvetica", "Arial", "Avenir", "Avenir Next",
        "Futura", "Georgia", "Gill Sans", "Menlo", "Monaco",
        "Optima", "Palatino", "Times New Roman", "Verdana"
    ]

    private var watermarkColorBinding: Binding<Color> {
        Binding(
            get: {
                let c = appVM.settings.watermark.textSettings.color
                return Color(red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
            },
            set: { newColor in
                if let components = NSColor(newColor).usingColorSpace(.sRGB) {
                    appVM.settings.watermark.textSettings.color = WatermarkColor(
                        red: Double(components.redComponent),
                        green: Double(components.greenComponent),
                        blue: Double(components.blueComponent),
                        alpha: Double(components.alphaComponent)
                    )
                }
            }
        )
    }

    private func selectWatermarkImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP]
        panel.message = L("選擇浮水印圖片")

        if panel.runModal() == .OK {
            appVM.settings.watermark.imageSettings.imageURL = panel.url
        }
    }

    // MARK: - Watermark Preview

    private var previewItemURL: URL? {
        appVM.mediaItems.first(where: { $0.mediaType == .image })?.url
    }

    private func generateWatermarkPreview() {
        watermarkPreviewTask?.cancel()
        watermarkPreviewTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            guard appVM.settings.watermark.mode != .none,
                  let url = previewItemURL else {
                watermarkPreviewImage = nil
                isGeneratingPreview = false
                return
            }

            isGeneratingPreview = true

            let settings = appVM.settings.watermark
            let result: NSImage? = await Task.detached(priority: .medium) {
                guard let thumbnail = CGImage.thumbnail(from: url, maxPixelSize: 400) else {
                    return nil
                }
                let watermarked = WatermarkService.applyWatermark(to: thumbnail, settings: settings)
                return NSImage(cgImage: watermarked)
            }.value

            if !Task.isCancelled {
                watermarkPreviewImage = result
                isGeneratingPreview = false
            }
        }
    }
}

// MARK: - Anchor Grid View

private struct AnchorGridView: View {
    @Binding var selectedAnchor: WatermarkAnchor

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let anchor = WatermarkAnchor.allCases.first { $0.row == row && $0.column == col }!
                        Circle()
                            .fill(selectedAnchor == anchor ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .onTapGesture { selectedAnchor = anchor }
                    }
                }
            }
        }
        .frame(width: 60, height: 60)
    }
}
