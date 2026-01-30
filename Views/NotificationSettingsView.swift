import SwiftUI
import UIKit
import Combine

struct NotificationSettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    //@EnvironmentObject var localizationManager: LocalizationManager
    @StateObject private var notifManager = NotificationManager.shared
    
    // 持久化儲存設定
    @AppStorage("isDailyReminderEnabled") private var isDailyReminderEnabled = false
    @AppStorage("dailyReminderTime") private var dailyReminderTime = Date().addingTimeInterval(3600) // 預設當前時間+1小時
    
    @AppStorage("isCycleReminderEnabled") private var isCycleReminderEnabled = true // 預設開啟
    
    var body: some View {
        Form {
            // 權限狀態提示
            if !notifManager.isAuthorized {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("notification_permission_title")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("notification_permission_desc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("notification_go_to_settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption.bold())
                        .foregroundColor(themeManager.accentColor)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 1. 每日提醒
            Section(header: Text("notification_daily_section_title"), footer: Text("notification_daily_section_footer")) {
                Toggle("notification_daily_toggle", isOn: $isDailyReminderEnabled)
                    .onChange(of: isDailyReminderEnabled) { enabled in
                        if enabled && !notifManager.isAuthorized {
                            notifManager.requestAuthorization()
                        }
                        notifManager.scheduleDailyReminder(enabled: enabled, time: dailyReminderTime)
                    }
                
                if isDailyReminderEnabled {
                    DatePicker("notification_daily_time", selection: $dailyReminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: dailyReminderTime) { newTime in
                            notifManager.scheduleDailyReminder(enabled: true, time: newTime)
                        }
                }
            }
            
            // 2. 週期提醒
            Section(header: Text("cycleManagement"), footer: Text("notification_cycle_section_footer")) {
                Toggle("notification_cycle_toggle", isOn: $isCycleReminderEnabled)
                    .onChange(of: isCycleReminderEnabled) { enabled in
                        if enabled && !notifManager.isAuthorized {
                            notifManager.requestAuthorization()
                        }
                        // 取得最新的週期來設定
                        let currentCycle = auth.currentUser?.cycles.first // 假設第一個是最新的
                        notifManager.scheduleCycleReminders(enabled: enabled, currentCycle: currentCycle)
                    }
            }
        }
        .navigationTitle("notification_settings_title")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .onAppear {
            // 進入頁面時檢查權限狀態
            notifManager.checkAuthorizationStatus()
            
            // 確保預設時間是晚上 9:00 (如果還沒設過)
            // 這裡用一個簡單的邏輯：如果 UserDefaults 裡沒有值，我們可以給預設值
            // 但因為 @AppStorage 已經有初始值了，這裡我們手動初始化一次預設 21:00
            if UserDefaults.standard.object(forKey: "dailyReminderTime") == nil {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = 21
                components.minute = 0
                dailyReminderTime = Calendar.current.date(from: components) ?? Date()
            }
        }
    }
}
