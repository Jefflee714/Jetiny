import SwiftUI

struct RenameDetailView: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        @Bindable var vm = renameVM

        ZStack {
            if renameVM.renameItems.isEmpty {
                ContentUnavailableView {
                    Label("尚未加入檔案", systemImage: "pencil.and.list.clipboard")
                } description: {
                    Text("拖放檔案到左側，或使用選單開啟檔案")
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        RenameSettingsPanel()
                        RenamePreviewTable()
                    }
                    .padding(20)
                }
                .onChange(of: renameVM.settings) { _, _ in
                    renameVM.regeneratePreviews()
                }
            }

            // Results overlay
            if renameVM.isProcessing || renameVM.showResults {
                RenameResultsOverlay()
            }
        }
        .alert("確認重新命名", isPresented: $vm.showConfirmAlert) {
            Button("開始重新命名", role: .destructive) {
                Task { await renameVM.startRenaming() }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("即將重新命名 \(renameVM.validCount) 個檔案，此操作執行後可使用「復原」按鈕還原。確定要繼續嗎？")
        }
    }
}

// MARK: - Settings Panel

private struct RenameSettingsPanel: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        @Bindable var vm = renameVM

        GroupBox("重新命名設定") {
            VStack(alignment: .leading, spacing: 14) {
                // Mode picker
                HStack {
                    Text("模式")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $vm.settings.mode) {
                        ForEach(RenameMode.allCases) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Divider()

                // Mode-specific controls
                switch renameVM.settings.mode {
                case .format:
                    FormatSettingsSection()
                case .replaceText:
                    ReplaceTextSettingsSection()
                case .addText:
                    AddTextSettingsSection()
                }
            }
            .padding(8)
        }

        // Summary
        GroupBox("摘要") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("檔案總數")
                        .frame(width: 100, alignment: .leading)
                    Text("\(renameVM.renameItems.count)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                HStack {
                    Text("將重新命名")
                        .frame(width: 100, alignment: .leading)
                    Text("\(renameVM.validCount)")
                        .foregroundStyle(renameVM.validCount > 0 ? .primary : .secondary)
                }
                .font(.caption)

                if renameVM.skippedCount > 0 {
                    HStack {
                        Text("將跳過")
                            .frame(width: 100, alignment: .leading)
                        Text("\(renameVM.skippedCount)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if renameVM.unchangedCount > 0 && renameVM.skippedCount == 0 {
                    HStack {
                        Text("未改變")
                            .frame(width: 100, alignment: .leading)
                        Text("\(renameVM.unchangedCount)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if renameVM.conflictCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(renameVM.conflictCount) 個檔案有名稱衝突，無法開始")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }

                if renameVM.existsOnDiskCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("\(renameVM.existsOnDiskCount) 個目標檔名在磁碟上已存在，無法開始")
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                }

                if renameVM.emptyCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("\(renameVM.emptyCount) 個檔案重新命名後名稱為空")
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                }

                if renameVM.illegalCharsCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("\(renameVM.illegalCharsCount) 個檔案名稱含有非法字元（/ 或 :），無法開始")
                            .foregroundStyle(.red)
                    }
                    .font(.caption)
                }

                if renameVM.tooLongCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(renameVM.tooLongCount) 個檔案名稱超過 255 bytes 上限")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Format Mode Settings

private struct FormatSettingsSection: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        @Bindable var vm = renameVM

        // Custom text
        HStack {
            Text("名稱")
                .frame(width: 80, alignment: .leading)
            TextField("輸入新檔名", text: $vm.settings.formatSettings.customText)
                .textFieldStyle(.roundedBorder)
        }

        // Separator
        HStack {
            Text("分隔符")
                .frame(width: 80, alignment: .leading)
            Picker("", selection: $vm.settings.formatSettings.separator) {
                Text("底線 _").tag("_")
                Text("連字號 -").tag("-")
                Text("空格").tag(" ")
                Text("無").tag("")
            }
            .labelsHidden()
            .frame(width: 150)
        }

        // Start number
        HStack {
            Text("起始數字")
                .frame(width: 80, alignment: .leading)
            TextField("", value: $vm.settings.formatSettings.startNumber, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
        }

        // Digit count
        HStack {
            Text("位數")
                .frame(width: 80, alignment: .leading)
            Picker("", selection: $vm.settings.formatSettings.digitCount) {
                Text("1 (1, 2, 3)").tag(1)
                Text("2 (01, 02)").tag(2)
                Text("3 (001, 002)").tag(3)
                Text("4 (0001, 0002)").tag(4)
            }
            .labelsHidden()
            .frame(width: 200)
        }
    }
}

// MARK: - Replace Text Mode Settings

private struct ReplaceTextSettingsSection: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        @Bindable var vm = renameVM

        HStack {
            Text("搜尋")
                .frame(width: 80, alignment: .leading)
            TextField("要尋找的文字", text: $vm.settings.replaceSettings.findText)
                .textFieldStyle(.roundedBorder)
        }

        HStack {
            Text("取代為")
                .frame(width: 80, alignment: .leading)
            TextField("取代文字（留空=刪除）", text: $vm.settings.replaceSettings.replaceText)
                .textFieldStyle(.roundedBorder)
        }

        HStack {
            Text("")
                .frame(width: 80, alignment: .leading)
            Toggle("區分大小寫", isOn: $vm.settings.replaceSettings.caseSensitive)
                .toggleStyle(.checkbox)
        }

        if renameVM.settings.replaceSettings.findText.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("請輸入要搜尋的文字")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}

