***

# TPASS.calc 多卡管理功能實作指南 FOR VER 1.11

## 1. 核心目標
透過引入「卡片（TransitCard）」概念，讓每個「週期（Cycle）」明確綁定一張載具。

* **數據隔離**：解決 TPASS 週期與常客回饋週期重疊時，回本率計算失真的問題。
* **自動歸類**：語音紀錄行程時，自動繼承當前週期的卡片設定，無需使用者額外選擇。

---

## 2. 資料模型更新 (SwiftData)
首先，你需要建立卡片模型，並更新現有的週期與行程模型。

### A. 新增 TransitCard 模型
```swift
@Model
class TransitCard {
    var id: UUID
    var name: String       // 例如：我的悠遊卡
    var type: String       // EasyCard, iPASS...
    var initialBalance: Int // 初始餘額
    
    init(name: String, type: String, initialBalance: Int = 0) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.initialBalance = initialBalance
    }
}
```

### B. 更新 Cycle 模型
在建立週期時，必須記錄其所屬的卡片 ID。

```swift
// 在你的 Cycle Model 中新增
var cardId: UUID?
```

### C. 更新 Trip 模型
建議在 `Trip` 中也記錄 `cardId`，這樣即使週期結束或被刪除，歷史資料依然能按卡片分類。

```swift
// 在 Trip 模型中
var cardId: UUID?
```

---

## 3. UI 實作步驟

### Step 1: 建立卡片管理頁面
在「設定」中新增一個頁面，讓使用者可以 CRUD 他們的卡片。
* 你可以參考 `SwiftDataManagementView.swift` 的結構來實作卡片列表與刪除功能。

### Step 2: 週期建立頁面綁定卡片
在「建立週期」的畫面（例如 `AddCycleView`）中：
* 讀取所有 `TransitCard`。
* 使用 `Picker` 讓使用者選擇這張月票（或彈性週期）是綁在哪張卡。
* 儲存時將 `TransitCard.id` 寫入 `Cycle.cardId`。
* 若未有卡片時，引導用戶創建。
* 週期綁定卡片時請做一個入口引導至卡片設定。

### Step 3: 優化語音快速記錄 (VoiceQuickTripView)
修改 `saveDraftsAsTrips` 函數，讓行程自動「繼承」週期的卡片身分。

```swift
// 在 VoiceQuickTripView.swift 中修改
private func saveDraftsAsTrips() {
    guard let userId = auth.currentUser?.id,
          let activeCycle = viewModel.activeCycle else { return } // 取得當前活躍週期

    for seg in segments {
        let newTrip = Trip(
            // ... 原有欄位
            cycleId: activeCycle.id,
            cardId: activeCycle.cardId // 自動繼承該週期的卡片 ID
        )
        viewModel.addTrip(newTrip)
    }
}
```

---

## 4. 計算邏輯修正 (解決數據失真)
這是回應使用者回饋最關鍵的一步。你需要修改儀表板的計算方法：

### A. 計算 TPASS 回本率 (ROI)
* **舊邏輯**：抓取該日期區間的所有行程。
* **新邏輯**：僅抓取 `trip.cycleId == currentCycle.id` 的行程。

> 這樣就不會把「沒綁月票的那張卡」的扣款行程算進 TPASS 的回本率裡了。

### B. 計算常客回饋 (Regular Reward)
* **舊邏輯**：抓取日期區間內所有 `paidPrice > 0` 的行程。
* **新邏輯**：抓取日期區間內，且 `trip.cardId == targetCard.id` 的行程。

> 這樣 TPASS 的 0 元行程就不會干擾另一張卡的常客回饋累計。

---

## 5. 開發者工具建議
為了確保功能正確，建議在你的 `SwiftDataManagementView` 中新增對 `TransitCard` 的監看：

* **新增查詢**：`@Query private var cards: [TransitCard]`。
* **新增 Section**：在 List 中加入一個 `Section("TransitCard")` 來查看卡片 ID 與綁定狀況。
* **Log 追蹤**：在 `DevLog` 中記錄每次行程儲存時所綁定的 `cardId`，方便在 `DevConsoleView` 中除錯。

---

## 小提醒
實作此功能後，建議推出「數據遷移說明」，引導使用者為舊有的週期補上卡片綁定。這將能讓他們過去的統計數據也恢復精準！
