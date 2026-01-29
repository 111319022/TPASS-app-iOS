import SwiftUI
import SwiftData

// MARK: - 主設定頁面
struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TripModel.createdAt, order: .reverse) private var allTripModels: [TripModel]
    @Query private var allFavoriteRouteModels: [FavoriteRouteModel]
    @StateObject private var cloudKitService = CloudKitSyncService.shared
    
    @State private var showClearDataAlert = false
    @State private var showAddCycleSheet = false
    @State private var isClearingData = false
    
    @State private var newCycleStart = Date()
    @State private var newCycleEnd = Date().addingTimeInterval(86400 * 30)
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - 1. 外觀與風格
                Section(header: Text("外觀與風格")) {
                    Picker("主題選擇", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.automatic)
                    
                    HStack {
                        Text("目前風格預覽").foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Circle().fill(themeManager.accentColor).frame(width: 20, height: 20)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - 2. TPASS 設定
                Section(header: Text("TPASS 設定")) {
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
                            Text("票種身分")
                        }
                    }
                    
                    // TPASS 地區方案選擇
                    NavigationLink(destination: TPASSRegionSelectionView()) {
                        HStack {
                            Image(systemName: "map.circle.fill").foregroundColor(.purple)
                            Text("TPASS 地區方案")
                            Spacer()
                            Text("基北北桃 $1,200")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                
                // MARK: - 3. 偏好設定
                Section(header: Text("偏好設定")) {
                    // 通知設定入口
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.badge.circle.fill").foregroundColor(.red)
                            Text("通知提醒")
                            Spacer()
                            Text(UserDefaults.standard.bool(forKey: "isDailyReminderEnabled") ? "已開啟" : "未開啟")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                
                // MARK: - 4. 資料管理 (iCloud 備份)
                Section(header: Text("資料管理 (iCloud 備份)")) {
                    NavigationLink(destination: BackupManagementView()) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("管理備份")
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                if let lastSync = cloudKitService.lastSyncDate {
                                    Text("最後備份：\(formatDate(lastSync))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("尚未備份")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                }
                
                // MARK: - 5. 週期管理
                Section(header: HStack {
                    Text("週期管理")
                    Spacer()
                    Button("新增") { showAddCycleSheet = true }
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
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                        }
                    } else {
                        Text("尚無設定週期，將使用自然月計算")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - 6. 其他
                Section {
                    NavigationLink(destination: TutorialView()) {
                        HStack {
                            Spacer()
                            Text("教學")
                            Spacer()
                        }
                    }
                    .foregroundColor(themeManager.primaryTextColor)
                }
                
                Section {
                    NavigationLink(destination: AboutAppView()) {
                        HStack {
                            Spacer()
                            Text("關於 App")
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
                            Text("清除所有資料")
                            Spacer()
                        }
                    }
                    .disabled(isClearingData)
                }
            }
            .navigationTitle("設定")
            .scrollIndicators(.hidden)
            .background(themeManager.backgroundColor)
            .scrollContentBackground(.hidden)
        }
        .alert("確定要清除所有資料嗎？", isPresented: $showClearDataAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task { await clearAllData() }
            }
        } message: {
            Text("這將清除所有行程記錄、常用路線與設定，且無法復原")
        }
        .sheet(isPresented: $showAddCycleSheet) {
            NavigationView {
                Form {
                    DatePicker("開始日期", selection: $newCycleStart, displayedComponents: .date)
                    DatePicker("結束日期", selection: $newCycleEnd, displayedComponents: .date)
                }
                .navigationTitle("新增週期")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showAddCycleSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("儲存") {
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
        allFavoriteRouteModels.forEach { modelContext.delete($0) }
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
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("作者")
                    Spacer()
                    Text("Raaay")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("© TPASS.calc. All rights reserved.")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
            }
        }
        .navigationTitle("關於 App")
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
    
    var body: some View {
        Form {
            Section(header: Text("目前適用方案")) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("基北北桃都會通")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        Text("適用範圍：基隆、台北、新北、桃園")
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
            
            Section(footer: Text("更多地區方案（如中彰投苗、南高屏）將於後續版本陸續開放，敬請期待。")) {
                HStack {
                    Text("其他地區")
                        .foregroundColor(themeManager.primaryTextColor)
                    Spacer()
                    Text("即將推出")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .opacity(0.5)
            }
        }
        .navigationTitle("選擇地區方案")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
    }
}
