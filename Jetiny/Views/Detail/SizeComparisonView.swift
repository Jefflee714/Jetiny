import SwiftUI

struct SizeComparisonView: View {
    let item: MediaItem
    @State private var hasEXIF: Bool = false
    @State private var videoDuration: TimeInterval = 0

    var body: some View {
        GroupBox("檔案資訊") {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "檔案名稱", value: item.fileName)
                InfoRow(label: "檔案大小", value: item.formattedSize)
                if item.pixelWidth > 0 {
                    InfoRow(label: "解析度", value: item.dimensionText)
                    InfoRow(label: "像素數", value: String(format: "%.1f MP", item.megapixels))
                }
                InfoRow(label: "格式", value: item.url.pathExtension.uppercased())

                if item.mediaType == .video && videoDuration > 0 {
                    InfoRow(label: "時長", value: formatDuration(videoDuration))
                }

                if hasEXIF {
                    InfoRow(label: "EXIF", value: L( "包含 EXIF 資訊"))
                }
            }
            .padding(8)
        }
        .task(id: item.id) {
            hasEXIF = false
            videoDuration = 0

            let url = item.url
            if item.mediaType == .video {
                videoDuration = await VideoProcessingService.videoDuration(url: url)
            } else {
                hasEXIF = await Task.detached(priority: .low) {
                    MetadataService.hasEXIF(url: url)
                }.value
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return L( "\(secs) 秒")
    }
}

struct InfoRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}
