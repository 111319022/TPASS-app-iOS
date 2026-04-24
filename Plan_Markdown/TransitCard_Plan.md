# TPASS.calc 多卡管理功能實作指南 FOR VER 1.11

## 1. 核心目標
透過引入「卡片（TransitCard）」概念，讓每個「週期（Cycle）」明確綁定一張載具。

* **數據隔離**：解決 TPASS 週期與常客回饋週期重疊時，回本率計算失真的問題。
* **自動歸類**：語音紀錄行程時，自動繼承當前週期的卡片設定，無需使用者額外選擇。
* **自訂靈活性**：類別僅作基本區分，使用者可自由命名卡片（如：我的紫色悠遊卡、公司公務卡）。

---

## 2. 資料模型更新 (SwiftData)
首先，定義卡片類型的 Enum，並更新 `TransitCard` 與相關模型。

### A. 新增 TransitCardType 與 TransitCard 模型
```swift
// 1. 定義卡片類別 Enum
enum TransitCardType: String, Codable, CaseIterable {
    case tpass = "TPASS 專用卡"
    case custom = "自訂"
}

// 2. 建立卡片模型
@Model
class TransitCard {
    var id: UUID
    var name: String           // 使用者自訂名稱，例如：「我的粉紅悠遊卡」
    var type: TransitCardType  // 使用 Enum 確保型別安全
    var initialBalance: Int    // 初始餘額
    
    init(name: String, type: TransitCardType = .custom, initialBalance: Int = 0) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.initialBalance = initialBalance
    }
}
```

### B. 更新 Cycle 模型
在建立週期時，必須記錄其所屬的卡片 ID，以實現數據隔離。

```swift
// 在你的 Cycle Model 中新增
var cardId: UUID?
```

### C. 更新 Trip 模型
建議在 `Trip` 中也記錄 `cardId`。這樣即使該週期結束或被刪除，歷史資料依然能按卡片進行支出分析與分類。

```swift
// 在 Trip 模型中新增
var cardId: UUID?
```

---

## 3. UI 實作步驟

### Step 1: 建立卡片管理頁面
在「設定」中新增一個頁面，讓使用者可以 CRUD 他們的卡片。
* **新增卡片**：提供一個 `TextField` 讓使用者輸入自訂名稱，並使用 `Picker` 選擇類別（TPASS 或 自訂）。
* **列表顯示**：可以參考 `SwiftDataManagementView.swift` 的結構來實作卡片清單與滑動刪除功能。

### Step 2: 週期建立頁面綁定卡片
在「建立週期」的畫面（例如 `AddCycleView`）中：
* **讀取卡片**：讀取所有 `TransitCard` 並顯示自訂名稱。
* **綁定邏輯**：使用 `Picker` 讓使用者選擇此週期（月票或彈性週期）是綁在哪張實體載具。
* **引導流程**：若使用者尚未建立任何卡片，應在此頁面提供一個「新增卡片」的入口或直接彈窗引導建立。
* **存檔**：儲存週期時將 `TransitCard.id` 寫入 `Cycle.cardId`。

### Step 3: 優化語音快速記錄 (VoiceQuickTripView)
修改儲存邏輯，讓語音解析出的多段行程自動繼承當前週期的卡片設定。

```swift
// 在 VoiceQuickTripView.swift 中修改
private func saveDraftsAsTrips() {
    guard let userId = auth.currentUser?.id,
          let activeCycle = viewModel.activeCycle else { return } // 取得當前活躍週期

    for seg in segments {
        let newTrip = Trip(
            // ... 原有欄位
            cycleId: activeCycle.id,
            cardId: activeCycle.cardId // 自動繼承該週期的卡片 ID，無需使用者選擇
        )
        viewModel.addTrip(newTrip)
    }
}
```

---

## 4. 計算邏輯修正 (解決數據失真)
這是解決使用者痛點的最關鍵步驟，需修改儀表板的計算方法：

### A. 計算 TPASS 回本率 (ROI)
* **舊邏輯**：抓取該日期區間的所有行程。
* **新邏輯**：僅抓取 `trip.cycleId == currentCycle.id` 的行程。
> **效果**：這會自動排除「同一段時間內使用其他卡片（非月票）」的扣款行程，確保回本率數據精準。

### B. 計算常客回饋 (Regular Reward)
* **舊邏輯**：抓取日期區間內所有有付費的行程。
* **新邏輯**：抓取日期區間內，且 `trip.cardId == targetCard.id` 的行程。
> **效果**：避免 TPASS 的 0 元行程干擾另一張一般悠遊卡的常客回饋累計金額。

---

## 5. 開發者工具建議
為了確保多卡邏輯運作正確，建議更新 `SwiftDataManagementView` 與 Console：

* **監控資料**：在 `SwiftDataManagementView` 中新增 `@Query private var cards: [TransitCard]`，並加入 `Section("TransitCard")` 查看卡片 ID 與型別。
* **Log 追蹤**：在 `DevLog` 中記錄每次行程儲存時所關聯的 `cardId`，方便在 `DevConsoleView` 中進行除錯。

---

## 小提醒
實作完成後，建議在 App 啟動時加入「數據遷移提示」，引導老用戶為現有的週期補上卡片綁定。一旦舊資料補齊 `cardId`，他們過去被干擾的統計圖表將會立即恢復精準。
