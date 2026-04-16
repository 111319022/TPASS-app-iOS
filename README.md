# TPASS.calc 月票回本計算機 (iOS)

![iOS](https://img.shields.io/badge/iOS-18.0+-black?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-FA7343?style=for-the-badge&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-MVVM-blue?style=for-the-badge&logo=swift)
![CloudKit](https://img.shields.io/badge/CloudKit-Backup-34A853?style=for-the-badge)

TPASS.calc 是一款為台灣通勤族打造的 iOS App，專注在「交通記帳 + TPASS 優惠計算 + 月票回本分析」。

你可以快速記錄每日搭乘，系統會依據地區方案、身分與轉乘規則，自動算出原價、實付與折抵，幫助你判斷每月 TPASS 是否回本。

## 下載

- **App Store 正式版:** [點此下載](https://apps.apple.com/tw/app/tpass-calc-%E6%9C%88%E7%A5%A8%E5%9B%9E%E6%9C%AC%E8%A8%88%E7%AE%97%E6%A9%9F/id6758194196)
- **TestFlight 公測版:** [點此加入測試](https://testflight.apple.com/join/m1y9Q7pH)

## 核心功能

### 行程與快速新增
- 支援多運具：捷運、公車、客運、台鐵、高鐵、機捷、輕軌、YouBike、渡輪
- 單筆新增/編輯/刪除、複製行程、建立回程、整日複製
- 常用路線（Favorites）一鍵加入
- 通勤路線模板（Commuter Routes）整組快速建立
- 回家站點與出門站點快捷新增

### TPASS 與轉乘優惠計算
- 依「方案 + 身分 + 轉乘型態」自動換算實付金額
- 支援雙北、桃園、台中、高雄、台南、嘉義等跨區規則
- 支援彈性記帳週期（可選運具子集合）
- 台鐵區間合法性與多區段範圍對應（依方案）

### 週期與儀表板
- 管理目前/未來/歷史週期
- 每個週期可綁定不同 TPASS 方案
- 儀表板提供：回本率、折抵分析、每日累積、熱力圖、路線排行、運具統計

### 備份與資料搬移
- CloudKit 私有資料庫手動備份/還原/刪除（V2 JSON Payload）
- CSV 匯出與匯入，含舊格式相容
- App 內建本地舊資料遷移至 SwiftData（MigrationManager）

### 問題回報與開發者工具
- 使用者可於設定頁提交問題到 CloudKit Public Database
- 開發者可於開發者工具頁啟用「IssueReport 新增事件」推播訂閱
- 開發者可於 App 內開發者頁面查看回報清單（內容、聯絡信箱、App/iOS 版本、建立時間）

### 使用體驗
- 通知系統：每日提醒、週期到期提醒
- 主題切換：系統/亮色/深色/暖色（Muji）
- Spotlight 教學與引導頁
- 多語系字串架構（Localizable.xcstrings）

## 支援的 TPASS 方案

- 基北北桃
- 桃竹竹、桃竹竹苗、竹竹苗
- 北宜跨城際及雙北、北宜跨城際
- 宜蘭縣都市內、宜蘭好行三日券
- 中彰投苗（市民/非市民）
- 南高屏、高雄
- 大台南不含台鐵、大台南台鐵、大台南加嘉義台鐵、嘉嘉南
- 彈性記帳週期

## 架構概要

TPASS.calc 採 SwiftUI + SwiftData 的 iOS 原生 MVVM 架構：

```
TPASS-app-iOS/
├── TPASS-app-iOS.swift              # App 入口、ModelContainer 啟動、登入切頁
├── Models/                          # Domain model / enum / TPASS 規則
├── ViewModels/
│   └── AppViewModel.swift           # 核心狀態與商業邏輯
├── Services/                        # 票價、備份、通知、主題、觸覺
├── Views/                           # 全部 UI 畫面與流程
├── Data/                            # 站點資料與轉換工具
└── Helpers/
    └── MigrationManager.swift       # 舊資料遷移
```

## 技術棧

| 層級 | 技術 |
|------|------|
| UI | SwiftUI |
| 狀態管理 | `ObservableObject` + `@Published` |
| 資料層 | SwiftData (`Trip` / `FavoriteRoute` / `CommuterRoute` / `UserSettingsModel`) |
| 設定層 | UserDefaults（User/Cycle/偏好/主題） |
| 備份層 | CloudKit Private Database（`CloudKitSyncService`） |
| 回報層 | CloudKit Public Database（`IssueReportService`） |
| 匯入匯出 | CSV (`CSVManager`) |
| 計算服務 | 多運具票價 Service（MRT/TRA/HSR/TYMRT/TCMRT/KMRT） |

## 重要設計決策

- **本地優先資料模型**：主要營運資料在本機 SwiftData + UserDefaults；CloudKit 用於備份還原。
- **漸進式資料遷移**：先嘗試非版本化資料庫，再 fallback 到版本化 Schema（`TPASSSchemaV2` + `TPASSMigrationPlan`）。
- **效能優先讀取策略**：`AppViewModel.fetchAllData()` 預設載入近 3 個月行程；備份時才讀完整歷史資料。
- **向後相容**：`Cycle` 與 CSV 解析都保留舊版欄位容錯（ID 型別、時間戳格式、欄位數）。

## 系統需求

* **機型與作業系統**
    * **iPhone**: 需為 **iOS 18.0** 或以上版本 (支援 iPhone XS/XR/SE 2 及後續機型)。
    * **多平台相容性**: 本APP採 iOS 原生架構開發，可於下列裝置以 **iPhone 相容模式**執行：
        * **iPad**: 需運行 iPadOS 18.0 或以上版本。
        * **Mac**: 僅支援搭載 **Apple Silicon** 晶片之機型，並且需運行 MacOS Sequoia (15.0) 或以上版本。
        * **Apple Vision Pro**: 需運行 VisionOS 2.0 或以上版本。
        
* **開發環境:** 你需要一台Mac！建議使用 Xcode 26.2 或以上版本進行編譯，並選擇或連接符合作業系統要求之裝置。

## 快速開始

```bash
git clone https://github.com/111319022/TPASS-app-iOS.git
open TPASS-app-iOS/TPASS-app-iOS.xcodeproj
```

執行前請確認：
- Xcode Signing & Capabilities 設定 Team 與 Bundle Identifier
- 若需 CloudKit 備份，需啟用 iCloud 並設定正確 container
- 若需測試開發者回報推播，需以實機安裝並允許通知與遠端推播

## 使用流程建議

1. 首次啟動：完成 Intro 與身分設定
2. 建立週期並綁定 TPASS 方案
3. 記錄日常通勤（可使用常用路線/模板）
4. 於 Dashboard 查看回本率、折抵與統計
5. 定期做 CloudKit 或 CSV 備份
6. 如遇問題可在設定頁使用「問題回報」提交內容

## 專案文件

完整技術文件、模組責任、資料流程與維護指南，請參閱：

- **[PROJECT_GUIDE.md](PROJECT_GUIDE.md)**

## 團隊

- **Raaay** — [github.com/111319022](https://github.com/111319022)

## 使用的AI輔助

- Gemini from Google
- Claude Code from Anthropic
