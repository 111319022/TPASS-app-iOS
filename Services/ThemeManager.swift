import SwiftUI
import Combine
import UIKit //     必須引入

// MARK: - 主題定義
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    case muji = "muji"

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
        }
    }

    var displayName: String {
        localizationKey
    }

    var localizedDisplayName: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }
}

// MARK: - 主題管理器
class ThemeManager: ObservableObject {
    @MainActor static let shared = ThemeManager()
    
    @AppStorage("selectedTheme") var currentTheme: AppTheme = .system
    
    // MARK: - 基礎背景與文字
    var backgroundColor: AnyShapeStyle {
        switch currentTheme {
        case .muji:
            return AnyShapeStyle(Color(hex: "#f5f0eb"))
        case .light: 
            return AnyShapeStyle(Color(uiColor: .systemGroupedBackground))
        case .dark: 
            return AnyShapeStyle(Color.black)
        case .system:
            // 跟隨系統：深色模式用黑色，淺色模式用系統背景
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? AnyShapeStyle(Color.black) : AnyShapeStyle(Color(uiColor: .systemGroupedBackground))
        }
    }
    
    var cardBackgroundColor: Color {
        switch currentTheme {
        case .muji: 
            return Color.white
        case .light: 
            return Color.white
        case .dark: 
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .system:
            // 跟隨系統：根據當前深/淺色模式返回相應顏色
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
        }
    }
    
    var primaryTextColor: Color {
        switch currentTheme {
        case .muji: return Color(hex: "#434343")
        default: return Color.primary
        }
    }
    
    var secondaryTextColor: Color {
        switch currentTheme {
        case .muji: return Color(hex: "#8c8c8c")
        default: return Color.secondary
        }
    }
    
    //     這是 MainTabView 需要的變數
    var accentColor: Color {
        switch currentTheme {
        case .muji: 
            return Color(hex: "#B07D62")
        case .dark: 
            return Color(hex: "#5AC8FA")
        case .light:
            return Color.blue
        case .system:
            // 跟隨系統：深色模式用淺藍色，淺色模式用藍色
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? Color(hex: "#5AC8FA") : Color.blue
        }
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .light, .muji: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    // MARK: - 🎨 交通工具配色
    func transportColor(_ type: TransportType) -> Color {
        // 判斷是否為深色模式
        let isDark: Bool = {
            switch currentTheme {
            case .dark:
                return true
            case .light, .muji:
                return false
            case .system:
                return UITraitCollection.current.userInterfaceStyle == .dark
            }
        }()
        
        switch currentTheme {
        case .muji:
            switch type {
            case .mrt: return Color(hex: "#4A90E2")
            case .bus: return Color(hex: "#6BCB77")
            case .tra: return Color(hex: "#9E9E9E")
            case .tymrt: return Color(hex: "#B388EB")
            case .tcmrt: return Color(hex: "#C41E3A")
            case .kmrt: return Color(hex: "#E67E22")
            case .coach: return Color(hex: "#3E8E41")
            case .bike: return Color(hex: "#FF7F50")
            case .lrt: return Color(hex: "#FFD93D")
            case .ferry: return Color(hex: "#1E88E5")
            }
        case .system where isDark, .dark:
            // 深色模式（包括跟隨系統且當前為深色）
            switch type {
            case .mrt: return Color(hex: "#5AC8FA")
            case .bus: return Color(hex: "#30D158")
            case .tra: return Color(hex: "#AFAFAF")
            case .tymrt: return Color(hex: "#BF5AF2")
            case .tcmrt: return Color(hex: "#FF6B6B")
            case .kmrt: return Color(hex: "#FFA94D")
            case .lrt: return Color(hex: "#FFD60A")
            case .coach: return Color(hex: "#FF453A")
            case .bike: return Color(hex: "#FF9F0A")
            case .ferry: return Color(hex: "#64B5F6")
            }
        default:
            return type.color
        }
    }
    
    // MARK: - 📊 圖表配色
    func dnaColor(hex: String) -> Color {
        if currentTheme == .muji {
            switch hex.lowercased() {
            case "#00d2ff": return Color(hex: "#2E86AB")
            case "#2ecc71": return Color(hex: "#58A858")
            case "#bdc3c7": return Color(hex: "#757575")
            case "#9b59b6": return Color(hex: "#9B6EB8")
            case "#ff7675": return Color(hex: "#E85D3F")
            case "#55efc4": return Color(hex: "#2D5A27")
            case "#ffeaa7": return Color(hex: "#F2C94C")
            default: return Color(hex: hex).opacity(0.9)
            }
        }
        return Color(hex: hex)
    }

    enum RecordType {
        case cost, count, single
    }
    
    func recordColor(_ type: RecordType) -> Color {
        switch currentTheme {
        case .muji:
            switch type {
            case .cost:   return Color(hex: "#D1605E")
            case .count:  return Color(hex: "#E09F3E")
            case .single: return Color(hex: "#8D7B9F")
            }
        default:
            switch type {
            case .cost:   return .red
            case .count:  return .orange
            case .single: return .purple
            }
        }
    }
}

// MARK: -     [擴充功能] 放置於此以確保可見性
// 這裡使用了純 Swift 寫法，避免 lroundf 報錯
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
