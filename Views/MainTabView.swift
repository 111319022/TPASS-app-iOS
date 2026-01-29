import SwiftUI
import SwiftData
import Combine

struct MainTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    // 🔥 1. 新增：引入 ThemeManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.modelContext) private var modelContext
    
    // 控制預設選中的頁籤
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 頁籤 1: 行程
            TripListView()
                .tabItem {
                    Label(localizationManager.localized("trips"), systemImage: "list.bullet")
                }
                .tag(0)
            
            // 頁籤 2: 儀表板 (分析)
            DashboardView()
                .tabItem {
                    Label(localizationManager.localized("dashboardTitle"), systemImage: "chart.pie.fill")
                }
                .tag(1)
            
            // 頁籤 3: 設定
            SettingsView()
                .tabItem {
                    Label(localizationManager.localized("settings"), systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        // 🔥 2. 修改：改用 ThemeManager 的顏色，解決 Color(hex:) 報錯問題
        .accentColor(themeManager.accentColor)
    }
}
