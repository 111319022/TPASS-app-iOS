import SwiftUI
import SwiftData
import Combine

struct MainTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    // 1. 新增：引入 ThemeManager
    @EnvironmentObject var themeManager: ThemeManager
    //@EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.modelContext) private var modelContext
    
    // 控制預設選中的頁籤
    @SceneStorage("mainTab.selectedTab") private var selectedTab: Int = 0
    @AppStorage("issueReportOpenDeveloperToolsFromNotification") private var openDeveloperToolsFromNotification = false
    
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
            
            /*
            // 新增：頁籤 4: 實體卡片 NFC
            // 請確認你的檔案名稱是 CardScannerView 還是 CardView，這裡填入對應名稱
            CardScannerView()
                .tabItem {
                    // 使用 "sensor.tag.radiowaves.forward" 或 "wave.3.right" 很有感應的感覺
                    Label("Card", systemImage: "wave.3.right")
                }
                .tag(3)
            */
            
            // 頁籤 5: 設定 (順延為 tag 4，讓它保持在最右邊)
            SettingsView()
                .tabItem {
                    Label("settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        // 2. 修改：改用 ThemeManager 的顏色
        .accentColor(themeManager.accentColor)
        .onAppear {
            if openDeveloperToolsFromNotification {
                selectedTab = 4
            }
        }
        .onChange(of: openDeveloperToolsFromNotification) { _, shouldOpen in
            if shouldOpen {
                selectedTab = 4
            }
        }
    }
}
