import SwiftUI

struct FileRowView: View {
    let item: MediaItem
    var onRemove: (() -> Void)?
    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: item.mediaType == .video ? "film" : "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(item.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if item.mediaType == .image && item.pixelWidth > 0 {
                        Text(item.dimensionText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Type badge
            Text(item.url.pathExtension.uppercased())
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Remove button (visible on hover)
            Button {
                onRemove?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 0.8 : 0)
            .allowsHitTesting(isHovered)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .task {
            if item.mediaType == .image {
                thumbnail = await loadThumbnail()
            }
        }
    }

    private func loadThumbnail() async -> NSImage? {
        await Task.detached(priority: .low) {
            NSImage.thumbnail(from: item.url, maxPixelSize: 72)
        }.value
    }
}
