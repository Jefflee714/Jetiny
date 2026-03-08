import SwiftUI

struct FileListView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        @Bindable var vm = appVM

        List(selection: $vm.selectedItemIDs) {
            // Drop zone at top
            DropZoneCompactView()
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))

            ForEach(appVM.mediaItems) { item in
                FileRowView(item: item) {
                    withAnimation {
                        appVM.mediaItems.removeAll { $0.id == item.id }
                        appVM.selectedItemIDs.remove(item.id)
                    }
                }
                    .tag(item.id)
                    .contextMenu {
                        Button("移除") {
                            withAnimation {
                                appVM.mediaItems.removeAll { $0.id == item.id }
                                appVM.selectedItemIDs.remove(item.id)
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
            guard !appVM.selectedItemIDs.isEmpty else { return }
            withAnimation {
                appVM.removeSelected()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("開啟檔案...") { appVM.openFilePicker() }
                    Button("開啟資料夾...") { appVM.openFolderPicker() }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

/// Compact drop zone shown at the top of the file list
struct DropZoneCompactView: View {
    @Environment(AppViewModel.self) private var appVM
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
            appVM.handleDrop(providers: providers)
        }
    }
}
