import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(RenameViewModel.self) private var renameVM
    @Binding var activeTab: AppTab

    var body: some View {
        @Bindable var vm = appVM

        NavigationSplitView {
            switch activeTab {
            case .compression:
                CompressionSidebarView()
                    .frame(minWidth: 250)
            case .rename:
                RenameSidebarView()
                    .frame(minWidth: 250)
            }
        } detail: {
            switch activeTab {
            case .compression:
                DetailView()
            case .rename:
                RenameDetailView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $activeTab) {
                    ForEach(AppTab.allCases) { tab in
                        Text(tab.localizedName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            switch activeTab {
            case .compression:
                return appVM.handleDrop(providers: providers)
            case .rename:
                return renameVM.handleDrop(providers: providers)
            }
        }
        .overlay {
            if activeTab == .compression
                && (appVM.batchService.isProcessing || appVM.showBatchResults) {
                ProcessingOverlayView()
            }
        }
        .alert("大圖片提示", isPresented: $vm.showLargeImageAlert) {
            Button("知道了") {
                appVM.showLargeImageAlert = false
            }
        } message: {
            let count = appVM.largeImageItems.count
            let maxMP = appVM.largeImageItems.map(\.megapixels).max() ?? 0
            Text("有 \(count) 張圖片超過 3000 萬像素（最大 \(String(format: "%.0f", maxMP))MP），建議先調整解析度以節省記憶體和加速處理。")
        }
        .alert("長影片提示", isPresented: $vm.showLongVideoWarning) {
            Button("繼續轉換") {
                Task { await appVM.confirmLongVideoProcessing() }
            }
            Button("取消", role: .cancel) { }
        } message: {
            let count = appVM.longVideoItems.count
            Text("有 \(count) 個影片超過 30 秒，轉換為 GIF 可能產生非常大的檔案。")
        }
        .alert("磁碟空間不足", isPresented: $vm.insufficientDiskSpace) {
            Button("知道了") { }
        } message: {
            Text("輸出目錄的可用空間可能不足，請清理磁碟或選擇其他輸出路徑。")
        }
        .alert("無法寫入", isPresented: $vm.showNotWritableError) {
            Button("知道了") { }
        } message: {
            Text("輸出目錄沒有寫入權限，請選擇其他輸出路徑。")
        }
    }
}

// MARK: - Compression Sidebar (renamed from SidebarView)

struct CompressionSidebarView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 0) {
            if appVM.mediaItems.isEmpty {
                DropZoneView()
            } else {
                FileListView()
            }

            Divider()

            // Bottom toolbar
            HStack {
                Button {
                    Task { await appVM.startProcessing() }
                } label: {
                    Label("開始轉換", systemImage: "play.fill")
                }
                .disabled(appVM.mediaItems.isEmpty || appVM.batchService.isProcessing)
                .buttonStyle(.borderedProminent)

                Spacer()

                Button {
                    appVM.clearAll()
                } label: {
                    Label("清除", systemImage: "trash")
                }
                .disabled(appVM.mediaItems.isEmpty)
            }
            .padding(10)
        }
    }
}