// MARK: - Add Text Mode Settings

private struct AddTextSettingsSection: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        @Bindable var vm = renameVM

        HStack {
            Text("前綴")
                .frame(width: 80, alignment: .leading)
            TextField("加在檔名前面", text: $vm.settings.addTextSettings.prefix)
                .textFieldStyle(.roundedBorder)
        }

        HStack {
            Text("後綴")
                .frame(width: 80, alignment: .leading)
            TextField("加在檔名後面（副檔名之前）", text: $vm.settings.addTextSettings.suffix)
                .textFieldStyle(.roundedBorder)
        }

        if renameVM.settings.addTextSettings.prefix.isEmpty
            && renameVM.settings.addTextSettings.suffix.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("請輸入前綴或後綴")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}

// MARK: - Preview Table

private struct RenamePreviewTable: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        GroupBox("預覽") {
            if renameVM.previews.isEmpty {
                Text("加入檔案後顯示預覽")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("原始名稱")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("")
                            .frame(width: 30)
                        Text("新名稱")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                    Divider()

                    // Rows (scrollable)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(renameVM.previews) { preview in
                                RenamePreviewRow(preview: preview)
                                Divider()
                            }
                        }
                    }
                    .frame(minHeight: 150, maxHeight: 400)
                }
            }
        }
    }
}

// MARK: - Preview Row

private struct RenamePreviewRow: View {
    let preview: RenamePreview

    var body: some View {
        HStack {
            // Original name
            Text(preview.item.fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(preview.isSkipped ? .tertiary : .secondary)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 30)

            // New name
            HStack(spacing: 4) {
                if preview.isSkipped {
                    Text("（跳過）")
                        .foregroundStyle(.secondary)
                } else if preview.isEmpty {
                    Text("（名稱為空）")
                        .foregroundStyle(.red)
                } else if preview.hasIllegalChars {
                    Text(preview.newName)
                        .foregroundStyle(.red)
                } else if preview.isTooLong {
                    Text(preview.newName)
                        .foregroundStyle(.orange)
                } else if preview.isUnchanged {
                    Text(preview.newName)
                        .foregroundStyle(.tertiary)
                } else if preview.existsOnDisk {
                    Text(preview.newName)
                        .foregroundStyle(.red)
                } else {
                    Text(preview.newName)
                        .foregroundStyle(preview.hasConflict ? .orange : .primary)
                }

                if preview.hasConflict {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if preview.existsOnDisk {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .help("磁碟上已存在同名檔案")
                }
                if preview.hasIllegalChars {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .help("檔名含有非法字元（/ 或 :）")
                }
                if preview.isTooLong {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .help("檔名超過 255 bytes 上限（\(preview.newName.utf8.count) bytes）")
                }
            }
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            if preview.hasIllegalChars || preview.existsOnDisk {
                Color.red.opacity(0.05)
            } else if preview.hasConflict || preview.isTooLong {
                Color.orange.opacity(0.05)
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Results Overlay

private struct RenameResultsOverlay: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if renameVM.isProcessing {
                    // Processing state
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("正在重新命名...")
                            .font(.headline)
                    }
                } else {
                    // Results state
                    let successCount = renameVM.successCount
                    let failedResults = renameVM.failedResults
                    let skippedInResults = renameVM.results.filter {
                        if case .skipped = $0.status { return true } else { return false }
                    }.count

                    // Status icon
                    Image(systemName: failedResults.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(failedResults.isEmpty ? .green : .orange)

                    Text("重新命名完成")
                        .font(.headline)

                    // Stats
                    HStack(spacing: 16) {
                        if successCount > 0 {
                            Label("\(successCount) 成功", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                        if !failedResults.isEmpty {
                            Label("\(failedResults.count) 失敗", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                        if skippedInResults > 0 {
                            Label("\(skippedInResults) 跳過", systemImage: "minus.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)

                    // Failed items list
                    if !failedResults.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("失敗項目：")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(failedResults.prefix(5)) { result in
                                HStack {
                                    Text(result.originalURL.lastPathComponent)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if case .failed(let error) = result.status {
                                        Text("— \(error)")
                                            .foregroundStyle(.red)
                                    }
                                }
                                .font(.caption2)
                            }

                            if failedResults.count > 5 {
                                Text("... 還有 \(failedResults.count - 5) 個")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    HStack(spacing: 12) {
                        Button("完成") {
                            renameVM.dismissResults()
                        }
                        .buttonStyle(.borderedProminent)

                        if renameVM.canUndo && successCount > 0 {
                            Button {
                                Task {
                                    renameVM.dismissResults()
                                    await renameVM.undoLastRename()
                                }
                            } label: {
                                Label("復原所有變更", systemImage: "arrow.uturn.backward")
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(minWidth: 360)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
        }
    }
}
