import SwiftUI

struct ProcessingOverlayView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            if appVM.batchService.isProcessing {
                ProgressPanel()
            } else {
                ResultsPanel()
            }
        }
    }
}

// MARK: - Progress Panel

private struct ProgressPanel: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 20) {
            Text("處理中...")
                .font(.title2)
                .fontWeight(.medium)

            // Current task info
            if let currentTask = appVM.batchService.tasks.first(where: {
                if case .processing = $0.status { return true }
                return false
            }) {
                Text(currentTask.mediaItem.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Overall progress
            ProgressView(value: appVM.batchService.overallProgress)
                .progressViewStyle(.linear)
                .frame(width: 300)

            // Stats
            HStack(spacing: 16) {
                let bs = appVM.batchService
                Text("已完成 \(bs.completedCount) / \(bs.totalCount)")
                    .font(.caption)
                if bs.failedCount > 0 {
                    Text("失敗 \(bs.failedCount)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Cancel button
            Button("取消") {
                appVM.cancelProcessing()
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 20)
        }
    }
}

// MARK: - Results Panel

private struct ResultsPanel: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        let bs = appVM.batchService

        VStack(spacing: 16) {
            // Status icon
            Image(systemName: bs.failedCount > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(bs.failedCount > 0 ? .orange : .green)

            Text("處理完成")
                .font(.title2)
                .fontWeight(.medium)

            // Summary stats
            HStack(spacing: 20) {
                StatBadge(value: "\(bs.completedCount)", label: "成功", color: .green)

                if bs.failedCount > 0 {
                    StatBadge(value: "\(bs.failedCount)", label: "失敗", color: .red)
                }

                let cancelledCount = bs.tasks.filter { $0.status == .cancelled }.count
                if cancelledCount > 0 {
                    StatBadge(value: "\(cancelledCount)", label: "已取消", color: .secondary)
                }
            }

            // Total savings
            if bs.totalOriginalSize > 0 && bs.completedCount > 0 {
                let savedPercent = Double(bs.totalSavedBytes) / Double(bs.totalOriginalSize) * 100
                HStack {
                    Text("\(bs.totalOriginalSize.formattedFileSize) → \(bs.totalCompressedSize.formattedFileSize)")
                    if savedPercent > 0 {
                        Text("(節省 \(String(format: "%.0f", savedPercent))%)")
                            .foregroundStyle(.green)
                    } else if savedPercent < 0 {
                        Text("(增大 \(String(format: "%.0f", -savedPercent))%)")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
            }

            // Failed items list
            let failedTasks = bs.tasks.filter { $0.status.isFailed }
            if !failedTasks.isEmpty {
                Divider()
                    .frame(width: 300)

                VStack(alignment: .leading, spacing: 4) {
                    Text("失敗項目：")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(failedTasks) { task in
                                HStack {
                                    Text(task.mediaItem.fileName)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(task.errorMessage ?? L("未知錯誤"))
                                        .foregroundStyle(.red)
                                }
                                .font(.caption2)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
                .frame(width: 300)
            }

            Divider()
                .frame(width: 300)

            // Action buttons
            HStack(spacing: 12) {
                if bs.completedCount > 0 {
                    Button("在 Finder 中顯示") {
                        appVM.showOutputInFinder()
                    }
                    .buttonStyle(.bordered)
                }

                Button("關閉") {
                    appVM.dismissBatchResults()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 20)
        }
    }
}

private struct StatBadge: View {
    let value: String
    let label: LocalizedStringKey
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
