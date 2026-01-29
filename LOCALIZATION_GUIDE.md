## 多語言系統說明

### 功能概述

已成功實現 iOS App 的多語言支持系統。用戶可以在設定中輕鬆切換語言，預設為繁體中文，也可以選擇英文。

### 架構設計

#### 1. LocalizationManager (Services/LocalizationManager.swift)
- 單例模式 (Singleton)
- 管理當前語言選擇
- 提供翻譯字符串查詢
- 自動保存語言偏好設定到 UserDefaults

**主要方法：**
- `localized(_ key: String) -> String`：根據 key 獲取當前語言的翻譯
- `currentLanguage`：@Published 屬性，自動觸發 UI 刷新

#### 2. 支持的語言

| 語言 | Code | DisplayName |
|-----|------|------------|
| 繁體中文 | zh-Hant | 繁體中文 |
| 英文 | en | English |

### 使用方式

#### 1. 在 View 中使用

```swift
import SwiftUI

struct MyView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        Text(localizationManager.localized("welcomeMessage"))
    }
}
```

#### 2. 在設定中切換語言

設定頁面已新增「語言」區段，用戶可以直接選擇偏好的語言。

位置：Settings → Appearance & Style → Language

#### 3. 添加新的翻譯字符串

在 LocalizationManager 中的翻譯字典中添加：

```swift
private let chineseTranslations: [String: String] = [
    "myNewKey": "我的新文字",
    // ... 其他條目
]

private let englishTranslations: [String: String] = [
    "myNewKey": "My new text",
    // ... 其他條目
]
```

然後在 View 中使用：
```swift
Text(localizationManager.localized("myNewKey"))
```

### 已本地化的頁面

- ✅ SettingsView（設定頁面）
- ✅ AboutAppView（關於 App）
- ✅ TPASSRegionSelectionView（TPASS 地區選擇）

### 已本地化的字符串

包含以下類別的翻譯：
- 通用操作（新增、刪除、編輯等）
- 標籤欄導航
- 首頁內容
- 行程相關
- 常用路線
- 設定項目
- 通知相關
- 資料管理
- 週期管理
- 交通工具類型
- 身份類型

### 技術細節

1. **持久化存儲**：語言選擇自動保存到 UserDefaults，每次 App 啟動時會記住用戶的選擇

2. **實時更新**：LocalizationManager 是 ObservableObject，修改 currentLanguage 時會自動觸發所有使用的 View 重新渲染

3. **向後兼容**：如果翻譯 key 不存在，會返回該 key 本身（避免 App 崩潰）

### 後續擴展建議

1. 支持更多語言（簡體中文、日文、韓文等）
2. 使用 Strings Catalog（iOS 17+）進行本地化
3. 考慮使用 Localized.strings 文件以支持 App Store 本地化
4. 添加 RTL 語言支持（阿拉伯文、希伯來文等）

### 文件清單

- `Services/LocalizationManager.swift` - 本地化管理器
- `Views/SettingsView.swift` - 已更新的設定頁面
- `TPASS-app-iOS.swift` - App 入口，已注入 LocalizationManager
