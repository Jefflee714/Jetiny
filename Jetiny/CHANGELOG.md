# Jetiny 版本歷史

## 版本規則

- `1.0` — 正式上線版本
- `0.X` — 大版本：大型 bug 修復、功能增加
- `0.x.X` — 小版本：小 bug 修復、微調
- 每個版本號範圍：1 ~ 99

---

## [1.0.2] - 2026-03-08

### 新增功能

- **多語系支援** — 新增中英雙語 String Catalog（184 個翻譯字串）
  - 繁體中文為基底語言，英文為 fallback
  - 非中文系統自動顯示英文介面
- **App 內語言切換** — 選單 Jetiny > 語言，可即時切換繁體中文 / English
  - 選擇後即時生效，不需重啟
  - 設定自動記憶（UserDefaults）
- **一般設定持久化** — 三個一般設定開關現在會記住使用者的選擇
  - 完成後自動移除已處理的檔案
  - 保留失敗的項目
  - 不顯示大圖片（>30MP）警告

### 其他

- 新增 GPL-3.0 LICENSE
- 新增中英雙語 README.md

---

## [1.0.1] - 2026-03-08

### 新增功能

- **一般設定** — 新增「一般設定」區塊，包含三個開關：
  - 完成後自動移除已處理的檔案（關閉結果面板時移除已完成項目）
  - 保留失敗的項目（子選項，可選擇失敗項目是否保留在列表中）
  - 不顯示大圖片（>30MP）警告
- **浮水印定位手指游標** — 9 宮格定位圓點 hover 時顯示手指游標

---

## [1.0] - 2026-03-08

### 里程碑

- 🎉 **正式版本發佈！** 包含圖片壓縮/轉檔、影片轉 GIF、浮水印、批次改名四大功能

---

## [0.4.3] - 2026-03-08

### 修正

- **圖片壓縮/轉檔輸出失敗** — 修復 v0.4.2 引入的 regression：`FileService.outputURL()` 的佔位檔案（placeholder）導致 `moveItem` 無法將暫存檔搬到最終位置（因為 `moveItem` 不能覆蓋已存在的檔案）。移除 placeholder 機制，僅保留 `NSLock` 確保並發安全

### 改進

- **WebP 編碼加速** — 三項優化顯著提升 WebP 轉檔速度：
  - `method` 從 4 降到 2（壓縮品質差異 <5%，速度提升 2-3 倍）
  - 啟用 `threadLevel = 1`（libwebp 多執行緒編碼）
  - 智慧像素格式偵測：偵測圖片原生格式（RGBA/BGRA），跳過不必要的全圖像素複製（`ensureRGBA`），macOS 常見的 BGRA 格式可直接傳入編碼器

---

## [0.4.2] - 2026-03-08

### 修正

- **Task 記憶體洩漏** — `PreviewComparisonView` 和 `SettingsPanel` 的 debounce task 在 view 消失時正確取消，防止離開畫面後仍佔用資源
- **BatchProcessingService 冗餘排程** — 清理已在 MainActor 上的方法內多餘的 `MainActor.run` 呼叫
- **浮水印圖片快取** — 平鋪模式下浮水印圖片只從磁碟載入一次，不再每個 tile 重複讀取（最多減少 400 次磁碟讀取）
- **GIF 記憶體保護** — 影片轉 GIF 時每 50 幀檢查記憶體用量，超過 1.5GB 自動停止擷取，防止低記憶體 Mac 當機
- **清除全部取消批次** — `clearAll()` 現在會取消正在進行的壓縮批次和重新命名操作
- **RenameViewModel 任務追蹤** — 重新命名和復原操作的 `Task.detached` 現在有 reference 可取消
- **FileService TOCTOU 競爭** — `outputURL()` 加入 `NSLock` 序列化 + placeholder 檔案保留，防止並發批次產生相同輸出路徑
- **maxWidth=0 防護** — 圖片和影片的最大寬度設定值 ≤ 0 時視為「不限制」，避免靜默錯誤
- **影片時長並行載入** — 批次開始前的長影片檢查改為 `withTaskGroup` 並行，大量影片時更快
- **磁碟同名檔案偵測** — 重新命名預覽階段即時檢查目標檔名是否在磁碟上已存在，以紅色標記 + ✕ 圖示警告，禁止開始重新命名

### 改進

- **檔案圖示快取** — 重新命名側邊欄的系統檔案圖示用 `@State` 快取，避免每次 SwiftUI 渲染都呼叫 `NSWorkspace.shared.icon`
- **極端設定警告** — 新增 UI 警示：
  - 品質 100% 時提示輸出可能比原圖更大
  - 幀率 ≥ 20fps 時提示 GIF 檔案會很大且佔記憶體
  - 最大寬度輸入 0 或負數自動清除為「不限制」

