import SwiftUI

// MARK: - Rename Sidebar (file list + actions)

struct RenameSidebarView: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        VStack(spacing: 0) {
            if renameVM.renameItems.isEmpty {
                RenameDropZoneView()
            } else {
                RenameFileListView()
            }

            Divider()

            // Bottom toolbar
            HStack {
                Button {
                    renameVM.confirmStartRenaming()
                } label: {
                    Label("開始重新命名", systemImage: "pencil")
                }
                .disabled(
                    renameVM.renameItems.isEmpty
                    || renameVM.validCount == 0
                    || renameVM.hasConflicts
                    || renameVM.isProcessing
                    || renameVM.illegalCharsCount > 0
                    || renameVM.tooLongCount > 0
                    || renameVM.existsOnDiskCount > 0
                )
                .buttonStyle(.borderedProminent)

                if renameVM.canUndo {
                    Button {
                        Task { await renameVM.undoLastRename() }
                    } label: {
                        Label("復原", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(renameVM.isUndoing)
                }

                Spacer()

                Button {
                    renameVM.clearAll()
                } label: {
                    Label("清除", systemImage: "trash")
                }
                .disabled(renameVM.renameItems.isEmpty)
            }
            .padding(10)
        }
    }
}

// MARK: - Drop Zone (empty state)

private struct RenameDropZoneView: View {
    @Environment(RenameViewModel.self) private var renameVM
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("拖放任何檔案到這裡")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("支援所有檔案類型")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Button("選擇檔案") {
                    renameVM.openFilePicker()
                }
                Button("選擇資料夾") {
                    renameVM.openFolderPicker()
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .padding(8)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            renameVM.handleDrop(providers: providers)
        }
    }
}

// MARK: - File List

private struct RenameFileListView: View {
    @Environment(RenameViewModel.self) private var renameVM

    var body: some View {
        @Bindable var vm = renameVM

        List(selection: $vm.selectedItemIDs) {
            // Compact drop zone at top
            RenameDropZoneCompactView()
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))

            ForEach(renameVM.renameItems) { item in
                RenameFileRowView(item: item) {
                    withAnimation {
                        renameVM.renameItems.removeAll { $0.id == item.id }
                        renameVM.selectedItemIDs.remove(item.id)
                        renameVM.regeneratePreviews()
                    }
                }
                .tag(item.id)
                .contextMenu {
                    Button("移除") {
                        withAnimation {
                            renameVM.renameItems.removeAll { $0.id == item.id }
                            renameVM.selectedItemIDs.remove(item.id)
                            renameVM.regeneratePreviews()
                        }
                    }
                    Button("在 Finder 中顯示") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand {
            guard !renameVM.selectedItemIDs.isEmpty else { return }
            withAnimation {
                renameVM.removeSelected()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("開啟檔案...") { renameVM.openFilePicker() }
                    Button("開啟資料夾...") { renameVM.openFolderPicker() }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - Compact Drop Zone

private struct RenameDropZoneCompactView: View {
    @Environment(RenameViewModel.self) private var renameVM
    @State private var isTargeted = false

    var body: some View {
        HStack {
            Image(systemName: "plus.circle.dashed")
                .foregroundStyle(.secondary)
            Text("拖放更多檔案")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            renameVM.handleDrop(providers: providers)
        }
    }
}

// MARK: - File Row

struct RenameFileRowView: View {
    let item: RenameItem
    var onRemove: (() -> Void)?
    @State private var isHovered = false
    @State private var fileIcon: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            // System file icon (cached in @State to avoid per-render disk lookup)
            Image(nsImage: fileIcon ?? NSWorkspace.shared.icon(for: .data))
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.fileSize.formattedFileSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Extension badge
            if !item.fileExtension.isEmpty {
                Text(item.fileExtension.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

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
        .task(id: item.id) {
            fileIcon = NSWorkspace.shared.icon(forFile: item.url.path)
        }
    }
}
