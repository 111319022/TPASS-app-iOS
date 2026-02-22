# 彈性記帳週期實作說明

## 功能概述

根據用戶反饋需求，新增了「**彈性記帳週期**」功能，允許使用者在沒有購買 TPASS 月票的情況下，仍能記錄所有交通工具的搭乘記錄。

## 用戶需求來源

> 由於使用TPASS套票的使用者，並不是會購買每個縣市的通勤方案，但又希望可以紀錄自己的搭乘紀錄，可能在方案期間內，臨時使用了方案以外的交通工具以及方案外的路段，導致收取了額外費用或者紀錄了搭乘數據導致計算數據異常，希望可以新增一個非通勤月票方案以外的預設週期。

## 方案設計

### 名稱
- **中文**：彈性記帳週期
- **英文**：Flexible Tracking Period
- **LocalizationKey**: `plan_flexible`

### 特性

1. **全運具開放**
   - 支援所有交通工具類型：北捷、高捷、機捷、中捷、台鐵、高鐵、輕軌、渡輪、YouBike
   - 不受地區限制

2. **無月費**
   - `monthlyPrice = 0`
   - 用於記帳而非計算回本率

3. **預設週期為當月月初到月底**
   - 自動設定為當月 1 日 00:00 到當月最後一天 00:00
   - 當用戶選擇此方案時，日期會自動調整

4. **支援所有轉乘優惠**
   - 支援全台各地的轉乘優惠類型
   - 預設使用雙北轉乘優惠

5. **台鐵站點**
   - 支援全台灣所有台鐵站點（站點 ID：0900-9999）

## 程式碼修改

### 1. TPASSRegion.swift

新增 `.flexible` 枚舉值：

```swift
case flexible = "彈性記帳週期"
```

並在 `allCases` 中將其放在最前面：

```swift
static var allCases: [TPASSRegion] {
    return [.flexible, .north, .taoZhuZhu, ...]
}
```

### 2. CyclesView.swift

新增 `adjustDatesForRegion(_:)` 方法，當選擇彈性記帳週期時自動調整日期：

```swift
private func adjustDatesForRegion(_ region: TPASSRegion) {
    if region == .flexible {
        // 設定為當月月初到月底
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        if let firstDay = calendar.date(from: components) {
            startDate = firstDay
            // 計算當月最後一天
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay),
               let lastDay = calendar.date(byAdding: .second, value: -1, to: nextMonth) {
                endDate = calendar.startOfDay(for: lastDay)
            }
        }
    } else {
        // 一般方案：30天週期
        startDate = today
        endDate = today + 29天
    }
}
```

## 需要新增的多語系字串

請在您的 `Localizable.strings` 檔案中新增以下鍵值：

### 繁體中文 (zh-Hant)
```
"plan_flexible" = "彈性記帳週期";
```

### 英文 (en)
```
"plan_flexible" = "Flexible Tracking";
```

### 日文 (ja) - 如果有支援
```
"plan_flexible" = "フレキシブル記録";
```

## UI 顯示效果

### 週期列表
- 週期名稱：**彈性記帳週期**
- 日期範圍：2026/02/01 ~ 2026/02/28
- 月費：$0（不顯示或顯示為「無月費」）
- 狀態：如果在當月則顯示「進行中」

### 新增週期畫面
1. 當用戶選擇「彈性記帳週期」時：
   - 開始日期自動設為當月 1 日
   - 結束日期自動設為當月最後一天
   - 用戶仍可手動調整日期

2. 方案列表中「彈性記帳週期」排在最前面，方便使用者快速找到

### 財務統計
- 「原價合計」：所有行程的原價加總
- 「實付合計」：所有行程的實付金額加總
- 「回饋金額」：R1 + R2 回饋（如果有）
- 「回本率」：因為月費為 0，可以改為顯示「本月支出」或「累計支出」

## 使用場景

### 場景 1：跨區移動
用戶購買了「基北北桃方案」，但偶爾需要去台中或高雄出差：
- 基北北桃週期：記錄日常通勤
- 彈性記帳週期：記錄當月所有交通，包含出差的高鐵、台中捷運等

### 場景 2：過渡期記錄
用戶的 TPASS 方案在月中到期，但想繼續記錄後續的交通：
- TPASS 週期：2/1-2/15（基北北桃方案）
- 彈性記帳週期：2/16-2/28（無月票，純記帳）

