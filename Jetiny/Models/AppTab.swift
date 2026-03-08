import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case compression
    case rename

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .compression: "圖片壓縮"
        case .rename: "批次修改檔名"
        }
    }
}
