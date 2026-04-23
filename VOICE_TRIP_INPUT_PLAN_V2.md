# TPASS.calc 語音快速記錄 V2 升級計畫 (支援轉乘與多段行程)

## 1. 核心目標與場景
* **解鎖複雜句型**：允許使用者一口氣唸出完整通勤路線，例如「搭捷運從北車到淡水，然後轉 860 公車到三芝」。
* **智慧上下文推斷**：當使用者省略起點時（例如「轉 860 到三芝」），系統能自動將「上一段行程的終點（淡水）」帶入為「下一段行程的起點」。
* **轉乘優惠自動化**：偵測到多段行程時，自動將第二段以後的行程標記為「轉乘 (isTransfer)」，並依據使用者身份套用預設轉乘優惠。
* **UI 陣列化預覽**：在確認頁面中，以「時間軸 (Timeline)」或「卡片列表」的形式，讓使用者一次預覽並分別編輯多段草稿，最後一鍵「全部儲存」。

---

## 2. 資料模型與介面升級 (Data Model & API)

目前的 `TripVoiceParser` 回傳單一 `ParsedTrip`，`VoiceQuickTripView` 綁定單一 `VoiceDraft`。V2 需要將其升級為陣列結構。

### 核心更動
* `TripVoiceParser.parse(_ rawText: String)` 的回傳值更改為 `[ParsedTrip]`。
* 新增 `TripVoiceParser.splitIntoSegments(_ text: String) -> [String]` 內部方法，負責將長句切斷。
* `VoiceQuickTripView` 的狀態變數 `@State private var draft: VoiceDraft?` 更改為 `@State private var drafts: [VoiceDraft] = []`。
* 在 View 中，原本單一的 `editedStartStation` 等狀態，需改為以 `Dictionary` 或綁定陣列的方式管理多組輸入狀態。

---

## 3. 語意解析策略 (NLP Strategy)

處理多段行程最難的是「切句」與「補漏」。我們將在 `TripVoiceParser` 中加入以下流水線：

### Step 1: 句子切割 (Segmentation)
利用 `VoiceNLP_Rules.json` 中的 `multi_segment_keywords.transferKeywords`（如：轉、然後搭、再坐）作為切割點 (Splitter)。
* **範例**：「捷運北車到淡水轉860公車到三芝」
* **切割後**：`["捷運北車到淡水", "860公車到三芝"]`

### Step 2: 獨立解析 (Independent Parsing)
將切割後的字串陣列，利用 V1 既有的單趟解析邏輯（抽取運具、起迄站、金額），分別產生 `[ParsedTrip]`。

### Step 3: 上下文推論與補漏 (Context Inference)
針對陣列中的 `ParsedTrip` 進行二次掃描（從 Index 1 開始）：
* **起點推論**：若第 N 段缺乏 `startStation`，自動將第 N-1 段的 `endStation` 複製過來。
    * *舉例*：段落二「860公車到三芝」缺乏起點，自動補上段落一的終點「淡水」。
* **運具推論**：若第 N 段缺乏 `transportType` 但有路線號 (RouteId)，可預設為 `bus`。
* **時間推論**：若第 N 段缺乏時間，自動帶入與第 N-1 段相同的日期與時間。

### Step 4: 轉乘標記 (Transfer Flagging)
* 對於陣列中 Index > 0 的 `ParsedTrip`，自動將其 `isTransfer` 屬性設為 `true`。

---

## 4. UI / UX 預覽介面設計

`VoiceQuickTripView` 的預覽階段 (Preview Phase) 需要大改版，以容納多段行程：

* **時間軸列表 (Timeline List)**：以垂直堆疊顯示多張 `FieldResolutionCard`。每張卡片代表一段行程。
* **視覺引導**：在卡片與卡片之間加入垂直連接線，並在線的中間放置一個「轉乘」的視覺 Icon。
* **獨立編輯與刪除**：
    * 使用者可以點開任一卡片修改該段的運具、站名或金額。
    * 每張卡片右上角提供「移除此段」按鈕（以防語音被誤切）。
* **新增行程段落**：在列表最下方提供一個「+ 手動加入下一段轉乘」按鈕。
* **全域儲存**：最下方的儲存按鈕改為「確認並儲存 2 筆行程」。點擊後，以迴圈方式將所有草稿轉換為 `Trip` 寫入資料庫。

---

## 5. 票價與轉乘優惠自動化

V2 必須善用已解析出的多段資訊來進行智慧計算：

* **首段查價**：第一段行程套用原本的 `FareService` 自動查價。
* **次段查價與折抵**：
    * 第二段行程若觸發 `isTransfer = true`，自動查出原價後，系統應自動帶入目前區域預設的 `transferDiscountType`。
    * 計算 `paidPrice` 時，自動扣除轉乘優惠金額。
    * *防呆機制*：若為雙北捷運轉公車，應在介面上提示已自動套用半價/全免優惠。

---

## 6. VoiceParseLog 數據收集升級

為了能追蹤「多段行程」的解析準確率，`VoiceParseLogService` 需微調：

* 維持原有的單一 Record 概念，但將 `parsedResult` 與 `finalResult` 儲存的 JSON 字串改為 **JSON Array** 格式。
* 新增一個整數欄位 `segmentCount` 紀錄這句話切出了幾段行程。
* 移除 `FailureReason.multiSegment` 的失敗阻斷，讓多段行程正式進入 Success 的分析循環中。

---

## 7. V2 最小實作任務清單 (To-Do)

1. **Parser 重構**：在 `TripVoiceParser` 新增 `splitIntoSegments` 邏輯，實作上下文推論（終點接起點）。
2. **Draft 陣列化**：將 `VoiceQuickTripView` 的單一 `draft` 狀態改為 `[VoiceDraft]` 陣列。
3. **UI 重構**：將 `editableFieldsSection` 抽離成獨立的 View Component (`VoiceSegmentEditorCard`)，並在主視圖使用 `ForEach` 渲染。
4. **狀態綁定解耦**：移除全域的 `editedStartStation` 等變數，改為直接修改 `drafts[index]` 內的值（或使用 Binding 陣列）。
5. **儲存邏輯修改**：重寫 `saveDraftAsTrip()`，使用迴圈連續產生多筆 `Trip` 並呼叫 `viewModel.addTrip`。
6. **Log 服務升級**：修改 `VoiceParseLogService.logParseResult` 接受陣列資料並轉為 JSON Array。
7. **極限測試**：測試單一句子包含 3 段行程（例如：客運 -> 捷運 -> 公車），確認上下文傳遞與票價扣除正確。
