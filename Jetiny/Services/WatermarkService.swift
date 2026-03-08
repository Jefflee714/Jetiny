import Foundation
import CoreGraphics
import CoreText
import AppKit
import ImageIO

enum WatermarkService {

    // MARK: - Public API

    /// Apply watermark to a CGImage. Returns the original image if mode is .none.
    static func applyWatermark(to image: CGImage, settings: WatermarkSettings) -> CGImage {
        guard settings.mode != .none else { return image }
        guard settings.opacity > 0 else { return image }

        let width = image.width
        let height = image.height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }

        // Draw original image
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply global opacity for watermark
        let opacity = CGFloat(settings.opacity / 100.0)
        context.setAlpha(opacity)

        let imageWidth = CGFloat(width)
        let imageHeight = CGFloat(height)
        let shorterSide = min(imageWidth, imageHeight)
        let margin = shorterSide * CGFloat(settings.marginPercent / 100.0)
        let rotationRadians = CGFloat(settings.rotation) * .pi / 180.0

        if settings.tileEnabled {
            // Tiling mode: repeat watermark across entire image
            drawTiledWatermark(
                context: context,
                settings: settings,
                rotation: rotationRadians,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
        } else {
            // Single watermark mode
            switch settings.mode {
            case .text:
                drawSingleTextWatermark(
                    context: context,
                    settings: settings.textSettings,
                    anchor: settings.anchor,
                    margin: margin,
                    rotation: rotationRadians,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight
                )
            case .image:
                drawSingleImageWatermark(
                    context: context,
                    settings: settings.imageSettings,
                    anchor: settings.anchor,
                    margin: margin,
                    rotation: rotationRadians,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight
                )
            case .none:
                break
            }
        }

        return context.makeImage() ?? image
    }

    // MARK: - Tiled Watermark

    private static func drawTiledWatermark(
        context: CGContext,
        settings: WatermarkSettings,
        rotation: CGFloat,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        let shorterSide = min(imageWidth, imageHeight)
        let spacing = shorterSide * CGFloat(settings.tileSpacingPercent / 100.0)

        // Pre-load watermark image ONCE for tiling (avoid reloading from disk per tile)
        var preloadedImage: CGImage?
        if case .image = settings.mode {
            if let imageURL = settings.imageSettings.imageURL,
               let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
               let img = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                preloadedImage = img
            }
        }

        // Get watermark size for spacing calculation
        let wmSize: CGSize
        switch settings.mode {
        case .text:
            wmSize = textWatermarkSize(settings: settings.textSettings, shorterSide: shorterSide)
        case .image:
            wmSize = imageWatermarkSize(settings: settings.imageSettings, shorterSide: shorterSide)
        case .none:
            return
        }

        guard wmSize.width > 0, wmSize.height > 0 else { return }

        // Step size between tiles
        let stepX = wmSize.width + spacing
        let stepY = wmSize.height + spacing

        // Expand coverage area to handle rotation — when rotated,
        // we need to cover beyond the image bounds
        let diagonal = sqrt(imageWidth * imageWidth + imageHeight * imageHeight)
        let coverSize = diagonal * 1.5

        // Number of tiles needed
        let cols = Int(coverSize / stepX) + 2
        let rows = Int(coverSize / stepY) + 2

        // Center of image
        let cx = imageWidth / 2.0
        let cy = imageHeight / 2.0

        context.saveGState()

        // Rotate around center
        context.translateBy(x: cx, y: cy)
        context.rotate(by: rotation)
        context.translateBy(x: -cx, y: -cy)

        // Draw grid of watermarks centered on image
        let startX = cx - CGFloat(cols / 2) * stepX
        let startY = cy - CGFloat(rows / 2) * stepY

