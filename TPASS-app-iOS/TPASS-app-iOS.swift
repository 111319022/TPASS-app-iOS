import SwiftUI
import UserNotifications
import SwiftData
import CloudKit

@main
struct TPASS_app_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var authService = AuthService.shared
    @StateObject var appViewModel = AppViewModel()
    @StateObject var themeManager = ThemeManager.shared

    
    //     設定 SwiftData ModelContainer
    let modelContainer: ModelContainer?
    
    init() {
        // 啟動 stdout/stderr 攔截，讓所有 print 輸出都能在 DevConsole 看到
        DevLogStore.shared.startCapturing()

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
            let schema = Schema([Trip.self, FavoriteRoute.self, CommuterRoute.self, UserSettingsModel.self, TransitCard.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            container = try ModelContainer(for: schema, configurations: config)
            print("✅ 成功載入資料庫（非版本化模式）")
        } catch {
            print("⚠️ 無法以非版本化模式載入: \(error)")
            // 如果失敗，嘗試使用版本化 schema 和 migration plan
            do {
                let schema = Schema(versionedSchema: TPASSSchemaV3.self)
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, migrationPlan: TPASSMigrationPlan.self, configurations: config)
                print("✅ 成功載入資料庫（版本化模式）")
            } catch {
                print("⚠️ 版本化模式也失敗: \(error)")
                // 最後使用記憶體模式
                let schema = Schema([Trip.self, FavoriteRoute.self, CommuterRoute.self, UserSettingsModel.self, TransitCard.self])
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

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let issueReportRouteFlagKey = "issueReportNavigateToDetail"
    private let issueReportRouteRecordIDKey = "issueReportNavigateRecordID"
    private let issueReportOpenDeveloperToolsKey = "issueReportOpenDeveloperToolsFromNotification"

    @MainActor
    private func clearAppBadge() async {
        if #available(iOS 16.0, *) {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    private func isIssueReportNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        if let recordID = userInfo["issueReportRecordID"] as? String,
           !recordID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        if let subscriptionID = userInfo["issueReportSubscriptionID"] as? String,
           subscriptionID == "developer-issue-report-subscription" {
            return true
        }

        return false
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs 註冊成功: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs 註冊失敗: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("收到遠端推播 payload: \(userInfo)")

        if let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            let subscriptionID = ckNotification.subscriptionID ?? "<nil>"

            if subscriptionID == "developer-issue-report-subscription",
               let queryNotification = ckNotification as? CKQueryNotification {
                Task { @MainActor in
                    do {
                        await clearAppBadge()

                        let publicDB = CKContainer(identifier: "iCloud.com.tpass-app.tpasscalc").publicCloudDatabase
                        guard let recordID = queryNotification.recordID else {
                            throw NSError(domain: "IssueReportNotification", code: -1, userInfo: [NSLocalizedDescriptionKey: "缺少 recordID"])
                        }

                        let record = try await publicDB.record(for: recordID)
                        let content = (record["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let email = (record["contactEmail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let preview = content.isEmpty ? "使用者回報訊息為空。" : String(content.prefix(120))

                        let notificationContent = UNMutableNotificationContent()
                        notificationContent.title = "🔧收到新的 TPASS 問題回報！"
                        notificationContent.body = preview
                        notificationContent.sound = .default
                        notificationContent.badge = nil
                        notificationContent.userInfo = [
                            "issueReportSubscriptionID": subscriptionID,
                            "issueReportEmail": email,
                            "issueReportContent": content,
                            "issueReportRecordID": record.recordID.recordName
                        ]

                        let request = UNNotificationRequest(
                            identifier: "issue-report-received-\(UUID().uuidString)",
                            content: notificationContent,
                            trigger: nil
                        )

                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            UNUserNotificationCenter.current().add(request) { error in
                                if let error {
                                    continuation.resume(throwing: error)
                                } else {
                                    continuation.resume(returning: ())
                                }
                            }
                        }
                        print("已創建本地通知，內容: \(preview)")
                    } catch {
                        print("建立本地通知失敗: \(error.localizedDescription)")
                    }
                }
            }
            
            switch ckNotification.notificationType {
            case .query:
                print("CloudKit Query 推播，subscriptionID: \(subscriptionID)")
            case .recordZone:
                print("CloudKit RecordZone 推播，subscriptionID: \(subscriptionID)")
            case .readNotification:
                print("CloudKit ReadNotification 推播，subscriptionID: \(subscriptionID)")
            case .database:
                print("CloudKit Database 推播，subscriptionID: \(subscriptionID)")
            @unknown default:
                print("CloudKit 未知類型推播，subscriptionID: \(subscriptionID)")
            }
        } else {
            print("非 CloudKit 推播 payload")
        }

        completionHandler(.newData)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        print("前景收到通知: \(userInfo)")

        if isIssueReportNotification(userInfo) {
            Task { @MainActor in
                await clearAppBadge()
            }
            completionHandler([.banner, .sound])
            return
        }

        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("使用者點擊通知: \(userInfo)")

        if let recordID = userInfo["issueReportRecordID"] as? String,
           !recordID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.set(true, forKey: issueReportRouteFlagKey)
            UserDefaults.standard.set(recordID, forKey: issueReportRouteRecordIDKey)
            UserDefaults.standard.set(true, forKey: issueReportOpenDeveloperToolsKey)
            print("已設定通知導頁目標: \(recordID)")
        }

        completionHandler()
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
                colors: [Color("Colors/Intro/IntroGradientStart"), Color("Colors/Intro/IntroGradientMid"), Color("Colors/Intro/IntroGradientEnd")],
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
                    .tint(Color("Colors/Intro/IntroAccent"))
            }
        }
    }
}
