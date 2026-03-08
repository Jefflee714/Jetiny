import SwiftUI

// MARK: - Watermark Mode

enum WatermarkMode: String, CaseIterable, Identifiable, Sendable, Equatable {
    case none
    case text
    case image

    var id: String { rawValue }

    var localizedName: LocalizedStringKey {
        switch self {
        case .none: "無"
        case .text: "文字"
        case .image: "圖片"
        }
    }
}

// MARK: - Anchor Position (3x3 grid)

enum WatermarkAnchor: String, CaseIterable, Identifiable, Sendable, Equatable {
    case topLeft, topCenter, topRight
    case centerLeft, center, centerRight
    case bottomLeft, bottomCenter, bottomRight

    var id: String { rawValue }

    var row: Int {
        switch self {
        case .topLeft, .topCenter, .topRight: return 0
        case .centerLeft, .center, .centerRight: return 1
        case .bottomLeft, .bottomCenter, .bottomRight: return 2
        }
    }

    var column: Int {
        switch self {
        case .topLeft, .centerLeft, .bottomLeft: return 0
        case .topCenter, .center, .bottomCenter: return 1
        case .topRight, .centerRight, .bottomRight: return 2
        }
    }
}

// MARK: - Sendable Color (RGBA 0-1)

struct WatermarkColor: Sendable, Equatable {
    var red: Double = 1.0
    var green: Double = 1.0
    var blue: Double = 1.0
    var alpha: Double = 1.0

    static let white = WatermarkColor(red: 1, green: 1, blue: 1, alpha: 1)
    static let black = WatermarkColor(red: 0, green: 0, blue: 0, alpha: 1)
}

// MARK: - Text Watermark Settings

struct TextWatermarkSettings: Sendable, Equatable {
    var text: String = "Jetiny"
    var fontName: String = "Helvetica Neue"
    var fontSize: Double = 48.0          // base size, scaled relative to image
    var fontWeight: Double = 0.0         // -1.0 (thin) to 1.0 (black)
    var color: WatermarkColor = .white
    var shadowEnabled: Bool = true
    var shadowColor: WatermarkColor = WatermarkColor(red: 0, green: 0, blue: 0, alpha: 0.6)
    var shadowBlurRadius: Double = 4.0
    var shadowOffsetX: Double = 2.0
    var shadowOffsetY: Double = -2.0     // negative = downward in CG coords
}

// MARK: - Image Watermark Settings

struct ImageWatermarkSettings: Sendable, Equatable {
    var imageURL: URL? = nil
    var sizePercent: Double = 20.0       // 1-80, % of image shorter side
}

// MARK: - Combined Watermark Settings

struct WatermarkSettings: Sendable, Equatable {
    var mode: WatermarkMode = .none
    var anchor: WatermarkAnchor = .bottomRight
    var marginPercent: Double = 3.0      // 0-20, % of image dimensions
    var opacity: Double = 100.0          // 0-100
    var rotation: Double = 0.0           // degrees, -180 to 180
    var tileEnabled: Bool = false        // repeat across entire image
    var tileSpacingPercent: Double = 15.0 // 5-50, spacing between tiles as % of shorter side

    var textSettings: TextWatermarkSettings = TextWatermarkSettings()
    var imageSettings: ImageWatermarkSettings = ImageWatermarkSettings()
}
