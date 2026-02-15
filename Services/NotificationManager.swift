import Foundation
import UserNotifications
import UIKit
import Combine // 修正1：必須引入這個框架，才能使用 @Published 和 ObservableObject

@MainActor
class NotificationManager: ObservableObject {
    @MainActor static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    // 檢查權限
    func checkAuthorizationStatus() {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                // 2. 先把狀態取出來變成一個簡單的值 (Int/Enum 是安全的)
                let status = settings.authorizationStatus
                
                Task { @MainActor in
                    // 3. 在這裡只使用剛剛取出的 status，不直接碰 settings 物件
                    self.isAuthorized = (status == .authorized)
                }
            }
        }
    
    // 請求權限
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                if granted {
                    print("通知權限已授權")
                } else {
                    print("通知權限被拒絕")
                }
            }
        }
    }
    
    // MARK: - 每日提醒 (Daily Reminder)
    func scheduleDailyReminder(enabled: Bool, time: Date) {
        let identifier = "daily_reminder"
        let center = UNUserNotificationCenter.current()
        
        // 如果關閉，就移除待辦通知
        if !enabled {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        
        // 設定內容 (使用系統原生多國語系)
        let content = UNMutableNotificationContent()
        // 這裡使用 iOS 15+ 的 String(localized:)，會自動去 Localizable.xcstrings 找翻譯
        content.title = String(localized: "notification_daily_title")
        content.body = String(localized: "notification_daily_body")
        content.sound = .default
        
        // 設定時間觸發 (每天)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // 建立請求
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("每日提醒設定失敗: \(error)")
            } else {
                print("每日提醒已設定於: \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
    
    // MARK: - 週期提醒 (Cycle Reminder)
    // 提醒用戶月票快過期，或已經過期
    func scheduleCycleReminders(enabled: Bool, currentCycle: Cycle?) {
        let center = UNUserNotificationCenter.current()
        let identifiers = ["cycle_expiring", "cycle_expired"]
        
        if !enabled || currentCycle == nil {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            return
        }
        
        // 先清掉舊排程，避免重複
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        
        // 修正2：因為您的 Model 沒有 endDate，我們用 start + 30 天來推算
        guard let currentCycle else {
            print("無法設定週期提醒：找不到 cycle")
            return
        }
        let startDate = currentCycle.start
        let endDate = currentCycle.end
        guard endDate >= startDate else {
            print("無法設定週期提醒：週期結束早於開始")
            return
        }
        
        // 快到期提醒時間（提前 3 天；若不足 3 天則提前 1 天）
        let calendar = Calendar.current
        let expiringDate = calendar.date(byAdding: .day, value: -3, to: endDate) ?? endDate
        let safeExpiringDate = expiringDate < startDate
            ? (calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate)
            : expiringDate
        
        // 1. 快到期提醒 (例如前 3 天)
        scheduleNotification(
            identifier: "cycle_expiring",
            title: String(localized: "notification_cycle_expiring_title"),
            body: String(localized: "notification_cycle_expiring_body"),
            date: safeExpiringDate
        )
        
        // 2. 過期後提醒 (例如過期隔天，提醒設定新週期)
        scheduleNotification(
            identifier: "cycle_expired",
            title: String(localized: "notification_cycle_new_title"),
            body: String(localized: "notification_cycle_new_body"),
            date: calendar.date(byAdding: .day, value: 1, to: endDate)
        )
    }
    
    // 私有輔助方法
    private func scheduleNotification(identifier: String, title: String, body: String, date: Date?) {
        guard let date = date, date > Date() else { return } // 如果時間已經過了就不設
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        // 這裡預設設在早上 9:00 提醒
        var triggerComponents = components
        triggerComponents.hour = 9
        triggerComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
