

# TPASS.calc 語音快速記錄 UI/UX 減法重構 (V3)

## 1. 目標
將目前的「開發者除錯風格」介面重構為「消費者導向」的極簡體驗。
* **Magic Card 體驗**：辨識成功且信心高時，顯示極簡大卡片，一鍵儲存。
* **Focused Fill-in**：資訊不足時，僅針對缺漏欄位要求補填。
* **Advanced Editor**：僅在低信心或使用者要求修改時，才顯示複雜的列表。

---

## 2. 需修改檔案
* `VoiceQuickTripView.swift`: 核心視圖邏輯與狀態機。
* `VoiceSegmentEditorCard.swift`: 既有的編輯卡片（轉為進階模式使用）。

---

## 3. 實作需求指令

### A. 重構狀態機 (ViewPhase)
請在 `VoiceQuickTripView.swift` 中修改 `ViewPhase` enum，以支援新的分流邏輯：
```swift
enum ViewPhase {
    case ready
    case recording
    case parsing
    case simplePreview   // 👈 新增：完美命中時的極簡卡片
    case missingInfo     // 👈 新增：針對性補填模式
    case advancedEditor  // 👈 原本的 preview 重新命名
    case permissionDenied
    case fallbackManual
}
```

### B. 修改解析分流邏輯 (`parseTranscript`)
修改 `parseTranscript` 函數，根據 `ParsedTrip` 的狀態進行導向：
1.  **高信心 & 欄位齊全**：進入 `.simplePreview`。
2.  **中/高信心 & 缺漏必要欄位**：進入 `.missingInfo`。
3.  **多段轉乘 或 低信心**：進入 `.advancedEditor`。

### C. 建立極簡預覽視圖 (`simplePreviewContent`)
設計一個 `readyPhaseContent` 之後的新視圖：
* **視覺設計**：移除列表感，改為一張類似「票券」的大卡片。
* **大標題**：顯示 `起點站 ➔ 終點站`。
* **副標題**：顯示 `運具名稱 · 票價`。
* **按鈕**：
    * **主按鈕**：寬度佔滿的「確認儲存」按鈕。
    * **次按鈕**：文字連結「修改詳細內容」，點擊後切換至 `.advancedEditor`。
* **隱藏元素**：隱藏 `originalTranscript` 與所有百分比分數。

### D. 實作補填視窗 (`missingInfoContent`)
當 `phase == .missingInfo` 時：
* 判斷 `transportType`, `startStation`, `endStation` 哪項為空。
* 畫面上顯示大字提問：「請問您搭到哪一站？」或「請問是什麼交通工具？」。
* 提供對應的輸入框，填寫完畢後自動跳轉回 `.simplePreview`。

### E. 調整進階編輯器
* 將目前的 `previewPhaseContent` 內容移至 `advancedEditorContent`。
* 在視圖頂部加上「辨識結果可能有誤，請檢查以下段落」的提示字樣。
* 移除 `VoiceSegmentEditorCard` 內的 `confidenceBadge` (百分比標籤)。

---

## 4. 具體 UI 修正建議 (Agent 執行細節)

1.  **移除 AI 感**：在所有 `Simple` 與 `Advanced` 模式中，除非在 Debug 模式下，否則不應向用戶展示 `overallScore` 或各項細部 Score。
2.  **弱化原始文字**：使用者不需要核對自己的逐字稿。除非辨識完全失敗 (fallbackManual)，否則不主動顯示 `originalTranscript`。
3.  **成功動畫**：當進入 `simplePreview` 時，觸發一次 `HapticManager.shared.notification(type: .success)`。

---

## 5. 完成定義 (Definition of Done)
* [ ] 語音辨識出「北車到市政府 25 元」後，畫面應直接出現大卡片與大儲存按鈕。
* [ ] 使用者看不到任何信心分數百分比。
* [ ] 只有在複雜轉乘時，才會看到原本的多段列表。

***
