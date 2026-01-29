import SwiftUI
import SwiftData

// MARK: - 主設定頁面
struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTripModels: [Trip]
    @Query private var allFavoriteRoutes: [FavoriteRoute]
    @StateObject private var cloudKitService = CloudKitSyncService.shared
    
    @State private var showClearDataAlert = false
    @State private var showAddCycleSheet = false
    @State private var isClearingData = false
    
    @State private var newCycleStart = Date()
    @State private var newCycleEnd = Date().addingTimeInterval(86400 * 30)
    
    @State private var showThemeTransition = false
    @State private var selectedTheme: AppTheme?
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - 1. 外觀與風格
                Section(header: Text(localizationManager.localized("appearance"))) {
                    Picker(localizationManager.localized("theme"), selection: Binding(
                        get: { selectedTheme ?? themeManager.currentTheme },
                        set: { newTheme in
                            selectedTheme = newTheme
                            triggerThemeTransition()
                        }
                    )) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(localizationManager.localized(theme.localizationKey)).tag(theme)
                        }
                    }
                    .pickerStyle(.automatic)
                    
                    HStack {
                        Text(localizationManager.localized("currentTheme")).foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Circle().fill(themeManager.accentColor).frame(width: 20, height: 20)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - 語言設定
                Section(header: Text(localizationManager.localized("language"))) {
                    Picker(localizationManager.localized("language"), selection: $localizationManager.currentLanguage) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                // MARK: - 2. TPASS 設定
                Section(header: Text(localizationManager.localized("tpassSettings"))) {
                    // 身分選擇
                    Picker(selection: Binding(
                        get: { auth.currentUser?.identity ?? .adult },
                        set: { auth.updateIdentity($0) }
                    )) {
                        ForEach(Identity.allCases, id: \.self) { identity in
                            Text(localizationManager.localized("identity_\(identity.rawValue)")).tag(identity)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.text.rectangle").foregroundColor(.blue)
                            Text(localizationManager.localized("ticketType"))
                        }
                    }
                    
                    // TPASS 地區方案選擇
                    NavigationLink(destination: TPASSRegionSelectionView(localizationManager: localizationManager)) {
                        HStack {
                            Image(systemName: "map.circle.fill").foregroundColor(.purple)
                            Text(localizationManager.localized("region"))
                            Spacer()
                            Text(localizationManager.localized("region_jiapei"))
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                
                // MARK: - 3. 偏好設定
                Section(header: Text(localizationManager.localized("preferences"))) {
                    // 通知設定入口
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge.circle.fill").foregroundColor(.red)
                            Text(localizationManager.localized("notifications"))
                        }
                    }
                }
                
                // MARK: - 4. 資料管理 (iCloud 備份)
                Section(header: Text(localizationManager.localized("dataManagement"))) {
                    NavigationLink(destination: BackupManagementView()) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizationManager.localized("manageBackup"))
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                if let lastSync = cloudKitService.lastSyncDate {
                                    Text(localizationManager.localized("lastBackup") + "：\(formatDate(lastSync))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(localizationManager.localized("neverBackup"))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // MARK: - 5. 週期管理
                Section(header: HStack {
                    Text(localizationManager.localized("cycleManagement"))
                    Spacer()
                    Button(localizationManager.localized("add")) { showAddCycleSheet = true }
                        .font(.caption)
                        .foregroundColor(themeManager.accentColor)
                }) {
                    if let cycles = auth.currentUser?.cycles, !cycles.isEmpty {
                        ForEach(cycles) { cycle in
                            HStack {
                                Image(systemName: "calendar.badge.clock").foregroundColor(.orange)
                                Text(cycle.title).font(.system(.body, design: .monospaced))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        auth.deleteCycle(cycle)
                                    }
                                } label: {
                                    Label(localizationManager.localized("delete"), systemImage: "trash")
                                }
                            }
                        }
                    } else {
                        Text(localizationManager.localized("noCycleSet"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - 6. 其他
                Section {
                    NavigationLink(destination: TutorialView()) {
                        HStack {
                            Spacer()
                            Text(localizationManager.localized("tutorial"))
                            Spacer()
                        }
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                }
                
                Section {
                    NavigationLink(destination: AboutAppView(localizationManager: localizationManager)) {
                        HStack {
                            Spacer()
                            Text(localizationManager.localized("aboutApp"))
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
                            Text(localizationManager.localized("clearAllData"))
                            Spacer()
                        }
                    }
                    .disabled(isClearingData)
                }
            }
            .navigationTitle(localizationManager.localized("settings"))
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
                            Text(localizationManager.localized("theme"))
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                            
                            Text(localizationManager.localized("themeChanging"))
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
        .alert(localizationManager.localized("confirmClearData"), isPresented: $showClearDataAlert) {
            Button(localizationManager.localized("cancel"), role: .cancel) {}
            Button(localizationManager.localized("delete"), role: .destructive) {
                Task { await clearAllData() }
            }
        } message: {
            Text(localizationManager.localized("clearDataWarning"))
        }
        .sheet(isPresented: $showAddCycleSheet) {
            NavigationView {
                Form {
                    DatePicker(localizationManager.localized("startDate"), selection: $newCycleStart, displayedComponents: .date)
                    DatePicker(localizationManager.localized("endDate"), selection: $newCycleEnd, displayedComponents: .date)
                }
                .navigationTitle(localizationManager.localized("addCycle"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(localizationManager.localized("cancel")) { showAddCycleSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localizationManager.localized("save")) {
                            auth.addCycle(start: newCycleStart, end: newCycleEnd)
                            
                            let isCycleNotifOn = UserDefaults.standard.bool(forKey: "isCycleReminderEnabled")
                            if isCycleNotifOn {
                                let tempCycle = Cycle(id: UUID().uuidString, start: newCycleStart, end: newCycleEnd, displayName: "New")
                                NotificationManager.shared.scheduleCycleReminders(enabled: true, currentCycle: tempCycle)
                            }
                            
                            showAddCycleSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(300)])
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
        if let userSettings = try? modelContext.fetch(FetchDescriptor<UserSettingsModel>()) {
            userSettings.forEach { modelContext.delete($0) }
        }
        try? modelContext.save()
        
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
    let localizationManager: LocalizationManager
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text(localizationManager.localized("version"))
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text(localizationManager.localized("author"))
                    Spacer()
                    Text("Raaay")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text(localizationManager.localized("copyright"))
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
            }
        }
        .navigationTitle(localizationManager.localized("aboutAppTitle"))
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

// MARK: - TPASS 地區選擇頁面
struct TPASSRegionSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    let localizationManager: LocalizationManager
    
    var body: some View {
        Form {
            Section(header: Text(localizationManager.localized("current_plan"))) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizationManager.localized("plan_jiapei_name"))
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        Text(localizationManager.localized("plan_jiapei_scope"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("$1,200")
                        .foregroundColor(themeManager.primaryTextColor)
                    Image(systemName: "checkmark")
                        .foregroundColor(themeManager.accentColor)
                        .font(.headline)
                }
            }
            
            Section(footer: Text(localizationManager.localized("more_plans_footer"))) {
                HStack {
                    Text(localizationManager.localized("other_regions"))
                        .foregroundColor(themeManager.primaryTextColor)
                    Spacer()
                    Text(localizationManager.localized("comingSoon"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .opacity(0.5)
            }
        }
        .navigationTitle(localizationManager.localized("region_selection_title"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
    }
}