        for row in 0..<rows {
            for col in 0..<cols {
                let x = startX + CGFloat(col) * stepX
                let y = startY + CGFloat(row) * stepY

                switch settings.mode {
                case .text:
                    drawTextAt(
                        context: context,
                        settings: settings.textSettings,
                        position: CGPoint(x: x, y: y),
                        shorterSide: shorterSide
                    )
                case .image:
                    drawImageAtCached(
                        context: context,
                        settings: settings.imageSettings,
                        preloadedImage: preloadedImage,
                        position: CGPoint(x: x, y: y),
                        shorterSide: shorterSide
                    )
                case .none:
                    break
                }
            }
        }

        context.restoreGState()
    }

    // MARK: - Single Watermark (with rotation)

    private static func drawSingleTextWatermark(
        context: CGContext,
        settings: TextWatermarkSettings,
        anchor: WatermarkAnchor,
        margin: CGFloat,
        rotation: CGFloat,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        guard !settings.text.isEmpty else { return }

        let shorterSide = min(imageWidth, imageHeight)
        let wmSize = textWatermarkSize(settings: settings, shorterSide: shorterSide)
        let origin = anchorOrigin(
            anchor: anchor,
            watermarkSize: wmSize,
            margin: margin,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        // Rotate around the watermark center
        let centerX = origin.x + wmSize.width / 2.0
        let centerY = origin.y + wmSize.height / 2.0

        context.saveGState()
        if rotation != 0 {
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: rotation)
            context.translateBy(x: -centerX, y: -centerY)
        }

        drawTextAt(context: context, settings: settings, position: origin, shorterSide: shorterSide)
        context.restoreGState()
    }

    private static func drawSingleImageWatermark(
        context: CGContext,
        settings: ImageWatermarkSettings,
        anchor: WatermarkAnchor,
        margin: CGFloat,
        rotation: CGFloat,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        let shorterSide = min(imageWidth, imageHeight)
        let wmSize = imageWatermarkSize(settings: settings, shorterSide: shorterSide)
        guard wmSize.width > 0, wmSize.height > 0 else { return }

        let origin = anchorOrigin(
            anchor: anchor,
            watermarkSize: wmSize,
            margin: margin,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        let centerX = origin.x + wmSize.width / 2.0
        let centerY = origin.y + wmSize.height / 2.0

        context.saveGState()
        if rotation != 0 {
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: rotation)
            context.translateBy(x: -centerX, y: -centerY)
        }

        drawImageAt(context: context, settings: settings, position: origin, shorterSide: shorterSide)
        context.restoreGState()
    }

    // MARK: - Drawing Primitives

    /// Draw text watermark at a specific position
    private static func drawTextAt(
        context: CGContext,
        settings: TextWatermarkSettings,
        position: CGPoint,
        shorterSide: CGFloat
    ) {
        guard !settings.text.isEmpty else { return }

        let scaledFontSize = CGFloat(settings.fontSize) * shorterSide / 1000.0
        let weight = mapWeight(settings.fontWeight)

        let font: NSFont = {
            if let named = NSFont(name: settings.fontName, size: scaledFontSize) {
                let descriptor = named.fontDescriptor.addingAttributes([
                    .traits: [NSFontDescriptor.TraitKey.weight: weight]
                ])
                return NSFont(descriptor: descriptor, size: scaledFontSize) ?? named
            }
            return NSFont.systemFont(ofSize: scaledFontSize, weight: weight)
        }()

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: nsColor(from: settings.color)
        ]

        if settings.shadowEnabled {
            let shadow = NSShadow()
            shadow.shadowColor = nsColor(from: settings.shadowColor)
            shadow.shadowBlurRadius = CGFloat(settings.shadowBlurRadius) * shorterSide / 1000.0
            shadow.shadowOffset = NSSize(
                width: CGFloat(settings.shadowOffsetX) * shorterSide / 1000.0,
                height: CGFloat(settings.shadowOffsetY) * shorterSide / 1000.0
            )
            attributes[.shadow] = shadow
        }

        let attrString = NSAttributedString(string: settings.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        context.saveGState()
        context.textPosition = CGPoint(
            x: position.x - bounds.origin.x,
            y: position.y - bounds.origin.y
        )
        CTLineDraw(line, context)
        context.restoreGState()
    }

    /// Draw image watermark at a specific position (loads from disk)
    private static func drawImageAt(
        context: CGContext,
        settings: ImageWatermarkSettings,
        position: CGPoint,
        shorterSide: CGFloat
    ) {
        guard let imageURL = settings.imageURL,
              let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let watermarkImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return
        }
        drawImageAtCached(
            context: context,
            settings: settings,
            preloadedImage: watermarkImage,
            position: position,
            shorterSide: shorterSide
        )
    }

    /// Draw image watermark using a pre-loaded CGImage (avoids repeated disk reads in tiling)
    private static func drawImageAtCached(
        context: CGContext,
        settings: ImageWatermarkSettings,
        preloadedImage: CGImage?,
        position: CGPoint,
        shorterSide: CGFloat
    ) {
        guard let watermarkImage = preloadedImage else { return }

        let targetSize = shorterSide * CGFloat(settings.sizePercent / 100.0)
        let wmWidth = CGFloat(watermarkImage.width)
        let wmHeight = CGFloat(watermarkImage.height)
        guard wmWidth > 0, wmHeight > 0 else { return }

        let scale = targetSize / max(wmWidth, wmHeight)
        let drawWidth = wmWidth * scale
        let drawHeight = wmHeight * scale

        context.draw(
            watermarkImage,
            in: CGRect(x: position.x, y: position.y, width: drawWidth, height: drawHeight)
        )
    }

    // MARK: - Size Calculation

    private static func textWatermarkSize(settings: TextWatermarkSettings, shorterSide: CGFloat) -> CGSize {
        guard !settings.text.isEmpty else { return .zero }

        let scaledFontSize = CGFloat(settings.fontSize) * shorterSide / 1000.0
        let weight = mapWeight(settings.fontWeight)
        let font: NSFont = {
            if let named = NSFont(name: settings.fontName, size: scaledFontSize) {
                let descriptor = named.fontDescriptor.addingAttributes([
                    .traits: [NSFontDescriptor.TraitKey.weight: weight]
                ])
                return NSFont(descriptor: descriptor, size: scaledFontSize) ?? named
            }
            return NSFont.systemFont(ofSize: scaledFontSize, weight: weight)
        }()

        let attrString = NSAttributedString(
            string: settings.text,
            attributes: [.font: font]
        )
        let line = CTLineCreateWithAttributedString(attrString)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return bounds.size
    }

    private static func imageWatermarkSize(settings: ImageWatermarkSettings, shorterSide: CGFloat) -> CGSize {
        guard let imageURL = settings.imageURL,
              let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let watermarkImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .zero
        }

        let targetSize = shorterSide * CGFloat(settings.sizePercent / 100.0)
        let wmWidth = CGFloat(watermarkImage.width)
        let wmHeight = CGFloat(watermarkImage.height)
        guard wmWidth > 0, wmHeight > 0 else { return .zero }

        let scale = targetSize / max(wmWidth, wmHeight)
        return CGSize(width: wmWidth * scale, height: wmHeight * scale)
    }

    // MARK: - Position Calculation

    private static func anchorOrigin(
        anchor: WatermarkAnchor,
        watermarkSize: CGSize,
        margin: CGFloat,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGPoint {
        let x: CGFloat
        let y: CGFloat

        switch anchor.column {
        case 0:  x = margin
        case 1:  x = (imageWidth - watermarkSize.width) / 2.0
        default: x = imageWidth - watermarkSize.width - margin
        }

        switch anchor.row {
        case 0:  y = imageHeight - watermarkSize.height - margin
        case 1:  y = (imageHeight - watermarkSize.height) / 2.0
        default: y = margin
        }

        return CGPoint(x: x, y: y)
    }

    // MARK: - Helpers

    private static func nsColor(from color: WatermarkColor) -> NSColor {
        NSColor(
            red: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.alpha)
        )
    }

    private static func mapWeight(_ value: Double) -> NSFont.Weight {
        let clamped = max(-1, min(1, value))
        return NSFont.Weight(rawValue: CGFloat(clamped * 0.62))
    }
}
