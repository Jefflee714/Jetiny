# Jetiny

A lightweight macOS app for image compression, video-to-GIF conversion, watermarking, and batch file renaming.

macOS 輕量圖片壓縮工具，支援影片轉 GIF、自訂浮水印、批次修改檔名。

## Features / 功能

### Image Compression / 圖片壓縮
- Supports JPEG, PNG, WebP, TIFF, BMP, HEIC, RAW (CR2, NEF, ARW, DNG, etc.)
- Output formats: JPEG, PNG, WebP
- Adjustable quality (0–100%), max width, EXIF removal

### Video to GIF / 影片轉 GIF
- Frame rate 1–30 fps, max width control
- Memory-safe with 1.5 GB limit

### Watermark / 自訂浮水印
- Text watermark: custom font, size, weight, color, shadow
- Image watermark: adjustable size, opacity
- 9-position placement, rotation, tiling

### Batch Rename / 批次修改檔名
- Format (text + separator + sequence number)
- Find & replace
- Add prefix / suffix
- Live preview, conflict detection, undo support

## Requirements / 系統需求

- macOS 14.0+
- Optimized for 8 GB RAM Macs

## Download / 下載

Go to [Releases](../../releases) and download the latest `.zip` file.
Unzip and drag `Jetiny.app` to your Applications folder.

前往 [Releases](../../releases) 下載最新 `.zip`，解壓後將 `Jetiny.app` 拖到應用程式資料夾。

## Build from Source / 從原始碼編譯

### Prerequisites / 前置需求

- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
```

### Build / 編譯

```bash
git clone https://github.com/Jefflee714/Jetiny.git
cd Jetiny
xcodegen generate
open Jetiny.xcodeproj
```

Then build and run in Xcode (⌘R).

### Release Build / 發佈編譯

```bash
xcodegen generate
xcodebuild -project Jetiny.xcodeproj -scheme Jetiny -configuration Release build
```

## Localization / 多語系

Jetiny supports **Traditional Chinese** and **English**.
Switch language from the menu: **Jetiny > Language**.

Jetiny 支援**繁體中文**和**英文**，可從選單 **Jetiny > 語言** 切換。

### Add a New Language / 新增語言

Translations are managed in `Jetiny/Localizable.xcstrings` (JSON format).
To add a new language, simply add your translations to the file — no code changes needed.

翻譯集中在 `Jetiny/Localizable.xcstrings`（JSON 格式），新增語言只要加入翻譯，不需要改任何程式碼。

## License / 授權

This project is licensed under the [GNU General Public License v3.0](LICENSE).

本專案採用 [GPL-3.0 授權](LICENSE)。

## Author / 作者

Designed and developed by [Jetalk](https://jetalk.com)
