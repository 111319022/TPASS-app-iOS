import SwiftUI
import SwiftData
import Combine

struct MainTabView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    // 🔥 1. 新增：引入 ThemeManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var modelContext
    
    // 控制預設選中的頁籤
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 頁籤 1: 行程
            TripListView()
                .tabItem {
                    Label("行程", systemImage: "list.bullet")
                }
                .tag(0)
            
            // 頁籤 2: 儀表板 (分析)
            DashboardView()
                .tabItem {
                    Label("儀表板", systemImage: "chart.pie.fill")
                }
                .tag(1)
            
            // 頁籤 3: 設定
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        // 🔥 2. 修改：改用 ThemeManager 的顏色，解決 Color(hex:) 報錯問題
        .accentColor(themeManager.accentColor)
        .onAppear {
            // 確保一進入主畫面就開始抓取資料
            if let user = auth.currentUser {
                // 這裡使用 user.id (對應 User struct 的定義)
                viewModel.start(userId: user.id)
            }
        }
    }
}