---

## [0.4.1] - 2026-03-08

### 改進

- **復原功能** — 重新命名執行後可一鍵還原所有變更
  - 結果面板提供「復原所有變更」按鈕
  - 側邊欄底部工具列顯示「復原」按鈕（僅在可復原時出現）
  - 反向執行 FileManager.moveItem 還原所有成功的重新命名
- **非法字元偵測** — 預覽階段即時偵測 `/` 和 `:` 等檔案系統非法字元
  - 含非法字元的檔案以紅色標記 + ✕ 圖示
  - 摘要區顯示紅色警告，禁止開始重新命名
- **檔名長度檢查** — 偵測新檔名是否超過 APFS 的 255 bytes 上限
  - 超長檔名以橘色標記 + ⚠️ 圖示（hover 顯示實際 bytes 數）
  - 摘要區顯示橘色警告
- **執行前確認** — 點擊「開始重新命名」後彈出確認對話框，顯示將重新命名的檔案數

---

## [0.4] - 2026-03-08

### 新增功能

- **批次修改檔名** — 全新 Tab 功能，與「圖片壓縮」並列切換
  - **支援所有檔案類型** — 不限圖片/影片，任何檔案皆可批次重新命名
  - **三種模式**：
    - **格式化** — 自訂文字 + 分隔符 + 流水號（可控制起始數字、位數 01/001/0001）
    - **取代文字** — 搜尋並取代檔名中的文字（留空=刪除文字，找不到則跳過）
    - **加入文字** — 在檔名前後加入前綴/後綴
  - **即時預覽表格** — 原始名稱 → 新名稱，設定變更後自動更新（100ms debounce）
  - **衝突偵測** — 同目錄多個檔案產生相同名稱時以橘色警告顯示，禁止執行
  - **空名偵測** — 重新命名後名稱為空時以紅色警告顯示
  - **跳過未改變** — 名稱未改變的檔案自動跳過
  - **執行結果** — 成功/失敗/跳過統計，失敗項目列出具體原因
  - **檔案管理** — 拖放匯入、右鍵選單移除、Delete 鍵刪除、hover X 按鈕
- **Tab 切換系統** — Toolbar 中央 segmented picker 切換「圖片壓縮」/「批次修改檔名」
- **個別檔案移除** — 壓縮 Tab 側邊欄支援 hover 顯示 X 按鈕移除單一檔案、Delete 鍵刪除選取項
- **條件式設定顯示** — 圖片設定和浮水印設定僅在有圖片時顯示，純影片時自動隱藏

### 技術細節

- `AppTab` 列舉：`.compression` / `.rename`，Toolbar segmented picker 切換
- `RenameItem` 模型：支援所有檔案類型，含 URL、檔名、副檔名、目錄（用於衝突偵測）
- `RenameSettings` 模型：三種模式各自獨立設定，全 Sendable + Equatable
- `RenameService`：純函數 preview 計算 + 衝突偵測 + 循序執行 FileManager.moveItem
- `RenameViewModel`：@Observable @MainActor，與 AppViewModel 平行注入
- `ContentView` 改為接收 `@Binding var activeTab` 以支援選單指令路由
- 選單指令（Cmd+O、Cmd+Shift+O、Cmd+Delete）根據當前 Tab 分派

---

## [0.3] - 2026-03-08

### 新增功能

- **浮水印功能** — Lightroom 風格浮水印支援
  - **文字浮水印** — 自訂文字、字體選擇、字體大小、粗細、顏色（ColorPicker）、陰影開關
  - **圖片浮水印** — 自選圖片檔案、大小調整（1-80% 圖片短邊）
  - **共用設定** — 透明度（0-100%）、邊距（0-20%）、9 宮格定位
  - 即時預覽 — 調整設定後自動更新壓縮預覽
  - 字體大小依圖片短邊等比縮放，跨解析度一致顯示
- **RAW 方向修正** — 修正 RAW 轉 JPEG/PNG 時 TIFF 子字典方向標籤導致二次旋轉

### 技術細節

- `WatermarkSettings` 資料模型：全 Sendable + Equatable，色彩用 RGBA Double 儲存
- `WatermarkService` 渲染引擎：Core Text + CGContext 合成，零第三方依賴
- 管線插入點：resize 之後、encode 之前，記憶體開銷與現有 resize 相同

---

## [0.2.1] - 2026-03-08

### 新增功能

