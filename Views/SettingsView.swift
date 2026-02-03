import SwiftUI
import SwiftData

// MARK: - 主設定頁面
struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTripModels: [Trip]
    @Query private var allFavoriteRoutes: [FavoriteRoute]
    @Query private var allCommuterRoutes: [CommuterRoute]
    @StateObject private var cloudKitService = CloudKitSyncService.shared
    
    @State private var showClearDataAlert = false
    @State private var isClearingData = false
    
    @State private var showThemeTransition = false
    @State private var selectedTheme: AppTheme?
    
    // 教學相關
    @AppStorage("hasShownTutorial_v1") private var hasShownTutorial = false
    @AppStorage("tutorialStep_v1") private var savedTutorialStep: Int = 0
    @SceneStorage("mainTab.selectedTab") private var selectedTab: Int = 0
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - 1. 外觀與風格
                Section(header: Text("appearance")) {
                    Picker("theme", selection: Binding(
                        get: { selectedTheme ?? themeManager.currentTheme },
                        set: { newTheme in
                            selectedTheme = newTheme
                            triggerThemeTransition()
                        }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.localizedDisplayName).tag(theme)
                        }
                    }
                    .pickerStyle(.automatic)
                    
                    HStack {
                        Text("currentTheme").foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Circle().fill(themeManager.accentColor).frame(width: 20, height: 20)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - 語言設定
                Section(header: Text("language")) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("language")
                            Spacer()
                            Text(Locale.current.identifier.starts(with: "en") ? "English" : "繁體中文")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                        }
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                }
                
                // MARK: - 2. TPASS 設定
                Section(header: Text("tpassSettings")) {
                    // 身分選擇
                    Picker(selection: Binding(
                        get: { auth.currentUser?.identity ?? .adult },
                        set: { auth.updateIdentity($0) }
                    )) {
                        ForEach(Identity.allCases, id: \.self) { identity in
                            Text(identity.label).tag(identity)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.text.rectangle").foregroundColor(.blue)
                            Text("ticketType")
                        }
                    }
                    
                    // TPASS 地區方案介紹
                    NavigationLink(destination: TPASSRegionSelectionView()) {
                        HStack {
                            Image(systemName: "map.circle.fill").foregroundColor(.purple)
                            Text("region_intro")
                        }
                    }
                }
                
                // MARK: - 3. 偏好設定
                Section(header: Text("preferences")) {
                    // 通知設定入口
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge.circle.fill").foregroundColor(.red)
                            Text("notifications")
                        }
                    }
                }
                
                // MARK: - 4. 資料管理 (iCloud 備份 + CSV)
                Section(header: Text("dataManagement")) {
                    // iCloud 備份
                    NavigationLink(destination: BackupManagementView()) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("manageBackup")
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                if let lastSync = cloudKitService.lastSyncDate {
                                    Text("lastBackup：\(formatDate(lastSync))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("neverBackup")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // CSV 匯出/匯入
                    NavigationLink(destination: CSVManagementView()) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("csv_export_import")
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                Text("csv_detail")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // MARK: - 5. 其他
                Section {
                    Button(action: {
                        // 重置教學到第一步
                        savedTutorialStep = 0
                        hasShownTutorial = false
                        // 切回第一個頁籤（Trips）
                        selectedTab = 0
                    }) {
                        HStack {
                            Spacer()
                            Text("tutorial")
                            Spacer()
                        }
                    }
                    .foregroundColor(themeManager.accentColor)
                }
                
                Section {
                    NavigationLink(destination: AboutAppView()) {
                        HStack {
                            Spacer()
                            Text("aboutApp")
                            Spacer()
                        }
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                }
                
                // MARK: - 7. 清除資料
                Section {
                    Button(role: .destructive) { showClearDataAlert = true } label: {
                        HStack {
                            Spacer()
                            if isClearingData {
                                ProgressView()
                            }
                            Text("clearAllData")
                            Spacer()
                        }
                    }
                    .disabled(isClearingData)
                }
            }
            .navigationTitle("settings")
            .scrollIndicators(.hidden)
            .background(themeManager.backgroundColor)
            .scrollContentBackground(.hidden)
        }
        .overlay {
            if showThemeTransition {
                ZStack {
                    // 背景色 - 使用新主題的顏色
                    Rectangle()
                        .fill(themeManager.backgroundColor)
                        .ignoresSafeArea()
                    
                    // 中心內容
                    VStack(spacing: 20) {
                        // 進度指示器
                        ProgressView()
                            .scaleEffect(1.5, anchor: .center)
                        
                        // 文字
                        VStack(spacing: 8) {
                            Text("theme")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Text("themeChanging")
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        // 主題色塊預覽
                        HStack(spacing: 12) {
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 16, height: 16)
                            
                            Circle()
                                .fill(themeManager.cardBackgroundColor)
                                .stroke(themeManager.primaryTextColor, lineWidth: 1)
                                .frame(width: 16, height: 16)
                        }
                    }
                    .padding(40)
                }
                .transition(.opacity)
            }
        }
        .alert("confirmClearData", isPresented: $showClearDataAlert) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                Task { await clearAllData() }
            }
        } message: {
            Text("clearDataWarning")
        }
    }
    
    // MARK: - 輔助函數
    
    private func triggerThemeTransition() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showThemeTransition = true
        }
        
        // 在動畫中途改變主題
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            themeManager.currentTheme = selectedTheme ?? themeManager.currentTheme
            
            // 保持遮掩一段時間
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showThemeTransition = false
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    @MainActor
    private func clearAllData() async {
        guard !isClearingData else { return }
        isClearingData = true
        defer { isClearingData = false }
        
        // 1) 清除 SwiftData 資料
        allTripModels.forEach { modelContext.delete($0) }
        allFavoriteRoutes.forEach { modelContext.delete($0) }
        allCommuterRoutes.forEach { modelContext.delete($0) }
        if let userSettings = try? modelContext.fetch(FetchDescriptor<UserSettingsModel>()) {
            userSettings.forEach { modelContext.delete($0) }
        }
        try? modelContext.save()

        // 清除記憶體中的 SwiftData 參照，避免 detached crash
        appViewModel.clearInMemoryData()
        
        // 2) 清除 UserDefaults 資料
        let keys = [
            "local_user",
            "last_cloudkit_sync_date",
            "cloudkit_auto_sync_enabled",
            "saved_trips_v1",
            "saved_favorites_v1",
            "isDailyReminderEnabled",
            "isCycleReminderEnabled"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        UserDefaults.standard.synchronize()
        
        // 3) 重置記憶體中的使用者狀態
        auth.currentUser = nil
    }
}

// MARK: - 關於 App 子頁面
struct AboutAppView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("author")
                    Spacer()
                    Text("Raaay")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("copyright")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
            }
        }
        .navigationTitle("aboutAppTitle")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
    }
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}


