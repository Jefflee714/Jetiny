import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("拖放圖片或影片到這裡")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("或使用選單 檔案 → 開啟檔案")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Button("選擇檔案") {
                    appVM.openFilePicker()
                }

                Button("選擇資料夾") {
                    appVM.openFolderPicker()
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
            appVM.handleDrop(providers: providers)
        }
    }
}
