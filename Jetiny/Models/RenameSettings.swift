import SwiftUI

// MARK: - Rename Mode

enum RenameMode: String, CaseIterable, Identifiable, Sendable, Equatable {
    case format
    case replaceText
    case addText

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .format: "格式化"
        case .replaceText: "取代文字"
        case .addText: "加入文字"
        }
    }
}

// MARK: - Format Settings (custom text + sequential number)

struct FormatSettings: Sendable, Equatable {
    var customText: String = ""
    var separator: String = "_"     // "_", "-", " ", ""
    var startNumber: Int = 1
    var digitCount: Int = 2         // 2=01, 3=001, 4=0001
}

// MARK: - Replace Text Settings (find → replace)

struct ReplaceTextSettings: Sendable, Equatable {
    var findText: String = ""
    var replaceText: String = ""
    var caseSensitive: Bool = false
}

// MARK: - Add Text Settings (prefix / suffix)

struct AddTextSettings: Sendable, Equatable {
    var prefix: String = ""
    var suffix: String = ""
}

// MARK: - Combined Settings

struct RenameSettings: Sendable, Equatable {
    var mode: RenameMode = .format
    var formatSettings = FormatSettings()
    var replaceSettings = ReplaceTextSettings()
    var addTextSettings = AddTextSettings()
}
