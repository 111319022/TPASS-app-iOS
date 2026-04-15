import SwiftUI
import UserNotifications
import SwiftData

@main
struct TPASS_app_iOSApp: App {
    @StateObject var authService = AuthService.shared
    @StateObject var appViewModel = AppViewModel()
    @StateObject var themeManager = ThemeManager.shared

    
    //     設定 SwiftData ModelContainer
    let modelContainer: ModelContainer?
    
    init() {
        var container: ModelContainer? = nil
        do {
            //           新增這段：手動建立 Application Support 資料夾
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if !fileManager.fileExists(atPath: appSupportURL.path) {
                    print("📁 建立 Application Support 資料夾...")
                    try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
                }
            }
            //           結束
            // 先嘗試使用當前 models（不使用 versioned schema）
            // 這樣可以載入舊的非版本化資料庫
            let schema = Schema([Trip.self, FavoriteRoute.self, CommuterRoute.self, UserSettingsModel.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: config)
            print("✅ 成功載入資料庫（非版本化模式）")
        } catch {
            print("⚠️ 無法以非版本化模式載入: \(error)")
            // 如果失敗，嘗試使用版本化 schema 和 migration plan
            do {
                let schema = Schema(versionedSchema: TPASSSchemaV2.self)
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, migrationPlan: TPASSMigrationPlan.self, configurations: config)
                print("✅ 成功載入資料庫（版本化模式）")
            } catch {
                print("⚠️ 版本化模式也失敗: \(error)")
                // 最後使用記憶體模式
                let schema = Schema([Trip.self, FavoriteRoute.self, CommuterRoute.self, UserSettingsModel.self])
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                container = try? ModelContainer(for: schema, configurations: fallbackConfig)
            }
        }
        modelContainer = container
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authService.isRestoringSession {
                    LaunchSplashView()
                } else if authService.isSignedIn {
                    if let container = modelContainer {
                        MainTabView()
                            .modelContainer(container)
                    } else {
                        DataStoreErrorView()
                    }
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
                if isNowSignedIn, let userId = authService.currentUser?.id, let container = modelContainer {
                    // 登入成功時，傳入 Context 讓 ViewModel 開始搬資料
                    Task { @MainActor in
                        appViewModel.start(modelContext: container.mainContext, userId: userId)
                    }
                    
                    // 通知權限改由 onboarding NotificationCard 處理
                }
            }
            
            // 3. 處理自動登入的情況
            .onAppear {
                if authService.isSignedIn, let userId = authService.currentUser?.id, let container = modelContainer {
                    Task { @MainActor in
                        appViewModel.start(modelContext: container.mainContext, userId: userId)
                    }
                }
            }
        }
    }
}

private struct DataStoreErrorView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.orange)
            Text("資料庫初始化失敗")
                .font(.headline)
            Text("請重新啟動 App，或稍後再試。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(24)
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
