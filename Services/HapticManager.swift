import UIKit

class HapticManager {
    @MainActor static let shared = HapticManager()
    
    // 通知震動 (成功/失敗/警告)
    @MainActor func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // 輕微撞擊 (適合按鈕)
    @MainActor func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
