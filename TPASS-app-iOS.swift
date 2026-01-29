import SwiftUI
import UserNotifications
import SwiftData

@main
struct TPASS_app_iOSApp: App {
    @StateObject var authService = AuthService.shared
    @StateObject var appViewModel = AppViewModel()
    
    // 🔥 引入 ThemeManager
    @StateObject var themeManager = ThemeManager.shared
    
    // 🔥 設定 SwiftData ModelContainer
    let modelContainer: ModelContainer
    
    init() {
        do {
            // 先禁用 CloudKit 自動同步，只使用本地儲存
            let config = ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            modelContainer = try ModelContainer(
                for: TripModel.self, FavoriteRouteModel.self, UserSettingsModel.self,
                configurations: config
            )
        } catch {
            fatalError("無法建立 ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authService.isRestoringSession {
                    LaunchSplashView()
                } else if authService.isSignedIn {
                    MainTabView()
                } else {
                    IntroView()
                }
            }
            .environmentObject(authService)
            .environmentObject(appViewModel)
            .environmentObject(themeManager) // 🔥 注入環境變數
            // 🔥 關鍵：強制套用 Light/Dark/Muji 模式
            .preferredColorScheme(themeManager.colorScheme)
            // 🔥 嘗試將強調色套用到全域 (影響 TabBar, NavigationBar 等)
            .accentColor(themeManager.accentColor)
            .animation(.easeInOut(duration: 0.25), value: authService.isRestoringSession)
            .animation(.easeInOut(duration: 0.25), value: authService.isSignedIn)
            // 🔔 首次登入成功後請求通知權限（只詢問一次）
            .onChange(of: authService.isSignedIn) { signedIn in
                guard signedIn else { return }
                let key = "didPromptNotificationPermission"
                if !UserDefaults.standard.bool(forKey: key) {
                    NotificationManager.shared.requestAuthorization()
                    UserDefaults.standard.set(true, forKey: key)
                }
            }
            .modelContainer(modelContainer) // 🔥 注入 SwiftData
        }
    }
}

private struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#faf9f8"), Color(hex: "#f3ebe3"), Color(hex: "#ede3d9")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color(hex: "#d97761"))
            }
        }
    }
}
