import SwiftUI

@main
struct JetinyApp: App {
    @State private var appVM = AppViewModel()
    @State private var renameVM = RenameViewModel()
    @State private var activeTab: AppTab = .compression
    @State private var showShortcuts = false
    @State private var langManager = LanguageManager.shared

    var body: some Scene {
        @Bindable var lm = langManager

        WindowGroup {
            ContentView(activeTab: $activeTab)
                .environment(appVM)
                .environment(renameVM)
                .environment(\.locale, langManager.locale)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    FileService.cleanupTempFiles()
                }
                .sheet(isPresented: $showShortcuts) {
                    ShortcutsView()
                        .environment(\.locale, langManager.locale)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L("開啟檔案...")) {
                    switch activeTab {
                    case .compression: appVM.openFilePicker()
                    case .rename: renameVM.openFilePicker()
                    }
                }
                .keyboardShortcut("o")

                Button(L("開啟資料夾...")) {
                    switch activeTab {
                    case .compression: appVM.openFolderPicker()
                    case .rename: renameVM.openFolderPicker()
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button(L("清除所有檔案")) {
                    switch activeTab {
                    case .compression: appVM.clearAll()
                    case .rename: renameVM.clearAll()
                    }
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(
                    activeTab == .compression
                        ? appVM.mediaItems.isEmpty
                        : renameVM.renameItems.isEmpty
                )
            }

            // About menu
            CommandGroup(replacing: .appInfo) {
                Button(L("關於 Jetiny")) {
                    showAboutPanel()
                }
            }

            // Language menu
            CommandGroup(after: .appInfo) {
                Picker(L("語言"), selection: $lm.language) {
                    ForEach(LanguageManager.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button(L("Jetiny 快捷鍵")) {
                    showShortcuts = true
                }

                Divider()

                Button(L("Jetalk 官網")) {
                    if let url = URL(string: "https://jetalk.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private func showAboutPanel() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2"

        let credits = NSAttributedString(
            string: L("圖片壓縮 · 影片轉 GIF · 批次改名") + "\n\n" + L("設計開發：Jetalk") + "\njetalk.com",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Jetiny",
            .applicationVersion: version,
            .credits: credits
        ])
    }
}

// MARK: - Shortcuts View

private struct ShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("快捷鍵")
                .font(.headline)
                .padding(.bottom, 16)

            Group {
                shortcutRow("開啟檔案", shortcut: "⌘O")
                shortcutRow("開啟資料夾", shortcut: "⇧⌘O")
                shortcutRow("清除所有檔案", shortcut: "⌘⌫")
                shortcutRow("刪除選取的檔案", shortcut: "Delete")
            }

            Divider()
                .padding(.vertical, 12)

            Text("Jetalk 設計開發")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            Button("jetalk.com") {
                if let url = URL(string: "https://jetalk.com") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)

            Spacer().frame(height: 16)

            Button("關閉") { dismiss() }
                .frame(maxWidth: .infinity, alignment: .center)
                .keyboardShortcut(.escape)
        }
        .padding(24)
        .frame(width: 340, height: 300)
    }

    private func shortcutRow(_ label: LocalizedStringKey, shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 6)
    }
}
