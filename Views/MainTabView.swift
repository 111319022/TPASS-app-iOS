import SwiftUI
import SwiftData
import Combine

struct MainTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    //     1. 新增：引入 ThemeManager
    @EnvironmentObject var themeManager: ThemeManager
    //@EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.modelContext) private var modelContext
    
    // 控制預設選中的頁籤
    @SceneStorage("mainTab.selectedTab") private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 頁籤 1: 行程
            TripListView()
                .tabItem {
                    Label("trips", systemImage: "list.bullet")
                }
                .tag(0)
            
            // 頁籤 2: 儀表板 (分析)
            DashboardView()
                .tabItem {
                    Label("dashboardTitle", systemImage: "chart.pie.fill")
                }
                .tag(1)
            
            // 頁籤 3: 週期管理
            CyclesView()
                .tabItem {
                    Label("cycle_management", systemImage: "calendar.circle.fill")
                }
                .tag(2)
            
            // 頁籤 4: 設定
            SettingsView()
                .tabItem {
                    Label("settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        //     2. 修改：改用 ThemeManager 的顏色，解決 Color(hex:) 報錯問題
        .accentColor(themeManager.accentColor)
    }
}
