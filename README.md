# TPASS.calc 月票回本計算機 (iOS)

TPASS.calc 是一款以通勤族為核心的 iOS App，協助你記錄日常交通支出、套用各區 TPASS 與轉乘優惠，並用可視化數據快速判斷「月票是否回本」。

## 作者

* **Raaay**: [https://github.com/111319022](https://github.com/111319022)

## 系統需求

* **作業系統:** iOS 18.0 或以上版本
* **開發環境:** 建議 Xcode 26.2 以上版本

## 下載連結

* **App Store 正式版:** [點此下載](https://apps.apple.com/tw/app/tpass-calc-%E6%9C%88%E7%A5%A8%E5%9B%9E%E6%9C%AC%E8%A8%88%E7%AE%97%E6%A9%9F/id6758194196)
* **TestFlight 公測版:** [點此加入 TestFlight 測試計畫](https://testflight.apple.com/join/m1y9Q7pH)

## 主要功能

- 行程記錄與管理
- 支援多種運具（捷運、公車、客運、台鐵、高鐵、機捷、輕軌、YouBike、渡輪）
- 可設定是否為轉乘，並套用區域與身分對應的轉乘優惠
- 支援單筆新增、編輯、刪除、複製、建立回程、整日複製

- 快速新增流程
- 常用路線（Favorites）一鍵新增
- 通勤路線模板（Commuter Routes）整組快速加入
- 回家/出門站點快速新增

- 票價與優惠計算
- 多套票價服務（台北捷運、桃園機捷、台中捷運、高雄捷運、台鐵、高鐵）
- 依 TPASS 方案與使用者身分自動計算原價、實付、折抵

- 週期管理
- 可建立目前週期、未來週期、歷史週期
- 每個週期可綁定 TPASS 方案
- 提供「彈性記帳週期」模式（全運具開放，適合無固定 TPASS 方案情境）

- 數據儀表板
- 月票回本率（ROI）
- 原價/實付/折抵分析
- 每日累積、熱力圖、時段分佈、路線排行、運具統計

- 資料備份與搬移
- CloudKit 私有資料庫備份/還原/刪除備份
- CSV 匯出與匯入（含舊格式相容）

- 其他實用功能
- 每日提醒與週期提醒通知
- 主題切換（含系統/亮色/深色/自定風格）
- 首次引導與操作聚光教學
- 中英文在地化字串架構

## 支援的 TPASS 方案（程式內建）

- 基北北桃
- 桃竹竹、桃竹竹苗、竹竹苗
- 北宜跨城際及雙北、北宜跨城際
- 宜蘭縣都市內、宜蘭好行三日券
- 中彰投苗（市民/非市民）
- 南高屏、高雄
- 大台南不含台鐵、大台南台鐵、大台南加嘉義台鐵、嘉嘉南
- 彈性記帳週期

## 技術架構

- UI 與狀態管理
- SwiftUI
- MVVM（`AppViewModel` 為核心資料與商業邏輯）

- 資料層
- SwiftData（`Trip`、`FavoriteRoute`、`CommuterRoute`）
- UserDefaults（使用者帳號、偏好、教學狀態、提醒設定）
- Migration Manager（舊版資料搬遷到 SwiftData）

- 同步與備份
- CloudKit（Private Database）

- 計算與視覺化
- Charts（儀表板圖表）
- SQLite3（台鐵票價資料）

## 專案結構

- `Views/`: 各頁面與 UI 元件
- `ViewModels/`: 畫面狀態、統計與資料操作
- `Models/`: 資料模型、列舉、TPASS 方案定義
- `Services/`: 票價服務、通知、CloudKit、CSV 等服務
- `Data/`: 車站資料與轉換工具
- `Helpers/`: 遷移與輔助工具

## 快速開始（開發者）

1. 下載專案
   - `git clone https://github.com/111319022/TPASS-app-iOS.git`

2. 使用 Xcode 開啟專案
   - 開啟 `TPASS-app-iOS.xcodeproj`

3. 設定簽章與能力（Signing & Capabilities）
   - Team 與 Bundle Identifier
   - 若要使用雲端備份，需啟用 iCloud 並配置對應 container

4. 選擇模擬器或實機後執行
   - Product > Run

## 使用流程建議

1. 首次啟動：完成導覽並選擇身分（成人/學生）
2. 設定 TPASS 週期與方案
3. 開始記錄行程（可用手動新增或常用路線快速新增）
4. 到儀表板查看回本率與節省分析
5. 定期做 CloudKit 或 CSV 備份

## 備份與隱私

- 資料預設儲存在裝置本機（SwiftData + UserDefaults）
- 啟用 CloudKit 後，備份會存到使用者自己的 iCloud 私有資料庫
- CSV 匯出可作為離線備份或跨裝置搬移
- App 提供清除本機資料功能（設定頁）

## 已知行為與限制

- 為了效能，主資料載入預設聚焦近三個月資料
- CloudKit 備份功能需使用者 iCloud 帳號可用
- `CardScannerView`（悠遊卡交易匯入）目前在主要 Tab 中預設未啟用

## 貢獻

歡迎提出 Issue 與 Pull Request，一起讓通勤記帳更簡單好用。

---
