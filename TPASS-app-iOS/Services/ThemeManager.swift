import SwiftUI
import Combine
import UIKit //     必須引入

// MARK: - 主題定義
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    case muji = "muji"
    case purple = "purple"

    // 相容舊版（曾以中文 rawValue 持久化）
    init?(rawValue: String) {
        switch rawValue {
        case "system", "跟隨系統":
            self = .system
        case "light", "淺色模式":
            self = .light
        case "dark", "深色模式":
            self = .dark
        case "muji", "暖色風格":
            self = .muji
        case "purple", "紫色風格":
            self = .purple
        default:
            return nil
        }
    }
    
    var id: String { self.rawValue }

    var localizationKey: String {
        switch self {
        case .system: return "theme_system"
        case .light: return "theme_light"
        case .dark: return "theme_dark"
        case .muji: return "theme_muji"
        case .purple: return "theme_purple"
        }
    }

    var displayName: String {
        localizationKey
    }

    var localizedDisplayName: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }
    
    /// Asset Catalog 中對應的主題資料夾名稱
    var assetName: String {
        switch self {
        case .muji: return "Muji"
        case .purple: return "Purple"
        case .system, .light, .dark: return "System"
        }
    }
}

// MARK: - 主題管理器
class ThemeManager: ObservableObject {
    @MainActor static let shared = ThemeManager()
    
    @AppStorage("selectedTheme") var currentTheme: AppTheme = .system
    
    // MARK: - 基礎背景與文字
    var backgroundColor: AnyShapeStyle {
        return AnyShapeStyle(Color("Colors/Base/Background/\(currentTheme.assetName)"))
    }
    
    var cardBackgroundColor: Color {
        return Color("Colors/Base/CardBackground/\(currentTheme.assetName)")
    }
    
    var primaryTextColor: Color {
        switch currentTheme {
        case .muji, .purple:
            return Color("Colors/Base/PrimaryText/\(currentTheme.assetName)")
        default:
            return Color.primary
        }
    }
    
    var secondaryTextColor: Color {
        switch currentTheme {
        case .muji, .purple:
            return Color("Colors/Base/SecondaryText/\(currentTheme.assetName)")
        default:
            return Color.secondary
        }
    }
    
    //     這是 MainTabView 需要的變數
    var accentColor: Color {
        return Color("Colors/Base/Accent/\(currentTheme.assetName)")
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .light, .muji, .purple: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    // MARK: - 🎨 交通工具配色
    func transportColor(_ type: TransportType) -> Color {
        let typeName: String
        switch type {
        case .mrt: typeName = "MRT"
        case .bus: typeName = "Bus"
        case .tra: typeName = "TRA"
        case .tymrt: typeName = "TYMRT"
        case .tcmrt: typeName = "TCMRT"
        case .kmrt: typeName = "KMRT"
        case .coach: typeName = "Coach"
        case .bike: typeName = "Bike"
        case .lrt: typeName = "LRT"
        case .ferry: typeName = "Ferry"
        case .hsr: typeName = "HSR"
        }
        return Color("Colors/Transport/\(typeName)/\(currentTheme.assetName)")
    }
    
    // MARK: - 📊 圖表配色
    
    /// DNA hex 對應的語意 key 映射表
    private static let dnaHexToKey: [String: String] = [
        "#00d2ff": "DNA_MRT",
        "#2ecc71": "DNA_Bus",
        "#bdc3c7": "DNA_TRA",
        "#9b59b6": "DNA_TYMRT",
        "#ff7675": "DNA_Fanatic",
        "#55efc4": "DNA_Regular",
        "#ffeaa7": "DNA_Profit"
    ]
    
    func dnaColor(hex: String) -> Color {
        if let key = Self.dnaHexToKey[hex.lowercased()] {
            return Color("Colors/Chart/\(key)/\(currentTheme.assetName)")
        }
        // 未知的 hex 值，fallback 到直接使用
        return Color(hex: hex)
    }

    enum RecordType {
        case cost, count, single
    }
    
    func recordColor(_ type: RecordType) -> Color {
        let typeName: String
        switch type {
        case .cost: typeName = "RecordCost"
        case .count: typeName = "RecordCount"
        case .single: typeName = "RecordSingle"
        }
        return Color("Colors/Chart/\(typeName)/\(currentTheme.assetName)")
    }
    
    // MARK: - 📊 時段配色
    func slotPalette() -> [Color] {
        let slots = ["SlotDawn", "SlotMorning", "SlotAfternoon", "SlotEvening"]
        let themeName = currentTheme == .muji ? "Muji" : "System"
        return slots.map { Color("Colors/Chart/\($0)/\(themeName)") }
    }
    
    // MARK: - 📊 熱力圖配色
    func heatMapColor(level: Int) -> Color {
        guard (1...4).contains(level) else { return Color.gray.opacity(0.15) }
        let themeName = currentTheme == .muji ? "Muji" : "Default"
        return Color("Colors/Chart/HeatMap\(level)/\(themeName)")
    }
    
    // MARK: - 📊 週期配色
    var cycleAccentColor: Color {
        return Color("Colors/Cycle/\(currentTheme.assetName)")
    }
}

// MARK: -     [擴充功能] 放置於此以確保可見性
// 這裡使用了純 Swift 寫法，避免 lroundf 報錯
@available(*, deprecated, message: "Use Asset Catalog colors instead")
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        // 改用 Int() 轉換，解決 lroundf 可能產生的型別錯誤
        let ir = Int(r * 255)
        let ig = Int(g * 255)
        let ib = Int(b * 255)
        let ia = Int(a * 255)

        if a != 1.0 {
            return String(format: "#%02X%02X%02X%02X", ir, ig, ib, ia)
        } else {
            return String(format: "#%02X%02X%02X", ir, ig, ib)
        }
    }
}
