import SwiftUI
import UserNotifications
import SwiftData

@main
struct TPASS_app_iOSApp: App {
    @StateObject var authService = AuthService.shared
    @StateObject var appViewModel = AppViewModel()
    @StateObject var themeManager = ThemeManager.shared

    
    // 🔥 設定 SwiftData ModelContainer
    let modelContainer: ModelContainer
    
    init() {
        do {
            // 🔥🔥🔥 新增這段：手動建立 Application Support 資料夾
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if !fileManager.fileExists(atPath: appSupportURL.path) {
                    print("📁 建立 Application Support 資料夾...")
                    try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
                }
            }
            // 🔥🔥🔥 結束

            // 注意：使用 SwiftDataModels.swift 裡定義的 class 名稱
            let schema = Schema([Trip.self, FavoriteRoute.self, CommuterRoute.self, UserSettingsModel.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            modelContainer = try ModelContainer(for: schema, configurations: config)
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
                        .modelContainer(modelContainer)
                } else {
                    IntroView()
                }
            }
            .environmentObject(authService)
            .environmentObject(appViewModel)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorScheme)
            .accentColor(themeManager.accentColor)
            .animation(.easeInOut(duration: 0.25), value: authService.isRestoringSession)
            .animation(.easeInOut(duration: 0.25), value: authService.isSignedIn)
            
            // 2. 監聽登入狀態並啟動 ViewModel + 執行遷移
            .onChange(of: authService.isSignedIn) { oldStatus, isNowSignedIn in
                if isNowSignedIn, let userId = authService.currentUser?.id {
                    // 登入成功時，傳入 Context 讓 ViewModel 開始搬資料
                    Task { @MainActor in
                        appViewModel.start(modelContext: modelContainer.mainContext, userId: userId)
                    }
                    
                    // 處理通知權限
                    let key = "didPromptNotificationPermission"
                    if !UserDefaults.standard.bool(forKey: key) {
                        NotificationManager.shared.requestAuthorization()
                        UserDefaults.standard.set(true, forKey: key)
                    }
                }
            }
            
            // 3. 處理自動登入的情況
            .onAppear {
                if authService.isSignedIn, let userId = authService.currentUser?.id {
                    Task { @MainActor in
                        appViewModel.start(modelContext: modelContainer.mainContext, userId: userId)
                    }
                }
            }
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