- **RAW 圖片轉換** — 支援相機 RAW 格式（CR2、NEF、ARW、DNG、RAF、ORF 等）轉換為 JPEG/PNG/WebP
  - 強制全解析度 demosaic 解碼，不使用內嵌低解析度預覽
  - 自動處理 16-bit 高位元深度，轉為 8-bit sRGB 輸出
  - RAW 批次處理自動限制並發為 1，保護記憶體
- **效能設定** — 新增「效能設定」面板
  - 記憶體上限：0（自動，系統 RAM 的 5%）或 200-2000 MB 手動設定
  - 最大並發數：0（自動，依圖片大小智慧判斷）或 1-8 手動設定

### 改進

- `ImageProcessingService.loadImage` — RAW 偵測 + `kCGImageSourceThumbnailMaxPixelSize` 強制全解析度
- `ImageProcessingService.resizeImage` — 高位元深度自動降為 8-bit，避免 CGContext 失敗和記憶體暴增
- `BatchProcessingService` — 記憶體閾值和並發數改為可設定，不再硬編碼 400MB

---

## [0.2] - 2026-03-08

### 新增功能

- **影片 → GIF 轉換** — `VideoProcessingService.convertToGIF` 完整實作
  - 使用 `AVAssetImageGenerator` 逐幀擷取 + `CGImageDestination` 組裝 GIF
  - 支援自訂幀率（1-30 fps）和最大寬度
  - 無限循環播放（GIF loop count = 0）
  - 安全上限 1,000 幀，防止記憶體溢出
  - 原子寫入（暫存 → rename）
- **影片設定 UI** — `SettingsPanel` 新增影片設定區塊
  - 輸出格式選擇（GIF / WebP 動態）
  - 幀率滑桿（1-30 fps）
  - 影片最大寬度設定
  - 動態 WebP 尚未支援的警告提示
- **批次結果摘要** — 處理完成後顯示結果面板
  - 成功 / 失敗 / 已取消 計數
  - 總檔案大小變化及節省百分比
  - 失敗項目列表及具體原因
  - 「在 Finder 中顯示」按鈕，一鍵定位輸出檔案
- **影片時長顯示** — `SizeComparisonView` 選取影片時顯示時長
- **影片檔案資訊** — `DetailView` 支援顯示影片的檔案資訊

### 安全防護

- **記憶體壓力監控** — 批次處理中監測進程記憶體用量，超過 400MB 自動節流
- **磁碟空間預檢** — 開始批次前估算所需空間，不足時彈出提示
- **輸出目錄權限檢查** — 寫入前檢查權限，無權限時彈出錯誤提示
- **iCloud 檔案偵測** — `FileService.isCloudFileNotDownloaded` 偵測未下載的 iCloud 檔案，處理時跳過並提示使用者先下載
- **長影片警告** — 影片超過 30 秒時彈出提示，告知轉換 GIF 可能產生超大檔案

### 改進

- **設定面板重構** — 拆分為圖片設定、影片設定、輸出設定三個區塊，結構更清晰
- **批次處理支援影片** — `BatchProcessingService` 新增影片處理分支，依 `outputVideoFormat` 決定轉換方式

### 尚未實作

- 動態 WebP 輸出（Swift-WebP 套件尚未提供動畫編碼 API）
- vImage 硬體加速縮放

---

## [0.1.3] - 2026-03-08

### 安全性修正（CRITICAL）

- **修正拖放死鎖** — `handleDrop` 從 `DispatchSemaphore`（會造成 App 凍結）改為現代 `async/await` + `withTaskGroup`，消除死鎖和資料競爭
- **修正 fatalError** — `VideoProcessingService` 從 `fatalError()`（會造成 App 崩潰）改為 `throw` 錯誤
- **修正 force unwrap** — `ensureRGBA()` 中 `CGColorSpace(name:)!` 改為 `guard let`，避免罕見情況崩潰

### 效能修正（HIGH）

- **修正圖片載入** — `loadImage` 設定 `kCGImageSourceShouldCacheImmediately: false`，避免不必要的記憶體佔用
- **修正執行緒安全** — `ProcessingTask` 加上 `@MainActor` 隔離，`ProcessingStatus` 加上 `Sendable`，消除資料競爭
- **修正跨 actor 安全** — `ConversionSettings` 標記為 `Sendable`
- **修正主執行緒阻塞** — `SizeComparisonView` 的 EXIF 檢查從同步改為非同步 `.task`
- **修正無限掃描** — `FileService` 資料夾遞迴掃描加入 5,000 檔案上限，防止 OOM
- **修正檔名碰撞迴圈** — `outputURL` 碰撞避免迴圈加入 9,999 次上限

### 改進

