import Foundation
import UserNotifications
import SwiftUI
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // 檢查授權狀態
    @Published var isAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    // 檢查權限
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.isAuthorized = true
                default:
                    #if compiler(>=5.5)
                    if #available(iOS 14.0, *), settings.authorizationStatus == .ephemeral {
                        self.isAuthorized = true
                    } else {
                        self.isAuthorized = false
                    }
                    #else
                    self.isAuthorized = false
                    #endif
                }
            }
        }
    }
    
    // 請求權限
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    print("✅ 通知權限已開通")
                } else {
                    print("❌ 通知權限被拒絕")
                }
            }
        }
    }
    
    // MARK: - 1. 每日記帳提醒
    func scheduleDailyReminder(enabled: Bool, time: Date) {
        // 先移除舊的，避免重複
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        guard enabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = LocalizationManager.shared.localized("notification_daily_title")
        content.body = LocalizationManager.shared.localized("notification_daily_body")
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("設定每日提醒失敗: \(error.localizedDescription)")
            } else {
                print("✅ 已設定每日提醒: \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
    
    // MARK: - 2. 月票到期與新週期提醒
    func scheduleCycleReminders(enabled: Bool, currentCycle: Cycle?) {
        // 移除舊的相關通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cycle_expiring_3days", "cycle_expiring_tomorrow", "cycle_new_start"])
        
        guard enabled, let cycle = currentCycle else { return }
        
        let calendar = Calendar.current
        let endDate = cycle.end
        
        // 1. 到期前 3 天提醒
        if let threeDaysBefore = calendar.date(byAdding: .day, value: -3, to: endDate), threeDaysBefore > Date() {
            let content = UNMutableNotificationContent()
            content.title = LocalizationManager.shared.localized("notification_cycle_expiring_title")
            content.body = LocalizationManager.shared.localized("notification_cycle_expiring_body")
            content.sound = .default
            
            // 設定在早上 9:00 提醒
            var components = calendar.dateComponents([.year, .month, .day], from: threeDaysBefore)
            components.hour = 9; components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "cycle_expiring_3days", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
        
        // 2. 到期當天提醒 (設定新週期提醒)
        // 邏輯：到期隔天早上提醒使用者設定新週期
        if let dayAfterEnd = calendar.date(byAdding: .day, value: 1, to: endDate), dayAfterEnd > Date() {
            let content = UNMutableNotificationContent()
            content.title = LocalizationManager.shared.localized("notification_cycle_new_title")
            content.body = LocalizationManager.shared.localized("notification_cycle_new_body")
            content.sound = .default
            
            // 設定在早上 8:30 提醒
            var components = calendar.dateComponents([.year, .month, .day], from: dayAfterEnd)
            components.hour = 8; components.minute = 30
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "cycle_new_start", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
        
        print("✅ 已更新週期相關通知 (到期日: \(endDate.formatted(date: .numeric, time: .omitted)))")
    }
}