### 場景 3：臨時需求
用戶偶爾使用高鐵、台鐵長途，不想影響 TPASS 方案的統計：
- 基北北桃週期：日常通勤記錄
- 彈性記帳週期：長途旅行記錄

## 技術細節

### 資料模型相容性
- 現有的 `Cycle` 結構完全相容，不需修改
- 只是 `region` 欄位新增了一個可能的值：`.flexible`
- 舊資料不受影響

### 回本率計算
對於彈性記帳週期，建議修改顯示邏輯：

```swift
var roi: Int {
    let monthlyPrice = activeCycle?.region.monthlyPrice ?? 1200
    if monthlyPrice == 0 {
        // 彈性記帳週期：不顯示回本率，改為顯示支出
        return 0  // 或使用特殊標記
    }
    return Int((Double(currentMonthTotal) / Double(monthlyPrice)) * 100)
}
```

### 財務統計調整建議
在 `FinancialBreakdown` 或財務總覽頁面中：

```swift
if activeCycle?.region == .flexible {
    // 不顯示「月費」、「回本率」、「淨賺」等與月票相關的指標
    // 改為顯示：
    // - 本月支出：$XXX
    // - 行程次數：XX 次
    // - 平均每趟：$XX
} else {
    // 正常顯示 TPASS 相關指標
}
```

## 測試建議

### 測試案例 1：新增彈性記帳週期
1. 進入週期管理
2. 點選「新增週期」
3. 選擇「彈性記帳週期」
4. 確認開始日期自動設為當月 1 日
5. 確認結束日期自動設為當月最後一天
6. 儲存並檢查週期列表

### 測試案例 2：記錄不同運具
1. 在彈性記帳週期中
2. 嘗試新增不同運具的行程：
   - 北捷
   - 高鐵
   - 台中捷運
   - 高雄捷運
   - 渡輪
3. 確認所有運具都能正常選擇和記錄

### 測試案例 3：轉乘優惠
1. 在彈性記帳週期中新增行程
2. 開啟轉乘優惠
3. 確認可以選擇各地區的轉乘優惠類型
4. 確認折扣金額計算正確

### 測試案例 4：財務統計
1. 在彈性記帳週期中記錄多筆行程
2. 檢查財務總覽頁面
3. 確認「月費」顯示為 $0 或「無月費」
4. 確認統計數據正確

### 測試案例 5：週期切換
1. 建立多個週期（包含 TPASS 方案和彈性記帳）
2. 在不同週期間切換
3. 確認行程正確歸屬到對應週期
4. 確認統計數據隨週期改變

## 後續優化建議

### 1. 智能推薦
根據使用者的記錄，推薦是否應該購買某個 TPASS 方案：

```swift
// 例如：使用者在彈性記帳週期中記錄了很多雙北行程
if 雙北行程花費 > 1200 {
    顯示推薦：「您本月在雙北地區花費已超過 $1200，建議考慮購買基北北桃方案」
}
```

### 2. 混合統計
提供「包含所有週期」的統計選項，讓使用者看到完整的交通支出：

```swift
// 統計模式選擇
enum StatisticsMode {
    case currentCycle      // 當前週期
    case allCycles         // 所有週期合計
    case flexibleOnly      // 僅彈性記帳
    case tpassOnly         // 僅 TPASS 方案
}
```

### 3. 匯出報表
彈性記帳週期特別適合用於報帳或記錄：

- 匯出 CSV：包含日期、運具、起訖站、金額
- 匯出 PDF：格式化的交通費用報表
- 依運具類型分類統計

### 4. 預算管理
為彈性記帳週期新增預算功能：

```swift
struct FlexibleCycleBudget {
    var monthlyBudget: Int  // 每月預算
    var warningThreshold: Int  // 警告門檻（例如 80%）
    var currentSpending: Int  // 當前支出
}
```

## 總結

「彈性記帳週期」功能完美解決了使用者想要記錄非 TPASS 方案內交通的需求，同時保持了應用程式的一致性和易用性。這個功能的設計理念是：

✅ **靈活性**：支援所有運具和地區  
✅ **易用性**：自動設定月初月底日期  
✅ **相容性**：不影響現有資料和功能  
✅ **擴展性**：為未來的統計和報表功能奠定基礎  

透過這個功能，使用者可以更完整地記錄他們的交通支出，無論是否有購買 TPASS 月票。
