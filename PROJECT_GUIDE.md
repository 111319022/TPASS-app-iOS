# TPASS.calc 專案指南

本文件提供 TPASS.calc 的完整技術說明，涵蓋架構、模組職責、資料流程、同步與備份策略，以及日常維護注意事項。適合新進開發者上手與維護者快速查閱。

## 目錄

1. [專案全域檔案架構圖（檔案級）](#專案全域檔案架構圖檔案級)
2. [架構總覽](#架構總覽)
3. [App 啟動流程](#app-啟動流程)
4. [資料模型 (SwiftData + UserDefaults)](#資料模型-swiftdata--userdefaults)
5. [資料來源與 JSON 結構](#資料來源與-json-結構)
6. [TPASS 方案與運具規則](#tpass-方案與運具規則)
7. [計價與折抵流程](#計價與折抵流程)
8. [ViewModel 層](#viewmodel-層)
9. [Service 層](#service-層)
10. [View 層](#view-層)
11. [語音快速新增功能](#語音快速新增功能)
12. [主題與通知系統](#主題與通知系統)
13. [備份、還原與匯入匯出](#備份還原與匯入匯出)
14. [遷移與相容策略](#遷移與相容策略)
15. [測試現況與建議](#測試現況與建議)
16. [已知限制與後續方向](#已知限制與後續方向)
17. [日常維護清單](#日常維護清單)
18. [CloudKit Admin 管理筆記](#cloudkit-admin-管理筆記)

---

## 專案全域檔案架構圖（檔案級）

依你需求，本節改為「每個區塊獨立架構圖」，並在每張架構圖後直接附上功能說明。

### Py_Data_Convert/

```text
Py_Data_Convert/
├── TRAConvertFare_v9.py
├── TRAConvertStations.py
└── csv_to_json.py
```

功能：
- `TRAConvertFare_v9.py`：台鐵票價原始資料轉換與清理。
- `TRAConvertStations.py`：台鐵站點資料正規化與匯整。
- `csv_to_json.py`：通用 CSV -> JSON 轉檔工具。

### TPASS-app-iOS.xcodeproj/
### TPASS-app-iOS/

```text
TPASS-app-iOS/
├── Assets.xcassets/
│   ├── Contents.json
│   ├── AppIcon.appiconset/Contents.json
│   ├── AppIcon.appiconset/工作區域 1.png
│   ├── icon.imageset/Contents.json
│   └── icon.imageset/工作區域 1_rounded.png
├── Data/
│   ├── New_FareData/
│   │   ├── KLRT_Fare.json
│   │   ├── KMRT_Fare.json
│   │   ├── NTALRT_Fare.json
│   │   ├── NTDLRT_Fare.json
│   │   ├── TCMRT_Fare.json
│   │   ├── TPEMRT_Fare.json
│   │   └── TYMRT_Fare.json
│   ├── New_StationData/
│   │   ├── KLRT_StationData.json
│   │   ├── KMRTStationData.swift
│   │   ├── KMRT_StationData.json
│   │   ├── LRTStationData.swift
│   │   ├── NTALRT_StationData.json
│   │   ├── NTDLRT_StationData.json
│   │   ├── NTPCMRT_StationData.json
│   │   ├── StationData.swift
│   │   ├── TCMRTStationData.swift
│   │   ├── TCMRT_StationData.json
│   │   ├── TPEMRT_StationData.json
│   │   ├── TYMRTStationData.swift
│   │   └── TYMRT_StationData.json
│   ├── StationData/
│   │   ├── HSRStationData.swift
│   │   ├── TRAStationData.swift
│   │   └── TRAStations.json
│   └── VoiceNLP/
│       └── VoiceNLP_Rules.json
├── Helpers/
│   └── MigrationManager.swift
├── Models/
│   ├── AllTripsCleanupView.swift
│   ├── Enums.swift
│   ├── LRTModels.swift
│   ├── SwiftDataModels.swift
│   ├── TPASSModelSchema.swift
│   ├── TPASSRegion.swift
│   ├── User.swift
│   └── VoiceDraft.swift
├── Services/
│   ├── AuthService.swift
│   ├── CSVManager.swift
│   ├── CloudKitSyncService.swift
│   ├── DeveloperAccessService.swift
│   ├── HapticManager.swift
│   ├── IssueReportService.swift
│   ├── NotificationManager.swift
│   ├── ThemeManager.swift
│   ├── TripVoiceParser.swift
│   ├── VoiceInputService.swift
│   ├── VoiceParseLogService.swift
│   ├── FareServices/
│   │   ├── THSRFareService.swift
│   │   ├── TRAFareService.swift
│   │   └── TRA_Fares_Fixed.sqlite
│   └── New_FareServices/
│       ├── KMRTFareService.swift
│       ├── LRTFareService.swift
│       ├── TCMRTFareService.swift
│       ├── TPEMRTFareService.swift
│       └── TYMRTFareService.swift
├── ViewModels/
│   └── AppViewModel.swift
├── Views/
│   ├── AddTripView.swift
│   ├── BackupManagementView.swift
│   ├── CSVManagementView.swift
│   ├── CardScannerView.swift
│   ├── CommuterRoutePickerOverlay.swift
│   ├── CyclesView.swift
│   ├── DashboardView.swift
│   ├── DeveloperIssueReportsView.swift
│   ├── DeveloperToolsPlaceholderView.swift
│   ├── EditTripView.swift
│   ├── FavoritesManagementView.swift
│   ├── HomeStationSettingsView.swift
│   ├── IntroView.swift
│   ├── MainTabView.swift
│   ├── NotificationSettingsView.swift
│   ├── OutboundStationSettingsView.swift
│   ├── QuickAddHomeView.swift
│   ├── QuickAddOutboundView.swift
│   ├── ReportIssueView.swift
│   ├── SettingsView.swift
│   ├── SpotlightTutorialView.swift
│   ├── TPASSRegionSelectionView.swift
│   ├── TransferIntroductionView.swift
│   ├── TransferTypeSelectionView.swift
│   ├── TripListView.swift
│   ├── ViewFrameKey.swift
│   └── VoiceQuickTripView.swift
├── Localizable.xcstrings
├── TPASS-app-iOS-Info.plist
├── TPASS-app-iOS.entitlements
└── TPASS-app-iOS.swift
```

功能：
- `TPASS-app-iOS.swift`：App 啟動入口、登入狀態切換、ModelContainer 初始化。
- `Data/`：站點/票價/NLP 規則資料與讀取服務。
- `Models/`：商業模型、SwiftData schema、TPASS 規則與語音草稿模型。
- `Services/`：認證、備份、查價、通知、語音解析、問題回報與記錄上傳。
- `ViewModels/AppViewModel.swift`：主流程狀態與核心商業邏輯。
- `Views/`：所有 UI 頁面與互動流程。
- `Helpers/MigrationManager.swift`：舊資料遷移。
- `Localizable.xcstrings`：多語系文案。
- `TPASS-app-iOS-Info.plist` / `TPASS-app-iOS.entitlements`：App 設定與權限。
- `Assets.xcassets/`：圖像資產、App Icon、Logo。


### webpage/

```text
webpage/
├── 404.html
├── index.html
├── privacy.html
└── support.html
```

功能：
- `index.html`：官網首頁。
- `privacy.html`：隱私權政策頁。
- `support.html`：客服支援頁。
- `404.html`：錯誤導向頁。

### Firebase 設定

```text
firebase.json
.firebaserc
```

功能：
- `firebase.json`：Hosting 行為、路由、部署規則設定。
- `.firebaserc`：Firebase 專案 alias 與環境對應。

備註：
- `.DS_Store` 與 `xcuserdata` 屬系統/個人環境檔，通常不作為商業邏輯維護重點。

## 架構總覽

TPASS.calc 採用 SwiftUI + SwiftData 的 iOS 原生 MVVM 架構，資料以本地優先設計，CloudKit 主要用於手動備份/還原。

```
┌─────────────────────────────────────────────────┐
│ Presentation                                    │
│ Views/ (SwiftUI)                                │
├─────────────────────────────────────────────────┤
│ Application                                     │
│ AppViewModel                                    │
├─────────────────────────────────────────────────┤
│ Domain                                          │
│ Models/ · Data/                                 │
├─────────────────────────────────────────────────┤
│ Infrastructure                                  │
│ SwiftData · UserDefaults · CloudKit Service     │
└─────────────────────────────────────────────────┘
```

### 技術選型

| 項目 | 選擇 | 理由 |
|------|------|------|
| UI | SwiftUI | 原生宣告式 UI，搭配狀態驅動流程 |
| 狀態管理 | `ObservableObject` + `@Published` | 與現有專案一致、可讀性高 |
| 持久層 | SwiftData | 本機資料查詢與存取效率佳 |
| 使用者設定 | UserDefaults | 輕量偏好與 session 資料保存 |
| 備份 | CloudKit Private DB | 不需自建後端，依 iCloud 帳號備份 |
| 匯入匯出 | CSV | 提供離線備份與跨裝置資料搬移 |

---

## 資料來源與 JSON 結構

TPASS.calc 目前的資料層已改為 JSON 驅動，站點資料與票價資料都由 App bundle 內的 JSON 檔提供，不再把站點或票價矩陣寫死在 Swift 程式碼中。

### 站點資料來源

- 所有站點資料均來自 TDX。
- 目前站點查表服務會先把 App 內的站點名稱正規化，再去對應 JSON 站點資料。
- 各運具站點資料主要放在 `Data/` 目錄下的對應 Swift / JSON 資料檔。

### 票價資料來源

- 北捷票價來自台北資料大平台（Data Taipei）。
- 其餘已 JSON 化的票價資料來源皆為 TDX。
- 目前已 JSON 化的票價服務包括：`TPEMRTFareService`、`TYMRTFareService`、`TCMRTFareService`、`KMRTFareService` 與 LRT 票價服務。
- TRA 與 HSR 目前仍沿用既有的資料庫/查價服務，尚未納入這次 JSON 化資料來源。

### 票價 JSON 規則

- 新版票價 JSON 檔集中放在 `Data/New_FareData/`。
- 實際查價時一律只取 `TicketType = 1`、`FareClass = 1` 的單程全票資料。
- 若 JSON 內同時存在多筆重複或不同票種資料，服務層會先過濾後再建立查價索引。

### 命名與相容性

- TYMRT 站名需要處理尾綴 `站` 與別名相容，例如 `桃園高鐵站`、`高鐵桃園站`。
- 北捷票價服務會合併查詢 `TPEMRT_Fare.json` 與 `NTPCMRT_Fare.json`。
- 查價時會先把起訖站名正規化，再建立對稱 key，避免方向相反時查不到票價。

### 語音 NLP 規則資料來源

- 語音解析規則集中在 `Data/VoiceNLP/VoiceNLP_Rules.json`。
- `TripVoiceParser` 會在 App 生命週期中 Lazy Loading 規則（只載一次）。
- 規則庫包含：
  - `noise_filters`：語助詞/雜訊過濾
  - `transports`：11 種運具關鍵字、priority、asr_errors
  - `station_aliases`：站名別名映射
  - `price_patterns` / `station_patterns` / `route_patterns`：抽取正則
  - `time_semantics` / `chinese_numbers`：時間與中文數字語意
  - `confidence`：信心分數權重與門檻
- 目標：調整解析規則時優先改 JSON，盡量不動 Swift 程式碼。

---

## App 啟動流程

**檔案**：`TPASS-app-iOS.swift`

啟動順序：

1. 建立 `AuthService` / `AppViewModel` / `ThemeManager` 單例或狀態物件
2. 初始化 `ModelContainer`：
   - 先嘗試非版本化 schema
   - 失敗則嘗試 `TPASSSchemaV2` + `TPASSMigrationPlan`
   - 再失敗則 fallback 記憶體模式
3. 依 `AuthService` 狀態顯示畫面：
   - `isRestoringSession == true` → `LaunchSplashView`
   - 已登入且容器可用 → `MainTabView`
   - 已登入但容器不可用 → `DataStoreErrorView`
   - 未登入 → `IntroView`
4. 使用者登入（或自動還原登入）後，呼叫 `AppViewModel.start(modelContext:userId:)`
5. `start` 內部會先跑 `MigrationManager.migrateIfNeeded`，再載入資料

---

## 資料模型 (SwiftData + UserDefaults)

### SwiftData Models

**檔案**：`Models/SwiftDataModels.swift`

| Model | 用途 |
|------|------|
| `Trip` | 行程主資料（運具、原價、實付、轉乘、路線、備註、週期） |
| `FavoriteRoute` | 常用路線設定 |
| `CommuterRoute` | 通勤模板（內含 `CommuterTripTemplate`） |
| `UserSettingsModel` | 使用者設定持久化（身分、遷移狀態等） |

`Trip` 核心欄位：
- `type: TransportType`
- `originalPrice` / `paidPrice`
- `isTransfer` / `transferDiscountType`
- `cycleId`
- `createdAt`

### UserDefaults / Codable Models

**檔案**：`Models/User.swift`

| 結構 | 用途 |
|------|------|
| `User` | 本地登入使用者、週期、身分、站點偏好 |
| `Cycle` | 週期區間、方案、可選運具清單 |
| `HomeStation` / `OutboundStation` | 快捷站點 |

特點：
- `Cycle` decoding 支援舊格式容錯（ID 數字/字串、時間戳格式）
- `Cycle` 新欄位 `selectedModes` 向後相容
- `effectiveSupportedModes` 會自動從 `selectedModes` 或 `region.supportedModes` 推導

---

## TPASS 方案與運具規則

**檔案**：`Models/TPASSRegion.swift`、`Models/Enums.swift`

### TPASSRegion

`TPASSRegion` 定義：
- 顯示名稱（含在地化 key）
- 月費（`monthlyPrice`）
- 支援運具（`supportedModes`）
- 支援轉乘類型（`supportedTransferTypes`）
- 預設轉乘類型（`defaultTransferType`）
- 台鐵有效區間（多段 ID range）

### 主要列舉

| Enum | 說明 |
|------|------|
| `TransportType` | 11 種運具分類（含 MRT/TRA/HSR/TYMRT/TCMRT/KMRT 等） |
| `Identity` | 成人 / 學生，影響折扣金額 |
| `TransferDiscountType` | 區域轉乘類型與折扣規則 |
| `TaiwanCity` | 市民條件判斷與顯示 |

---

## 計價與折抵流程

### 運具票價服務

**檔案**：`Services/New_FareServices/TPEMRTFareService.swift`、`Services/New_FareServices/TYMRTFareService.swift`、`Services/New_FareServices/TCMRTFareService.swift`、`Services/New_FareServices/KMRTFareService.swift`、`Services/New_FareServices/LRTFareService.swift`、`Services/FareServices/TRAFareService.swift`、`Services/FareServices/THSRFareService.swift`

責任：
- 依運具來源取得基礎票價
- 由 UI/VM 層結合 TPASS 方案與轉乘類型，計算實付
- JSON 化的票價服務會先過濾 `TicketType = 1`、`FareClass = 1` 的正式單程票資料
- TRA 與 HSR 目前仍維持既有查價服務，尚未切換到新版 JSON 票價檔

### 轉乘折抵

`TransferDiscountType.discount(for:)` 定義各方案折扣（依身分動態），例如：
- 雙北：成人/學生不同折抵
- 宜蘭：成人/學生不同折抵
- 高雄、台南：固定折抵值

### 週期歸屬邏輯

`AppViewModel` 使用 `resolveCycle(for:)` 與 `cycleId` 協同判定：
1. 優先使用 `Trip.cycleId`
2. 無 `cycleId` 時，以日期推論所屬週期
3. `filteredTrips` 只統計 active cycle 範圍

---

## ViewModel 層

**檔案**：`ViewModels/AppViewModel.swift`

`AppViewModel` 是目前專案核心資料與商業邏輯中心。

### 主要狀態

- `trips` / `favorites` / `commuterRoutes`
- `selectedCycle`
- `isLoading` / `errorMessage`
- 快取：`_filteredTripsCache`、`_groupedTripsCache`

### 主要方法

| 方法 | 說明 |
|------|------|
| `start(modelContext:userId:)` | 啟動 VM，執行遷移並載入資料 |
| `fetchAllData()` | 載入近 3 個月資料與路線配置 |
| `fetchAllHistoricalTrips()` | 備份用，載入完整歷史資料 |
| `refreshSelectedCycle()` | 重新抓取當前週期（避免 stale data） |
| `resolveCycle(for:)` | 依日期推論所屬週期 |
| `filteredTrips` / `groupedTrips` | 週期過濾與日期分組結果 |

設計重點：
- 預設只載近 3 個月，改善啟動與切頁效能
- 透過快取降低重複計算成本
- 週期切換時清快取，保證統計正確

---

## Service 層

### AuthService

**檔案**：`Services/AuthService.swift`

職責：
- 本地 session 還原與保存（`local_user`）
- 建立匿名使用者（初始化週期、身分）
- 身分、市民縣市、週期、站點偏好 CRUD
- `currentRegion` 狀態管理

### CloudKitSyncService

**檔案**：`Services/CloudKitSyncService.swift`

職責：
- 手動上傳備份（`TPASSBackupV2`）
- 備份歷史查詢（兼容 legacy `BackupMeta`）
- 還原備份（legacy / v2）
- 備份刪除

資料格式：
- `TPASSBackup`（JSON）
- 內容含 trips/favorites/cycles/commuterRoutes/home/outbound/identity/citizenCity
- `schemaVersion` 目前為 `2`

CloudKit container：
- `iCloud.com.tpass-app.tpasscalc`

### CSVManager

**檔案**：`Services/CSVManager.swift`

職責：
- 匯出 CSV（固定英文欄位）
- 匯入 CSV 並建立 `Trip`
- 向後相容舊版欄位數（11 欄）與新版（13 欄）
- cycleId 不存在時自動回退推論

### NotificationManager

**檔案**：`Services/NotificationManager.swift`

職責：
- 通知授權檢查與請求
- 每日提醒排程（重複通知）
- 週期到期前/過期後提醒

### ThemeManager

**檔案**：`Services/ThemeManager.swift`

職責：
- 主題切換（system/light/dark/muji）
- 全域背景/卡片/字色/強調色管理
- 運具配色與圖表配色映射

### 其他服務

| 檔案 | 說明 |
|------|------|
| `HapticManager.swift` | 觸覺回饋封裝 |
| `IssueReportService.swift` | 使用者問題回報寫入 Public DB、開發者訂閱建立、回報列表查詢 |
| `VoiceParseLogService.swift` | 匿名上傳語音解析紀錄（解析結果 vs 最終修正）至 Public DB |
| 各 `FareService` | 運具票價查表與運算 |

### IssueReportService

**檔案**：`Services/IssueReportService.swift`

職責：
- `submitReport(content:email:)`：將回報內容、聯絡信箱、App 版本、iOS 版本寫入 `IssueReport` record（Public DB）。
- `setupDeveloperPushNotification()`：建立 `CKQuerySubscription`（`firesOnRecordCreation`），接收新回報推播。
- `fetchReports(limit:)`：供開發者頁讀取回報清單。
- `updateIssueStatus(recordID:newStatus:)`：更新回報狀態（例如 `pending` -> `fixed`）。
- `deleteIssueReport(recordID:)`：刪除指定回報。
- `clearIssueReportNotificationMarks()`：清除回報相關通知與 App 角標。

權限注意：
- CloudKit Public Database 的管理寫入（至少包含標記回報完成狀態）需要 Admin 身分。
- 若帳號沒有對應角色，Production 會出現 `WRITE operation not permitted`。

CloudKit container：
- `iCloud.com.tpass-app.tpasscalc`

資料欄位：
- `content`
- `contactEmail`
- `appVersion`
- `iOSVersion`

### VoiceParseLogService

**檔案**：`Services/VoiceParseLogService.swift`

職責：
- 在語音快速新增儲存成功後，背景上傳語音解析紀錄到 CloudKit Public Database。
- 記錄解析階段與最終確認結果，用於離線分析與規則優化。
- 靜默失敗策略：上傳失敗不阻擋主流程，只在 debug 印出訊息。

CloudKit 設計：
- Record Type：`VoiceParseLog`
- 欄位（核心）：
  - `originalTranscript`
  - `parsedResult`（JSON 字串）
  - `finalResult`（JSON 字串）
  - `isCorrected`（0/1）
  - `overallScore`
  - `appVersion`
  - `rulesVersion`

隱私策略：
- 上傳前會清洗敏感欄位，至少包含：`userId`、`appleId`、`deviceId`、`email`、`name`。
- 不依賴個人識別資訊建立關聯，僅保留語音解析優化所需欄位。

---

## View 層

**目錄**：`Views/`

### 主要流程頁

| View | 功能 |
|------|------|
| `IntroView` | 初次使用流程與帳戶建立入口 |
| `MainTabView` | 主容器與分頁 |
| `DashboardView` | 回本摘要與統計視圖 |
| `TripListView` | 行程列表與每日分組 |
| `AddTripView` / `EditTripView` | 行程新增編輯 |
| `CyclesView` | 週期管理 |
| `SettingsView` | 設定總入口 |

### 管理與教學頁

| View | 功能 |
|------|------|
| `FavoritesManagementView` | 常用路線管理 |
| `CommuterRoutePickerOverlay` | 通勤模板快速套用 |
| `BackupManagementView` | CloudKit 備份還原 |
| `CSVManagementView` | CSV 匯入匯出 |
| `NotificationSettingsView` | 通知設定 |
| `SpotlightTutorialView` | 聚光教學 |
| `TPASSRegionSelectionView` | 方案選擇 |
| `TransferTypeSelectionView` | 轉乘類型設定 |
| `TransferIntroductionView` | 轉乘規則導覽 |
| `HomeStationSettingsView` / `OutboundStationSettingsView` | 快捷站點管理 |
| `QuickAddHomeView` / `QuickAddOutboundView` | 站點快速新增 |
| `ReportIssueView` | 使用者提交問題回報 |
| `DeveloperToolsPlaceholderView` | 開發者入口（啟用回報推播、工具整合） |
| `DeveloperIssueReportsView` | 開發者查看回報清單 |

### 回報流程與開發者流程

#### 使用者回報流程

```
設定頁 -> 問題回報
  ↓
輸入 Email + 問題描述
  ↓
IssueReportService.submitReport
  ↓
CloudKit Public DB: IssueReport
```

#### 開發者推播啟用流程

```
關於 App -> 開發者頁
  ↓
啟用問題回報推播
  ↓
IssueReportService.setupDeveloperPushNotification
  ↓
建立 CKQuerySubscription（IssueReport 新增事件）
```

#### 開發者查看回報流程

```
開發者頁 -> 查看問題回報
  ↓
IssueReportService.fetchReports
  ↓
顯示回報清單（內容/Email/版本/時間）
```

---

## 語音快速新增功能

語音快速新增是獨立於一般手動新增（`AddTripView`）的流程，目標是降低記帳輸入成本，同時保留可編輯確認。

### 流程總覽

```
VoiceQuickTripView 開始錄音
  ↓
VoiceInputService 取得 transcript
  ↓
TripVoiceParser.parse 解析文字
  ↓
TripVoiceParser 讀取 VoiceNLP_Rules.json 規則庫
  ↓
VoiceDraft.from 產生中介資料
  ↓
VoiceQuickTripView 回填欄位 + 自動查價
  ↓
使用者確認/修正後儲存 Trip
  ↓
背景上傳 VoiceParseLog（匿名）
```

### 核心檔案與責任

| 檔案 | 職責 | 你應該在何時修改 |
|------|------|------------------|
| `Views/VoiceQuickTripView.swift` | 語音 UI 狀態流（ready/recording/parsing/preview）、欄位回填、儲存與告警 | 你要改語音頁行為、欄位同步、儲存前驗證時 |
| `Services/VoiceInputService.swift` | 錄音與語音辨識（權限/開始/停止/轉錄） | 你要改語音權限、辨識生命週期、錯誤處理時 |
| `Services/TripVoiceParser.swift` | NLP 規則解析（運具、起訖站、路線、時間、價格）與信心分數 | 你要改規則載入、解析流程、消歧策略時 |
| `Data/VoiceNLP/VoiceNLP_Rules.json` | 語音規則資料庫（關鍵字、ASR 誤聽、別名、正則、信心門檻） | 你要改語音規則但不想改 Swift 程式碼時 |
| `Models/VoiceDraft.swift` | ParsedTrip 到 UI 草稿的中介模型 | 你要新增語音欄位、調整草稿狀態判定時 |
| `Services/VoiceParseLogService.swift` | 解析結果與最終修正結果的匿名上傳 | 你要改資料蒐集欄位、隱私過濾、上傳策略時 |
| `Services/FareServices/*`、`Services/New_FareServices/*` | 各運具查價服務，供語音回填票價 | 你要改票價來源、查價邏輯、運具新規則時 |

### 目前解析能力與保護機制

- 支援從語音抽取：日期、時間、運具、起點、終點、路線、票價。
- 規則由 JSON 結構化管理，支援 priority 消歧與 ASR 誤聽容錯。
- 站名會經過別名/正規化處理，再套用各運具站點驗證。
- 公車路線抽取已調整為語意模式優先（例如「295號公車」「公車 207」），並排除時間格式（例如 12:30）誤判。
- 語音回填後會嘗試補齊線別與自動查價。
- 公車在未口述票價時，會先帶入地區方案預設公車票價。
- 台鐵儲存前會檢查是否超出該月票方案可用站點範圍，超出時會顯示警告並阻擋儲存。
- 儲存後會背景上傳匿名修正紀錄（parsedResult vs finalResult），供規則調校。

### 維護建議（語音功能）

1. 新增或調整語音關鍵字時，優先修改 `VoiceNLP_Rules.json`，再看是否需要改 `TripVoiceParser`。
2. 任何新增運具關鍵字時，請檢查是否會與既有關鍵字衝突（以 priority 與長詞優先策略消歧）。
3. 修改站名清理規則時，請至少手動回歸測試「日期 + 時段 + 時間 + 運具 + 站名」一句話輸入。
4. 若調整 VoiceParseLog 欄位，請同步更新 CloudKit Console schema 與資料清洗邏輯。
5. 若新增新運具到語音流程，需同步更新：`TransportType`、`VoiceNLP_Rules.json`、對應 FareService、`VoiceQuickTripView` 的回填/查價分支。

---

## 主題與通知系統

### 主題

- 使用 `@AppStorage("selectedTheme")` 持久化
- `ThemeManager` 控制 `colorScheme` 與 `accentColor`
- 根據主題切換全域背景、卡片色、運具色與圖表色

### 通知

- 使用 `UNUserNotificationCenter`
- 通知文字透過 `String(localized:)` 對接 `Localizable.xcstrings`
- 週期提醒計算依據 `Cycle.start` 與 `Cycle.end`
- App 啟動時由 `AppDelegate` 指派 `UNUserNotificationCenter.current().delegate`
- 一般通知在前景可使用 `.banner + .sound + .badge`
- 問題回報通知已調整為不顯示 badge，並可在開發者工具清除通知標記

---

## 備份、還原與匯入匯出

### CloudKit 備份流程

```
使用者點擊備份
  ↓
檢查 iCloud accountStatus
  ↓
組裝 TPASSBackup (schemaVersion = 2)
  ↓
JSON encode + 寫入暫存檔
  ↓
作為 CKAsset 上傳 TPASSBackupV2 record
```

### 還原流程

```
載入備份歷史（V2 + Legacy）
  ↓
下載對應備份內容
  ↓
decode snapshots
  ↓
重建 Trip/Favorite/Cycle/Commuter 資料
```

### CSV 匯入匯出

- 匯出欄位：`id,date,type,startStation,endStation,price,paidPrice,isTransfer,isFree,routeId,note,transferDiscountType,cycleId`
- 匯入會檢查重複 ID，避免重複插入
- 欄位缺漏時依相容策略採預設值

---

## 遷移與相容策略

### SwiftData Schema 版本

**檔案**：`Models/TPASSModelSchema.swift`

- `TPASSSchemaV1` → `TPASSSchemaV2`
- V2 新增：`Trip.transferDiscountType`、`FavoriteRoute.transferDiscountType`
- migration stage 使用 custom stage，新增可選欄位由 SwiftData 自動處理

### 舊資料搬遷

**檔案**：`Helpers/MigrationManager.swift`

- 從 UserDefaults 舊 key 讀取舊版 JSON：
  - `saved_trips_v1`
  - `saved_favorites_v1`
  - `saved_commuter_routes_v1`
- 搬遷成功後寫入旗標：`did_migrate_to_swiftdata_v3`

### 兼容策略摘要

- `Cycle` 支援舊 timestamp 格式與 ID 型別容錯
- `CSVManager` 支援舊/新欄位數
- `TransferDiscountType` decoding 支援舊 raw 字串

---

## 測試現況與建議

目前專案目錄中尚未見到獨立測試 target 與測試檔案。建議優先補齊以下測試：

1. `TransferDiscountType.discount(for:)` 身分分支測試
2. `TPASSRegion.supportedModes` / `supportedTransferTypes` 一致性測試
3. `AppViewModel.resolveCycle(for:)` 與 `filteredTrips` 邊界測試
4. `CSVManager` 匯入匯出 round-trip 測試
5. `CloudKitSyncService` 的備份編解碼一致性（mock）

---

## 已知限制與後續方向

1. `AppViewModel` 集中大量業務邏輯，後續可拆分成多個專責 VM 或 use-case service。
2. 啟動時仍依賴本地 session + migration，未來可進一步模組化初始化流程。
3. CloudKit 目前偏手動備份，不是全量自動同步模型。
4. 票價規則分散在多個 service，可評估加入統一 registry 層降低重複邏輯。
5. 問題回報目前僅有列表檢視，尚未提供搜尋、標記狀態與指派流程。
5. 問題回報已支援狀態更新與刪除，但尚未提供搜尋、指派與審核流程。

---

## 日常維護清單

### 新增 TPASS 方案

1. 在 `TPASSRegion` 新增 case
2. 補上 `displayNameKey`、`monthlyPrice`、`supportedModes`、`supportedTransferTypes`
3. 補齊台鐵區間 `traRegionMap` / `traStationIDRange`
4. 驗證 `TPASSRegionSelectionView`、`AddTripView`、統計頁是否正確

### 新增運具

1. 在 `TransportType` 新增 case（含 icon/color/localization key）
2. 新增對應 FareService 或補齊既有 service
3. 更新 UI 篩選、圖表顯示與轉乘邏輯

### 新增模型欄位

1. 更新 `SwiftDataModels.swift`
2. 更新 `TPASSModelSchema.swift`（必要時升版）
3. 更新 CSV 匯出入與 CloudKit snapshot 編碼
4. 補遷移與相容測試

### 維護備份功能

1. CloudKit Dashboard 確認 record type/欄位存在
2. 變更備份格式時提高 `schemaVersion`
3. 驗證 V2 與 legacy 還原都可成功

### 發版前檢查

1. 確認 `Localizable.xcstrings` 新增字串都有翻譯
2. 手動驗證週期切換、回本統計與通知排程
3. 以實機驗證備份/還原與 CSV 匯入匯出
4. 以實機驗證 IssueReport 提交、開發者訂閱建立與推播到達

---

## CloudKit Admin 管理筆記

[筆記] 如何在 CloudKit 新增其他管理員 (Admin)

事前準備：
請新加入的成員先下載並打開 App，然後請他發送一則「測試用的問題回報」（例如內容寫 `Test from [他的名字]`）。

目的：
確保他的 Apple ID 已經在 CloudKit 建立紀錄，並且能最快反查出他那串隱藏的 User ID。

步驟一：抓出該成員的 User ID

1. 登入 CloudKit Console，確認左上角環境是 Production。
2. 左側選單點選 Data -> Records。
3. 選擇 Public Database，Record Type 選擇 IssueReport，點擊 Query Records。
4. 找到該成員剛發送的「測試回報」，點進去。
5. 往下滑找到系統欄位，複製 Creator 的值（一串以 `_` 開頭的代碼），這就是該成員的專屬 User ID。

步驟二：賦予 Admin 權限

1. 留在同一個 Data -> Records 畫面，將上方 Record Type 改選為 Users，點擊 Query Records。
2. 使用剛剛複製的 User ID 在清單中找到該成員使用者紀錄，點擊進入編輯模式。
3. 在畫面最下方 Roles 區塊，輸入 Admin 並新增。
4. 點擊右上角 Save 儲存。

設定完成

這位新成員現在就能在 App 內執行需要 Public Database 管理寫入權限的操作。

目前至少包含：
- 標記問題回報完成狀態（`pending` -> `fixed`）

補充：
- 若尚未給 Admin 身分，操作會出現 `WRITE operation not permitted`。

---

如需簡版對外說明請使用 `README.md`；本文件建議作為開發與維運內部手冊。
