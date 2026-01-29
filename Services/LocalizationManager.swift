import Foundation
import Combine

// MARK: - 語言列舉
enum Language: String, CaseIterable {
    case traditionalChinese = "zh-Hant"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .traditionalChinese:
            return "繁體中文"
        case .english:
            return "English"
        }
    }
    
    var code: String {
        self.rawValue
    }
}

// MARK: - 本地化管理器
class LocalizationManager: NSObject, ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
            UserDefaults.standard.synchronize()
            objectWillChange.send()
        }
    }
    
    override init() {
        let saved = UserDefaults.standard.string(forKey: "AppLanguage") ?? "zh-Hant"
        self.currentLanguage = Language(rawValue: saved) ?? .traditionalChinese
        super.init()
    }
    
    // 獲取本地化字符串
    func localized(_ key: String) -> String {
        let translations = getTranslations()
        return translations[key] ?? key
    }

    // 獲取本地化字串並套用格式化參數（例如："已新增：%@"）
    func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        let template = localized(key)
        guard !args.isEmpty else { return template }

        let localeIdentifier: String = {
            switch currentLanguage {
            case .english:
                return "en"
            case .traditionalChinese:
                return "zh_Hant_TW"
            }
        }()

        return String(format: template, locale: Locale(identifier: localeIdentifier), arguments: args)
    }
    
    // 根據當前語言返回翻譯字典
    private func getTranslations() -> [String: String] {
        switch currentLanguage {
        case .english:
            return englishTranslations
        case .traditionalChinese:
            return chineseTranslations
        }
    }
    
    // 繁體中文翻譯
    private let chineseTranslations: [String: String] = [
                // 時段標籤
                "early_morning": "清晨/深夜",
                "morning": "早上",
                "afternoon": "中午",
                "night": "晚上",
            "transfer_saving": "轉乘省下",
            "rebate_total": "回饋金總額",
        // 通用
        "cancel": "取消",
        "save": "儲存",
        "delete": "刪除",
        "edit": "編輯",
        "add": "新增",
        "confirm": "確定",
        "close": "關閉",
        
        // 標籤欄
        "dashboard": "首頁",
        "trips": "行程",
        "favorites": "常用",
        "settings": "設定",
        
        // 首頁
        "welcome": "歡迎使用 TPASS.calc",
        "totalSpent": "總消費",
        "monthlyRecord": "月度記錄",
        "recentTrips": "最近行程",
        "noTripsRecorded": "尚無行程記錄",
        
        // 行程相關
        "tripList": "行程列表",
        "addTrip": "新增行程",
        "editTrip": "編輯行程",
        "deleteTrip": "刪除行程",
        "selectTransport": "選擇交通工具",
        "startStation": "起站",
        "endStation": "終站",
        "price": "票價",
        "date": "日期",
        "time": "時間",
        "notes": "備註",
        
        // 常用路線
        "favoriteRoutes": "常用路線",
        "addFavoriteRoute": "新增常用路線",
        "editFavoriteRoute": "編輯常用路線",
        "deleteFavoriteRoute": "刪除常用路線",
        "commuterRoutes": "通勤路線",

        
        // 設定
        "appearance": "外觀與風格",
        "language": "語言",
        "theme": "主題選擇",    
        "currentTheme": "目前風格預覽",
        "themeChanging": "更換中...",
        
        "tpassSettings": "TPASS 設定",
        "ticketType": "票種身分",
        "region": "TPASS 地區方案",
        "region_jiapei": "基北北桃 $1,200",
        "region_zhongzhangmiao": "中彰投苗",
        "region_nankaoping": "南高屏",
        "comingSoon": "即將推出",
        
        "preferences": "偏好設定",
        "notifications": "通知提醒",
        "enabled": "已開啟",
        "disabled": "未開啟",
        
        "dataManagement": "資料管理 (iCloud 備份)",
        "manageBackup": "管理備份",
        "lastBackup": "最後備份",
        "neverBackup": "尚未備份",
        
        "cycleManagement": "週期管理",
        "noCycleSet": "尚無設定週期，將使用自然月計算",
        "addCycle": "新增週期",
        "startDate": "開始日期",
        "endDate": "結束日期",
        "deleteCycle": "刪除週期",
        
        "other": "其他",
        "tutorial": "教學",
        "aboutApp": "關於 App",
        "clearAllData": "清除所有資料",
        "clearDataWarning": "這將清除所有行程記錄、常用路線與設定，且無法復原",
        "confirmClearData": "確定要清除所有資料嗎？",
        
        "aboutAppTitle": "關於 App",
        "version": "版本",
        "author": "作者",
        "copyright": "© TPASS.calc. All rights reserved.",
        
        // Dashboard 儀表板
        "dashboardTitle": "儀表板",
        "currentCycleAuto": "本月週期 (自動)",
        "depthInsight": "運具深度透視",
        "weekday": "平日",
        "weekend": "假日",
        "timeDistribution": "時段分布 (次數)",
        "topRoutes": "Top 5 熱門路線",
        "totalTrips": "總行程數",
        "trips_unit": "趟",
        "breakeven": "回本率",
        "actualExpense": "實際總支出(扣回饋)",
        "vs": "VS",
        "tpassCost": "TPASS成本",
        "breakeven_complete": "🎉 已回本！省下%@",
        "notBreakeven": "💸 尚未回本 (差%@)",
        "average": "平均",
        "highest": "最高",
        "actualPayment": "實付",
        "percentage": "佔",
        
        // Dashboard 詳細頁面
        "totalTrips_label": "總行程數",
        "breakeven_rate": "回本率",
        "originalPrice": "原始票價總額",
        "actualExpenseDetail": "實際扣款總額",
        "actualExpenseNote": "(扣轉乘)",
        "commonRebate": "常客優惠回饋 (R1)",
        "tpass2Rebate": "TPASS 2.0 回饋 (R2)",
        "maxDailyExpense": "單日最高實付",
        "maxDailyBusy": "單日最忙碌",
        "maxSingleTrip": "單筆最貴",
        "tpassRaceProgress": "TPASS 回本競速",
        "commuterHeatmap": "通勤熱力圖",
        "transportInsight": "運具深度透視",
        
        // 交通工具
        "mrt": "北捷",
        "tymrt": "機捷",
        "tra": "台鐵",
        "lrt": "輕軌",
        "bus": "公車",
        "coach": "客運",
        "bike": "Ubike",
        
        // 身份類型
        "adult": "成人",
        "student": "學生",
        "senior": "長者",
        "child": "孩童",
        
        // TripListView
        "addTrip_btn": "記一筆",
        "favorites_btn": "常用路線",
        "duplicate_day": "複製整日",
        "delete_day": "刪除整日",
        "confirm_duplicate": "確定要複製 %@ 的整日行程？",
        "confirm_delete_day": "確定要刪除 %@ 的整日行程？",
        "add_to_favorites": "加入常用路線",
        "add_to_commuter": "加入通勤路線",
        "duplicate_trip": "複製",
        "return_trip": "回程",
        "cancel_transfer": "取消轉乘",
        "add_transfer": "補轉乘",
        "trip_duplicated": "已複製行程",
        "transfer_cancelled": "已取消轉乘",
        "transfer_added": "已標記轉乘",
        "commuter_name_prompt": "請輸入通勤路線名稱",
        "commuter_name_placeholder": "例如：去公司",
        "add_commuter": "加入",
        "commuter_added": "已加入通勤：%@",
        "choose_commuter": "加入通勤路線",
        "choose_commuter_desc": "選擇現有通勤路線或新增",
        "add_other": "新增其他",
        "no_commuter": "無通勤路線",
        "day_actions": "要對 %@ 做什麼？",
        "day_actions_title": "整日操作",
        "trip_deleted": "已刪除行程",
        "trip_added": "行程已新增",
        "trip_updated": "行程已更新",
        "favorites_added": "已新增：%@",
        "favorites_added_commuter": "已新增通勤：%@",
        "favorite_route_added": "已加入常用路線",
        "original_price_label": "原價",
        "copied_day": "已複製 %@ 行程到今日",
        "deleted_day": "已刪除 %@ 行程",
        
        // AddTripView
        "add_trip_title": "新增行程",
        "close_btn": "✕",
        "select_date": "日期",
        "select_time": "時間",
        "select_transport": "選擇交通工具",
        "route_number": "路線編號",
        "route_example": "輸入路線編號 (例: %@)",
        "start_point": "起點",
        "select_start_station": "選擇車站",
        "end_point": "終點",
        "select_end_station": "選擇車站",
        "select_route": "選擇路線",
        "select_route_first": "請先選路線",
        "select_station": "選擇車站",
        "enter_station_name": "輸入%@站名",
        "price_amount": "$",
        "price_placeholder": "金額",
        "free_trip": "免費",
        "transfer": "轉乘",
        "transfer_discount": "-",
        "notes_placeholder_add": "備註 (可選)...",
        "submit_button": "加入計算",
        
        // EditTripView
        "edit_trip_title": "編輯行程",
        "update_button": "更新資訊",
        "route_placeholder": "Enter Route No. (e.g. 307)",
        "station_placeholder_start": "起點",
        "station_placeholder_end": "終點",
        "amount_placeholder": "Amount",
        "notes_placeholder": "備註（選填）",
        "transfer_label": "轉乘 (-",

        // Theme names
        "theme_system": "跟隨系統",
        "theme_light": "淺色模式",
        "theme_dark": "深色模式",
        "theme_muji": "暖色風格",

        // Identity labels
        "identity_adult": "全票",
        "identity_student": "學生",

        // TPASS Region Selection
        "region_selection_title": "選擇地區方案",
        "current_plan": "目前適用方案",
        "plan_jiapei_name": "基北北桃都會通",
        "plan_jiapei_scope": "適用範圍：基隆、台北、新北、桃園",
        "other_regions": "其他地區",
        "more_plans_footer": "更多地區方案（如中彰投苗、南高屏）將於後續版本陸續開放，敬請期待。",

        // Notification Settings
        "notification_settings_title": "通知設定",
        "notification_permission_title": "尚未開啟通知權限",
        "notification_permission_desc": "請至 iPhone 的「設定」>「TPASS.calc」開啟通知，才能接收提醒。",
        "notification_go_to_settings": "前往設定",
        "notification_daily_section_title": "每日習慣",
        "notification_daily_section_footer": "養成每日記錄的好習慣，數據更準確。",
        "notification_daily_toggle": "每日記帳提醒",
        "notification_daily_time": "提醒時間",
        "notification_cycle_section_footer": "在月票到期前提醒您，並在過期後提醒設定新週期。",
        "notification_cycle_toggle": "月票到期與續購提醒",

        // Dashboard DNA tags
        "dna_mrt_addict": "🚇 北捷成癮者",
        "dna_mrt_addict_desc": "捷運搭乘次數居冠",
        "dna_bus_master": "🚌 公車達人",
        "dna_bus_master_desc": "公車搭乘次數居冠",
        "dna_tra_fan": "🚆 鐵道迷",
        "dna_tra_fan_desc": "台鐵搭乘次數居冠",
        "dna_tymrt_flyer": "✈️ 國門飛人",
        "dna_tymrt_flyer_desc": "機捷搭乘次數居冠",
        "dna_fanatic_commuter": "🔥 狂熱通勤",
        "dna_fanatic_commuter_desc": "累積行程超過 100 趟",
        "dna_regular_life": "📅 規律生活",
        "dna_regular_life_desc": "累積行程超過 50 趟",
        "dna_netprofit_king": "💸 倒賺省長",
        "dna_netprofit_king_desc": "淨收益超過 $1200",
        "dna_breakeven_master": "💰 回本大師",
        "dna_breakeven_master_desc": "已回本開始獲利",
        "dna_early_bird": "☀️ 早鳥部隊",
        "dna_early_bird_desc": "08:00 前行程佔比 > 30%",
        "dna_night_owl": "🌙 深夜旅人",
        "dna_night_owl_desc": "21:00 後行程佔比 > 20%",
        "dna_rail_friend": "🚉 軌道之友",
        "dna_rail_friend_desc": "80% 以上行程使用軌道運輸",
        "dna_bike_pioneer": "🚴 腳動力先鋒",
        "dna_bike_pioneer_desc": "Ubike 搭乘超過 10 趟",
        "dna_cross_region": "🏙️ 跨區移動者",
        "dna_cross_region_desc": "客運搭乘超過 5 趟",
        "dna_energy_full": "🔋 能量滿點",
        "dna_energy_full_desc": "單日搭乘超過 10 趟",

        // Common UI
        "done": "完成",

        // Tutorial
        "tutorial_trip_history_title": "行程紀錄",
        "tutorial_card_add_data": "新增資料",
        "tutorial_card_more_features": "更多功能",
        "tutorial_card_quick_delete": "快速刪除（左滑）",
        "tutorial_card_quick_add": "快速新增（右滑）",
        "tutorial_upload_image": "請上傳 %@",

        // Intro
        "intro_welcome_title": "歡迎來到\nTPASS回本計算機",
        "intro_swipe_more": "滑動查看更多",
        "intro_feature_1_title": "通勤，也要精打細算",
        "intro_feature_1_desc": "專為基北北桃通勤族打造。\n1200 買下去，到底有沒有回本？\n讓我們幫你算清楚。",
        "intro_feature_2_title": "智慧轉乘與優惠",
        "intro_feature_2_desc": "自動扣除轉乘優惠 ($8/$6)。\n支援「常客優惠」階梯回饋\n與「TPASS 2.0」運具補貼計算。",
        "intro_feature_3_title": "彈性週期設定",
        "intro_feature_3_desc": "不限於每月 1 號！\n自訂月票啟用日，\n自動計算 30 天效期內的每一筆回饋。",
        "intro_feature_4_title": "深度數據儀表板",
        "intro_feature_4_desc": "全新推出「通勤熱力圖」與「回本競速」。\n視覺化分析您的平日/假日貢獻，\n與每一筆支出的詳細結構。",
        "intro_start_title": "開始使用",
        "intro_choose_identity_desc": "請選擇您的票種身分\n這將影響轉乘優惠的計算",
        "intro_identity_adult_title": "全票 (成人)",
        "intro_identity_student_title": "學生票",
        "intro_identity_transfer_discount": "轉乘折 $%d",
        "intro_start_button": "開始使用",
        "intro_data_stored_local": "資料將儲存在您的裝置上",

        // Favorites / Commuter
        "favorites_empty_title": "尚無常用或通勤路線",
        "favorites_empty_desc": "長按行程可加入常用或通勤路線，方便快速新增",
        "favorites_empty_favorites_only_desc": "長按行程以選擇新增至「常用路線」",
        "favorites_empty_commuter_only_desc": "長按行程以選擇新增至「通勤路線」",
        "commuter_route": "通勤路線",
        "commuter_route_empty": "此通勤路線尚無項目",
        "count_trips": "%d 趟",

        // Backup
        "backup_upload_section_title": "上傳本地數據到 iCloud",
        "backup_upload_section_desc": "將目前的行程、常用路線與週期備份到 iCloud",
        "backup_upload_now": "立即上傳備份",
        "backup_last_upload": "最後上傳：%@",
        "backup_restore_section_title": "從 iCloud 恢復備份",
        "backup_restore": "恢復",
        "backup_footer": "• 上傳：將本地數據備份到 iCloud\n• 恢復：選擇 iCloud 上的備份版本還原本地數據\n• 所有操作均為手動執行，不會自動同步",
        "backup_nav_title": "備份管理",
        "backup_sheet_title": "上傳備份到 iCloud",
        "backup_sheet_desc": "將上傳 %@",
        "backup_trip_count": "%d 行程",
        "backup_favorite_count": "%d 常用路線",
        "backup_cycle_count": "%d 週期",
        "backup_upload": "上傳",
        "backup_confirm_restore_title": "確認恢復",
        "backup_confirm_restore_message": "恢復後會清除目前裝置上的資料並以此備份覆蓋，請先確認本機最新資料已備份",
        "backup_confirm_restore_action": "確認恢復",
        "backup_confirm_delete_title": "確認刪除",
        "backup_confirm_delete_message": "此操作將永久刪除 iCloud 上的備份，無法恢復",
        "backup_confirm_delete_action": "確認刪除",
        "backup_operation_success": "操作成功",
        "backup_operation_failed": "操作失敗",
        "backup_summary": "%d 筆行程、%d 個常用路線、%d 個週期",
        "backup_upload_success_title": "上傳成功",
        "backup_upload_success_message": "備份已上傳到 iCloud\n%@",
        "backup_upload_failed": "上傳失敗：%@",
        "backup_restore_success_title": "恢復成功",
        "backup_restore_success_message": "備份已恢復\n行程: %d\n常用路線: %d\n週期: %d",
        "backup_restore_failed": "恢復失敗：%@",
        "backup_delete_success_title": "刪除成功",
        "backup_delete_success_message": "備份已成功刪除",
        "backup_delete_failed": "刪除失敗：%@",

        // Notifications (content)
        "notification_daily_title": "今天搭車了嗎？🚌",
        "notification_daily_body": "記得記錄今天的行程，看看離回本還有多遠！",
        "notification_cycle_expiring_title": "TPASS 即將到期 📅",
        "notification_cycle_expiring_body": "您的定期票將在 3 天後到期，記得評估是否續購喔！",
        "notification_cycle_new_title": "新的週期開始了！🚀",
        "notification_cycle_new_body": "如果您已續購 TPASS，請記得在 App 內設定新週期，開始新的回本挑戰！",

        // AppViewModel label building
        "current_cycle_month": "本月週期",
        "route_title_bus": "%@路 (%@)",
        "month_short": "%d月",
        "rebate_r1_mrt_item": "[%@] 北捷 %d趟 (%d%%)",
        "rebate_r1_tra_item": "[%@] 台鐵 %d趟 (%d%%)",
        "rebate_r2_rail_item": "[%@] 軌道 %d趟 (2%)",
        "rebate_r2_bus_item": "[%@] 公車 %d趟 (%d%%)",
        "transport_count": "%@ (%d趟)",

        // CloudKit error messages
        "cloudkit_unavailable_check_signin": "iCloud 帳號不可用，請檢查登入狀態",
        "cloudkit_unavailable": "iCloud 帳號不可用",
        "cloudkit_partial_upload_failed": "部分記錄上傳失敗 (%d 筆)",
    ]
    
    // 英文翻譯
    private let englishTranslations: [String: String] = [
                // Time slot labels
                "early_morning": "Early, Late Night",
                "morning": "Morning",
                "afternoon": "Afternoon",
                "night": "Night",
            "transfer_saving": "Transfer Saving",
            "rebate_total": "Total Rebate",
        // Common
        "cancel": "Cancel",
        "save": "Save",
        "delete": "Delete",
        "edit": "Edit",
        "add": "Add",
        "confirm": "Confirm",
        "close": "Close",
        
        // Tab Bar
        "dashboard": "Dashboard",
        "trips": "Trips",
        "favorites": "Favorites",
        "settings": "Settings",
        
        // Dashboard
        "welcome": "Welcome to TPASS.calc",
        "totalSpent": "Total Spent",
        "monthlyRecord": "Monthly Record",
        "recentTrips": "Recent Trips",
        "noTripsRecorded": "No trips recorded",
        
        // Trips
        "tripList": "Trip List",
        "addTrip": "Add Trip",
        "editTrip": "Edit Trip",
        "deleteTrip": "Delete Trip",
        "selectTransport": "Select Transport",
        "startStation": "Start Station",
        "endStation": "End Station",
        "price": "Price",
        "date": "Date",
        "time": "Time",
        "notes": "Notes",
        
        // Favorites
        "favoriteRoutes": "Favorite Routes",
        "addFavoriteRoute": "Add Favorite Route",
        "editFavoriteRoute": "Edit Favorite Route",
        "deleteFavoriteRoute": "Delete Favorite Route",
        "commuterRoutes": "Commuter Routes",

        
        // Settings
        "appearance": "Appearance & Style",
        "language": "Language",
        "theme": "Theme",
        "currentTheme": "Current Theme Preview",
        "themeChanging": "Changing...",

        
        "tpassSettings": "TPASS Settings",
        "ticketType": "Ticket Type",
        "region": "TPASS Plan",
        "region_jiapei": "MegaCity Pass $1,200",
        "region_zhongzhangmiao": "Central Taiwan Pass",
        "region_nankaoping": "Southern Taiwan Pass $999",
        "comingSoon": "Coming Soon",
        
        "preferences": "Preferences",
        "notifications": "Notifications",
        "enabled": "Enabled",
        "disabled": "Disabled",
        
        "dataManagement": "Data Management (iCloud Backup)",
        "manageBackup": "Manage Backup",
        "lastBackup": "Last Backup",
        "neverBackup": "Never backed up",
        
        "cycleManagement": "Cycle Management",
        "noCycleSet": "No cycle set. Using calendar month.",
        "addCycle": "Add Cycle",
        "startDate": "Start Date",
        "endDate": "End Date",
        "deleteCycle": "Delete Cycle",
        
        "other": "Other",
        "tutorial": "Tutorial",
        "aboutApp": "About App",
        "clearAllData": "Clear All Data",
        "clearDataWarning": "This will clear all trip records, favorite routes and settings, and cannot be undone.",
        "confirmClearData": "Are you sure you want to clear all data?",
        
        "aboutAppTitle": "About App",
        "version": "Version",
        "author": "Author",
        "copyright": "© TPASS.calc. All rights reserved.",
        
        // Dashboard
        "dashboardTitle": "Dashboard",
        "currentCycleAuto": "Current Month Cycle (Auto)",
        "depthInsight": "Transport Type Insights",
        "weekday": "Weekday",
        "weekend": "Weekend",
        "timeDistribution": "Time Distribution (Trips)",
        "topRoutes": "Top 5 Popular Routes",
        "totalTrips": "Total Trips",
        "trips_unit": " trips",
        "breakeven": "Breakeven Rate",
        "actualExpense": "Actual Expense",
        "vs": "VS",
        "tpassCost": "TPASS Cost",
        "breakeven_complete": "🎉 Breakeven! Saved %@",
        "notBreakeven": "💸 Not breakeven yet (Diff %@)",
        "average": "Average",
        "highest": "Highest",
        "actualPayment": "Actual Payment",
        "percentage": "Percentage",
        
        // Dashboard Details
        "totalTrips_label": "Total Trips",
        "breakeven_rate": "Breakeven Rate",
        "originalPrice": "Original Total Price",
        "actualExpenseDetail": "Actual Total Expense",
        "actualExpenseNote": "(After Transfer Deduction)",
        "commonRebate": "Common Rebate (R1)",
        "tpass2Rebate": "TPASS 2.0 Rebate (R2)",
        "maxDailyExpense": "Max Daily Expense",
        "maxDailyBusy": "Busiest Day",
        "maxSingleTrip": "Most Expensive Trip",
        "tpassRaceProgress": "TPASS Breakeven Progress",
        "commuterHeatmap": "Commuter Heatmap",
        "transportInsight": "Transport Type Insights",
        
        // Transport
        "mrt": "MRT",
        "tymrt": "A.P. MRT",
        "tra": "TR",
        "lrt": "LRT",
        "bus": "Bus",
        "coach": "Coach",
        "bike": "Ubike",
        
        // Identity
        "adult": "Adult",
        "student": "Student",
        "senior": "Senior",
        "child": "Child",
        
        // TripListView
        "addTrip_btn": "Log Trip",
        "favorites_btn": "Favorites",
        "duplicate_day": "Duplicate Day",
        "delete_day": "Delete Day",
        "confirm_duplicate": "Confirm duplicating all trips from %@?",
        "confirm_delete_day": "Confirm deleting all trips from %@?",
        "add_to_favorites": "Add to Favorites",
        "add_to_commuter": "Add to Commuter Route",
        "duplicate_trip": "Duplicate",
        "return_trip": "Return Trip",
        "cancel_transfer": "Cancel Transfer",
        "add_transfer": "Mark Transfer",
        "trip_duplicated": "Trip duplicated",
        "transfer_cancelled": "Transfer cancelled",
        "transfer_added": "Transfer marked",
        "commuter_name_prompt": "Enter commuter route name",
        "commuter_name_placeholder": "e.g. To Office",
        "add_commuter": "Add",
        "commuter_added": "Added commuter: %@",
        "choose_commuter": "Add to Commuter Route",
        "choose_commuter_desc": "Select existing or create new",
        "add_other": "Add New",
        "no_commuter": "No Commuter Routes",
        "day_actions": "What to do with %@?",
        "day_actions_title": "Day Actions",
        "trip_deleted": "Trip deleted",
        "trip_added": "Trip added",
        "trip_updated": "Trip updated",
        "favorites_added": "Added: %@",
        "favorites_added_commuter": "Added commuter: %@",
        "favorite_route_added": "Added to favorites",
        "original_price_label": "Original",
        "copied_day": "Copied %@ trips to today",
        "deleted_day": "Deleted trips from %@",
        
        // AddTripView
        "add_trip_title": "Add Trip",
        "close_btn": "✕",
        "select_date": "Date",
        "select_time": "Time",
        "select_transport": "Select Transport",
        "route_number": "Route No.",
        "route_example": "Enter Route No. (e.g. %@)",
        "start_point": "Start",
        "select_start_station": "Select Station",
        "end_point": "End",
        "select_end_station": "Select Station",
        "select_route": "Select Line",
        "select_route_first": "Select a line first",
        "select_station": "Select Station",
        "enter_station_name": "Enter %@ station name",
        "price_amount": "$",
        "price_placeholder": "Amount",
        "free_trip": "Free",
        "transfer": "Transfer",
        "transfer_discount": "-",
        "notes_placeholder_add": "Notes (optional)...",
        "submit_button": "Add Trip",
        
        // EditTripView
        "edit_trip_title": "Edit Trip",
        "update_button": "Update Info",
        "route_placeholder": "Enter Route No. (e.g. 307)",
        "station_placeholder_start": "Start",
        "station_placeholder_end": "End",
        "amount_placeholder": "Amount",
        "notes_placeholder": "Notes (optional)",
        "transfer_label": "Transfer (-",

        // Theme names
        "theme_system": "System",
        "theme_light": "Light",
        "theme_dark": "Dark",
        "theme_muji": "Warm Style",

        // Identity labels
        "identity_adult": "Adult",
        "identity_student": "Student",

        // TPASS Region Selection
        "region_selection_title": "Select TPASS Plan",
        "current_plan": "Current Plan",
        "plan_jiapei_name": "MegaCity Pass",
        "plan_jiapei_scope": "Coverage: Keelung, Taipei, New Taipei, Taoyuan",
        "other_regions": "Other Regions",
        "more_plans_footer": "More regional plans (e.g. Pass for Central & Southern Taiwan) will be available in future updates.",

        // Notification Settings
        "notification_settings_title": "Notification Settings",
        "notification_permission_title": "Notifications not enabled",
        "notification_permission_desc": "Go to iPhone Settings > TPASS.calc to enable notifications.",
        "notification_go_to_settings": "Open Settings",
        "notification_daily_section_title": "Daily Habit",
        "notification_daily_section_footer": "Build a daily logging habit for more accurate stats.",
        "notification_daily_toggle": "Daily reminder",
        "notification_daily_time": "Reminder time",
        "notification_cycle_section_footer": "Get reminders before your pass expires and after it expires.",
        "notification_cycle_toggle": "Pass expiry & renewal reminders",

        // Dashboard DNA tags
        "dna_mrt_addict": "🚇 MRT Addict",
        "dna_mrt_addict_desc": "Most trips by MRT",
        "dna_bus_master": "🚌 Bus Master",
        "dna_bus_master_desc": "Most trips by bus",
        "dna_tra_fan": "🚆 Rail Fan",
        "dna_tra_fan_desc": "Most trips by TR",
        "dna_tymrt_flyer": "✈️ Airport Express",
        "dna_tymrt_flyer_desc": "Most trips by Taoyuan A.P. MRT",
        "dna_fanatic_commuter": "🔥 Hardcore Commuter",
        "dna_fanatic_commuter_desc": "More than 100 trips",
        "dna_regular_life": "📅 Regular Lifestyle",
        "dna_regular_life_desc": "More than 50 trips",
        "dna_netprofit_king": "💸 Net Profit King",
        "dna_netprofit_king_desc": "Net profit over $1200",
        "dna_breakeven_master": "💰 Breakeven Master",
        "dna_breakeven_master_desc": "Breakeven achieved",
        "dna_early_bird": "☀️ Early Bird",
        "dna_early_bird_desc": "Over 30% before 08:00",
        "dna_night_owl": "🌙 Night Owl",
        "dna_night_owl_desc": "Over 20% after 21:00",
        "dna_rail_friend": "🚉 Rail Friend",
        "dna_rail_friend_desc": "80%+ rail-based trips",
        "dna_bike_pioneer": "🚴 Bike Pioneer",
        "dna_bike_pioneer_desc": "More than 10 Ubike trips",
        "dna_cross_region": "🏙️ Cross-region Traveler",
        "dna_cross_region_desc": "More than 5 coach trips",
        "dna_energy_full": "🔋 Fully Charged",
        "dna_energy_full_desc": "10+ trips in a single day",

        // Common UI
        "done": "Done",

        // Tutorial
        "tutorial_trip_history_title": "Trip History",
        "tutorial_card_add_data": "Add a trip",
        "tutorial_card_more_features": "More features",
        "tutorial_card_quick_delete": "Quick delete (swipe left)",
        "tutorial_card_quick_add": "Quick add (swipe right)",
        "tutorial_upload_image": "Please add image: %@",

        // Intro
        "intro_welcome_title": "Welcome to\nTPASS Calculator",
        "intro_swipe_more": "Swipe for more",
        "intro_feature_1_title": "Commute smart, spend less",
        "intro_feature_1_desc": "Built for MegaCity Pass commuters.\nIs 1200 worth it?\nLet’s calculate together.",
        "intro_feature_2_title": "Smart transfers & discounts",
        "intro_feature_2_desc": "Automatically applies transfer discounts ($8/$6).\nSupports frequent rider rebates\nand TPASS 2.0 subsidy calculations.",
        "intro_feature_3_title": "Flexible cycle settings",
        "intro_feature_3_desc": "Not limited to the 1st of each month.\nPick your pass start date,\nand track rebates across the 30-day validity.",
        "intro_feature_4_title": "Deep analytics dashboard",
        "intro_feature_4_desc": "New: commuter heatmap & breakeven race.\nVisualize weekday/weekend patterns\nand detailed spend breakdowns.",
        "intro_start_title": "Get Started",
        "intro_choose_identity_desc": "Choose your ticket type.\nThis affects transfer discount calculations.",
        "intro_identity_adult_title": "Full fare (Adult)",
        "intro_identity_student_title": "Student",
        "intro_identity_transfer_discount": "Transfer discount $%d",
        "intro_start_button": "Start",
        "intro_data_stored_local": "Your data stays on your device",

        // Favorites / Commuter
        "favorites_empty_title": "No favorites or commuter routes",
        "favorites_empty_desc": "Long press a trip to add it to Favorites or Commuter Routes for quick access.",
        "favorites_empty_favorites_only_desc": "Long press a trip to add it to Favorites.",
        "favorites_empty_commuter_only_desc": "Long press a trip to add it to Commuter Routes.",
        "commuter_route": "Commuter Route",
        "commuter_route_empty": "No trips in this commuter route",
        "count_trips": "%d trips",

        // Backup
        "backup_upload_section_title": "Upload to iCloud",
        "backup_upload_section_desc": "Back up your trips, favorites, and cycles to iCloud.",
        "backup_upload_now": "Upload now",
        "backup_last_upload": "Last upload: %@",
        "backup_restore_section_title": "Restore from iCloud",
        "backup_restore": "Restore",
        "backup_footer": "• Upload: back up local data to iCloud\n• Restore: restore a selected iCloud backup to this device\n• All actions are manual; no automatic sync",
        "backup_nav_title": "Backup",
        "backup_sheet_title": "Upload Backup to iCloud",
        "backup_sheet_desc": "You will upload %@",
        "backup_trip_count": "%d trips",
        "backup_favorite_count": "%d favorites",
        "backup_cycle_count": "%d cycles",
        "backup_upload": "Upload",
        "backup_confirm_restore_title": "Confirm Restore",
        "backup_confirm_restore_message": "Restoring will erase current local data and replace it with this backup. Please make sure your latest data is backed up first.",
        "backup_confirm_restore_action": "Restore",
        "backup_confirm_delete_title": "Confirm Delete",
        "backup_confirm_delete_message": "This will permanently delete the selected iCloud backup. This action cannot be undone.",
        "backup_confirm_delete_action": "Delete",
        "backup_operation_success": "Success",
        "backup_operation_failed": "Failed",
        "backup_summary": "%d trips, %d favorites, %d cycles",
        "backup_upload_success_title": "Upload Complete",
        "backup_upload_success_message": "Backup uploaded to iCloud\n%@",
        "backup_upload_failed": "Upload failed: %@",
        "backup_restore_success_title": "Restore Complete",
        "backup_restore_success_message": "Backup restored\nTrips: %d\nFavorites: %d\nCycles: %d",
        "backup_restore_failed": "Restore failed: %@",
        "backup_delete_success_title": "Deleted",
        "backup_delete_success_message": "Backup deleted successfully",
        "backup_delete_failed": "Delete failed: %@",

        // Notifications (content)
        "notification_daily_title": "Did you ride today? 🚌",
        "notification_daily_body": "Log today’s trips and see how close you are to breakeven!",
        "notification_cycle_expiring_title": "TPASS Expiring Soon 📅",
        "notification_cycle_expiring_body": "Your pass expires in 3 days. Time to decide whether to renew!",
        "notification_cycle_new_title": "New cycle has started! 🚀",
        "notification_cycle_new_body": "If you renewed TPASS, set a new cycle in the app to start a fresh challenge.",

        // AppViewModel label building
        "current_cycle_month": "Current month",
        "route_title_bus": "Route %@ (%@)",
        "month_short": "M%d",
        "rebate_r1_mrt_item": "[%@] MRT %d trips (%d%%)",
        "rebate_r1_tra_item": "[%@] TR %d trips (%d%%)",
        "rebate_r2_rail_item": "[%@] Rail %d trips (2%%)",
        "rebate_r2_bus_item": "[%@] Bus %d trips (%d%%)",
        "transport_count": "%@ (%d trips)",

        // CloudKit error messages
        "cloudkit_unavailable_check_signin": "iCloud account unavailable. Please check your sign-in status.",
        "cloudkit_unavailable": "iCloud account unavailable.",
        "cloudkit_partial_upload_failed": "Some records failed to upload (%d).",
    ]
}