- **檔案匯入非同步化** — `addFiles` 改為背景執行緒處理，匯入大量檔案時不凍結 UI
- **預覽最佳化** — 壓縮預覽限制最大 800px，節省記憶體和 CPU
- **暫存檔清理** — 預覽用暫存檔現在正確寫入 Jetiny 暫存目錄，App 啟動時統一清理
- **WebP 錯誤處理** — 新增 `webpEncodingFailed` 錯誤類型，WebP 編碼失敗時提供具體訊息

---

## [0.1.2] - 2026-03-08

### 新增

- **WebP 編碼支援** — 加入 [Swift-WebP](https://github.com/ainame/Swift-WebP) (v0.6.x) SPM 套件
- `ImageProcessingService` 新增 `encodeToWebP()` 方法，使用 libwebp `.photo` preset
- `ensureRGBA()` 輔助方法 — 將任意 CGImage 轉為標準 8-bit RGBA（WebP 編碼器要求）

### 改進

- **預覽對比功能** — `PreviewComparisonView` 完全重寫
  - 原圖 vs 壓縮後並排顯示
  - 壓縮後預覽即時生成（變更設定後 300ms debounce）
  - 顯示壓縮前後檔案大小及節省百分比
  - 設定變更時自動重新生成（品質、格式、寬度）
  - 載入/生成中顯示進度指示器

### 尚未實作

- 影片 → GIF / WebP 轉換
- vImage 硬體加速縮放
- 記憶體壓力監聽
- 進階錯誤處理（三級分類）

---

## [0.1.1] - 2026-03-08

### 新增

- 專案初始化，建立 Xcode 專案 (macOS 14+, SwiftUI)
- XcodeGen 配置，自動生成 `.xcodeproj`
- 停用 App Sandbox（非 App Store 發行）

### 資料模型

- `MediaItem` — 檔案資料模型（URL、大小、類型、像素尺寸、EXIF 方向修正）
- `ConversionSettings` — 壓縮設定（格式、品質、最大寬度、EXIF 開關、輸出路徑）
- `ProcessingTask` — 單一任務狀態追蹤（pending / processing / completed / failed / cancelled）
- `ProcessingResult` — 處理結果（前後大小對比、壓縮率計算）
- `SupportedFormat` — 輸出格式定義（PNG / JPEG / WebP / GIF）

### 服務層

- `FileService` — 檔案探索（支援資料夾遞迴）、隱藏檔過濾、輸出路徑生成（`_jetiny` 後綴 + 衝突自動加序號）、暫存目錄管理、磁碟空間檢查、權限檢查
- `MetadataService` — EXIF 讀取 / 移除（含 GPS、IPTC、Apple Maker 資訊）
- `ImageProcessingService` — 圖片載入（EXIF 方向自動修正）、CGContext 縮放（Lanczos）、PNG / JPG 編碼、原子寫入（暫存 → rename）、保留原始修改日期
- `BatchProcessingService` — 批次處理協調器、動態並發控制（依圖片大小：小圖 4 張 / 中圖 2 張 / 大圖 1 張）、進度追蹤、取消功能、系統休眠阻止
- `VideoProcessingService` — 預留框架（Phase 5 實作）

### 介面

- `ContentView` — 主佈局（NavigationSplitView 雙欄）
- `DropZoneView` — 拖放區域（支援檔案、多檔、資料夾，拖曳時視覺反饋）
- `FileListView` — 檔案列表（縮圖延遲載入、右鍵選單：移除 / 在 Finder 中顯示）
- `FileRowView` — 單列顯示（縮圖 + 檔名 + 大小 + 尺寸 + 格式標籤）
- `SettingsPanel` — 設定面板（格式選擇、品質滑桿、最大寬度、EXIF 開關、輸出路徑、JPEG 透明警告）
- `DetailView` — 右側面板（設定 + 預覽 + 檔案資訊）
- `PreviewComparisonView` — 圖片預覽（1024px 縮圖）
- `SizeComparisonView` — 檔案資訊顯示
- `ProcessingOverlayView` — 處理進度覆蓋層（進度條 + 當前檔名 + 完成/失敗計數 + 取消按鈕）

### 狀態管理

- `AppViewModel` — 檔案匯入（NSOpenPanel 檔案/資料夾）、拖放處理、超大圖片提示（>30MP）、批次啟動/取消、輸出目錄選擇

### 其他

- `.gitignore` 配置
- `Jetiny.entitlements`（停用沙盒）
- Asset Catalog（AppIcon、AccentColor）

### 尚未實作

- WebP 編碼（需加入 webp.swift 第三方庫）
- 影片 → GIF / WebP 轉換
- 前後預覽對比（壓縮後預覽）
- 記憶體壓力監聽
- 進階錯誤處理（三級分類）
