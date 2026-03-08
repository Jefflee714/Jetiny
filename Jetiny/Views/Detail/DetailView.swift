import SwiftUI

struct DetailView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        if appVM.mediaItems.isEmpty {
            ContentUnavailableView {
                Label("尚未加入檔案", systemImage: "photo.on.rectangle.angled")
            } description: {
                Text("拖放圖片或影片到左側，或使用選單開啟檔案")
            }
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    SettingsPanel()

                    if let item = appVM.selectedItem {
                        if item.mediaType == .image {
                            PreviewComparisonView(item: item)
                        }
                        SizeComparisonView(item: item)
                    }
                }
                .padding(20)
            }
        }
    }
}
