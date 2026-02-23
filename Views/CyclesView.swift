import SwiftUI

struct CyclesView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: AppViewModel
    
    @State private var showAddCycleSheet = false
    @State private var selectedCycleForEdit: Cycle? = nil
    @State private var showFlexibleCycleSheet = false  // 彈性記帳週期的新增頁面
    
    private var currentCycles: [Cycle] {
        let now = Date()
        return (auth.currentUser?.cycles ?? [])
            .filter { cycle in
                cycle.start <= now && cycle.end >= now
            }
            .sorted { $0.start < $1.start }
    }
    
    private var futureCycles: [Cycle] {
        let now = Date()
        return (auth.currentUser?.cycles ?? [])
            .filter { $0.start > now }
            .sorted { $0.start < $1.start }
    }
    
    private var pastCycles: [Cycle] {
        let now = Date()
        return (auth.currentUser?.cycles ?? [])
            .filter { $0.end < now }
            .sorted { $0.start > $1.start }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        
                        // 🆕 彈性記帳週期按鈕（獨立區塊）
                        flexibleCycleButton
                        
                        // 添加周期按钮
                        addCycleButton
                        
                        // 最新周期
                        if !currentCycles.isEmpty {
                            currentCyclesSection
                        }
                        
                        // 未來周期
                        if !futureCycles.isEmpty {
                            futureCyclesSection
                        }
                        
                        // 过去周期
                        if !pastCycles.isEmpty {
                            pastCyclesSection
                        }
                        
                        // 空状态提示
                        if currentCycles.isEmpty && futureCycles.isEmpty && pastCycles.isEmpty {
                            emptyStateView
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("cycle_management")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(false)
            .sheet(isPresented: $showAddCycleSheet) {
                AddCycleView()
            }
            .sheet(isPresented: $showFlexibleCycleSheet) {
                AddFlexibleCycleView()  // 彈性記帳週期的新增頁面
            }
            .sheet(item: $selectedCycleForEdit) { cycle in
                EditCycleView(cycle: cycle)
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - 🆕 彈性記帳週期按鈕（獨立）
    private var flexibleCycleButton: some View {
        VStack(spacing: 12) {
            Button(action: { showFlexibleCycleSheet = true }) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                    Text("flexible_cycle_button")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [flexibleCycleColor, flexibleCycleColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: flexibleCycleColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // 提示文字
            Text("flexible_cycle_reminder")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
    }
    
    // MARK: - 彈性週期配色
    private var flexibleCycleColor: Color {
        switch themeManager.currentTheme {
        case .muji:
            return Color(hex: "#B07D62") // Muji 暖棕色
        case .dark:
            return Color(hex: "#5AC8FA") // 深色模式青色
        case .light:
            return Color(hex: "#34C759") // 淺色模式綠色
        case .system:
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? Color(hex: "#5AC8FA") : Color(hex: "#34C759")
        }
    }
    
    // MARK: - 添加周期按钮
    private var addCycleButton: some View {
        Button(action: { showAddCycleSheet = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("add_new_cycle")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - 最新周期区块
    private var currentCyclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("current_cycle")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
            }
            
            ForEach(currentCycles) { cycle in
                cycleCard(cycle, isCurrent: true)
            }
        }
    }
    
    // MARK: - 未來周期区块
    private var futureCyclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("future_cycles")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(themeManager.accentColor)
            }
            
            ForEach(futureCycles) { cycle in
                cycleCard(cycle, isCurrent: false)
            }
        }
    }
    
    // MARK: - 过去周期区块
    private var pastCyclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("past_cycles")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryTextColor)
            
            ForEach(pastCycles) { cycle in
                cycleCard(cycle, isCurrent: false)
            }
        }
    }
    
    // MARK: - 周期卡片
    private func cycleCard(_ cycle: Cycle, isCurrent: Bool) -> some View {
        Button(action: {
            selectedCycleForEdit = cycle
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cycle.region.displayNameKey)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isCurrent ? themeManager.accentColor : themeManager.primaryTextColor)
                        
                        Text(cycleDateRange(cycle))
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if isCurrent {
                            Text("active")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.accentColor)
                                .cornerRadius(6)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
                
                Divider()
                
                HStack(spacing: 16) {
                    cycleInfoItem(icon: "calendar", text: daysRemaining(cycle))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? themeManager.accentColor.opacity(0.1) : Color(uiColor: .systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? themeManager.accentColor.opacity(0.3) : Color(uiColor: .systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 周期信息项
    private func cycleInfoItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
            Text(text)
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
            
            Text("no_cycles_yet")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("no_cycles_description")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }
    
    // MARK: - 辅助方法
    private func cycleDateRange(_ cycle: Cycle) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return "\(formatter.string(from: cycle.start)) ~ \(formatter.string(from: cycle.end))"
    }
    
    private func daysRemaining(_ cycle: Cycle) -> String {
        let now = Date()
        if cycle.end < now {
            return String(localized: "expired")
        } else if cycle.start > now {
            let days = Calendar.current.dateComponents([.day], from: now, to: cycle.start).day ?? 0
            return String(format: NSLocalizedString("days_until_start", comment: ""), days)
        } else {
            let days = Calendar.current.dateComponents([.day], from: now, to: cycle.end).day ?? 0
            return String(format: NSLocalizedString("days_remaining", comment: ""), days)
        }
    }
}

// MARK: - 添加周期视图
struct AddCycleView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedRegion: TPASSRegion = .north
    @State private var showOverlapAlert = false
    
    init() {
        // 初始化：開始日期為今天0:00，結束日期為今天+29天0:00（含開始日共30天）
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        _startDate = State(initialValue: today)
        _endDate = State(initialValue: calendar.date(byAdding: .day, value: 29, to: today) ?? today.addingTimeInterval(86400 * 29))
    }
    
    // 🆕 新增：根據方案類型自動調整日期範圍
    private func adjustDatesForRegion(_ region: TPASSRegion) {
        if region == .flexible {
            // 彈性記帳週期：自動設定為當月月初到月底
            let calendar = Calendar.current
            let now = Date()
            
            // 取得當月第一天
            let components = calendar.dateComponents([.year, .month], from: now)
            if let firstDay = calendar.date(from: components) {
                startDate = firstDay
                
                // 取得當月最後一天（下個月第一天 - 1秒）
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay),
                   let lastDay = calendar.date(byAdding: .second, value: -1, to: nextMonth) {
                    endDate = calendar.startOfDay(for: lastDay)
                } else {
                    // 若計算失敗，使用備用方法：當天+29天
                    endDate = calendar.date(byAdding: .day, value: 29, to: firstDay) ?? firstDay
                }
            }
        } else {
            // 一般方案：使用30天週期
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            startDate = today
            endDate = calendar.date(byAdding: .day, value: 29, to: today) ?? today.addingTimeInterval(86400 * 29)
        }
    }
    
    private var hasDateOverlap: Bool {
        let cycles = auth.currentUser?.cycles ?? []
        return cycles.contains { existingCycle in
            // 检查新周期是否与现有周期重叠
            !(endDate < existingCycle.start || startDate > existingCycle.end)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("start_date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { oldDate, newDate in
                            // 當開始日期改變時，自動設定結束日期為開始日期+29天，時間都為0:00（含開始日共30天）
                            let calendar = Calendar.current
                            let startOfDay = calendar.startOfDay(for: newDate)
                            endDate = calendar.date(byAdding: .day, value: 29, to: startOfDay) ?? startOfDay.addingTimeInterval(86400 * 29)
                        }
                    DatePicker("end_date", selection: $endDate, displayedComponents: .date)
                }
                
                Section(header: Text("tpass_plan")) {
                    Picker("tpass_plan", selection: $selectedRegion) {
                        ForEach(TPASSRegion.allCases, id: \.self) { region in
                            Text(region.displayNameKey).tag(region)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: selectedRegion) { oldValue, newValue in
                        // 當方案改變時，自動調整日期範圍
                        adjustDatesForRegion(newValue)
                    }
                }
            }
            .navigationTitle("add_new_cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save") {
                        if hasDateOverlap {
                            showOverlapAlert = true
                        } else {
                            // 儲存前給予震動回饋
                            HapticManager.shared.impact(style: .medium)
                            auth.addCycle(start: startDate, end: endDate, region: selectedRegion)
                            
                            let isCycleNotifOn = UserDefaults.standard.bool(forKey: "isCycleReminderEnabled")
                            if isCycleNotifOn {
                                let tempCycle = Cycle(id: UUID().uuidString, start: startDate, end: endDate, region: selectedRegion)
                                NotificationManager.shared.scheduleCycleReminders(enabled: true, currentCycle: tempCycle)
                            }
                            
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("date_overlap_warning", isPresented: $showOverlapAlert) {
                Button("cancel", role: .cancel) { }
                Button("proceed", role: .destructive) {
                    // 進行覆蓋操作前給予警告震動
                    HapticManager.shared.notification(type: .warning)
                    auth.addCycle(start: startDate, end: endDate, region: selectedRegion)
                    
                    let isCycleNotifOn = UserDefaults.standard.bool(forKey: "isCycleReminderEnabled")
                    if isCycleNotifOn {
                        let tempCycle = Cycle(id: UUID().uuidString, start: startDate, end: endDate, region: selectedRegion)
                        NotificationManager.shared.scheduleCycleReminders(enabled: true, currentCycle: tempCycle)
                    }
                    
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("date_overlap_message")
            }
        }
    }
}

// MARK: - 编辑周期视图
struct EditCycleView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    let cycle: Cycle
    
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedRegion: TPASSRegion
    @State private var showDeleteConfirmation = false
    
    init(cycle: Cycle) {
        self.cycle = cycle
        // 確保開始和結束時間都是 0:00
        let calendar = Calendar.current
        let startOfDayStart = calendar.startOfDay(for: cycle.start)
        let startOfDayEnd = calendar.startOfDay(for: cycle.end)
        _startDate = State(initialValue: startOfDayStart)
        _endDate = State(initialValue: startOfDayEnd)
        _selectedRegion = State(initialValue: cycle.region)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("start_date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { oldDate, newDate in
                            // 當開始日期改變時，自動設定結束日期為開始日期+29天，時間都為0:00（含開始日共30天）
                            let calendar = Calendar.current
                            let startOfDay = calendar.startOfDay(for: newDate)
                            endDate = calendar.date(byAdding: .day, value: 29, to: startOfDay) ?? startOfDay.addingTimeInterval(86400 * 29)
                        }
                    DatePicker("end_date", selection: $endDate, displayedComponents: .date)
                }
                
                Section(header: Text("tpass_plan")) {
                    Picker("", selection: $selectedRegion) {
                        ForEach(TPASSRegion.allCases, id: \.self) { region in
                            Text(region.displayNameKey).tag(region)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("delete_cycle")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("edit_cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save") {
                        // 儲存前給予震動回饋
                        HapticManager.shared.impact(style: .medium)
                        auth.updateCycle(cycle, start: startDate, end: endDate, region: selectedRegion)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("delete_cycle_confirmation", isPresented: $showDeleteConfirmation) {
                Button("cancel", role: .cancel) { }
                Button("delete", role: .destructive) {
                    // 刪除前給予警告震動
                    HapticManager.shared.notification(type: .warning)
                    auth.deleteCycle(cycle)
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("delete_cycle_message")
            }
        }
    }
}
// MARK: - 🆕 彈性記帳週期新增頁面
struct AddFlexibleCycleView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showOverlapAlert = false
    @State private var showInfoSheet = false  // 顯示說明頁面
    
    init() {
        // 初始化：自動設定為當月月初到月底
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        
        if let firstDay = calendar.date(from: components) {
            _startDate = State(initialValue: firstDay)
            
            // 計算當月最後一天
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDay),
               let lastDay = calendar.date(byAdding: .second, value: -1, to: nextMonth) {
                _endDate = State(initialValue: calendar.startOfDay(for: lastDay))
            } else {
                _endDate = State(initialValue: calendar.date(byAdding: .day, value: 29, to: firstDay) ?? firstDay)
            }
        }
    }
    
    private var hasDateOverlap: Bool {
        let cycles = auth.currentUser?.cycles ?? []
        return cycles.contains { existingCycle in
            !(endDate < existingCycle.start || startDate > existingCycle.end)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 🎨 標題區塊
                        headerSection
                        
                        // 📅 日期選擇
                        dateSection
                        
                        // ℹ️ 功能說明
                        infoSection
                        
                        // 💡 使用提示
                        tipsSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("flexible_cycle_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save") {
                        if hasDateOverlap {
                            showOverlapAlert = true
                        } else {
                            saveFlexibleCycle()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("date_overlap_warning", isPresented: $showOverlapAlert) {
                Button("cancel", role: .cancel) { }
                Button("proceed", role: .destructive) {
                    HapticManager.shared.notification(type: .warning)
                    saveFlexibleCycle()
                }
            } message: {
                Text("date_overlap_message")
            }
        }
    }
    
    // MARK: - 標題區塊
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(flexibleCycleColor.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 28))
                    .foregroundColor(flexibleCycleColor)
            }
            
            Text("flexible_cycle_header_title")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("flexible_cycle_header_subtitle")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 日期選擇
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(flexibleCycleColor)
                Text("cycle_period")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("start_date")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 80, alignment: .leading)
                    
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                Divider()
                
                HStack {
                    Text("end_date")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .frame(width: 80, alignment: .leading)
                    
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(flexibleCycleColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 功能說明
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(flexibleCycleColor)
                Text("flexible_cycle_features")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "bus.doubledecker.fill", title: "flexible_feature_all_modes", color: .green)
                featureRow(icon: "location.fill", title: "flexible_feature_all_regions", color: .blue)
                featureRow(icon: "dollarsign.circle", title: "flexible_feature_no_monthly_fee", color: .orange)
                featureRow(icon: "chart.bar.fill", title: "flexible_feature_expense_tracking", color: flexibleCycleColor)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(flexibleCycleColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 使用提示
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(flexibleCycleColor)
                Text("flexible_cycle_use_cases")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                tipRow(number: "1", text: "flexible_tip_1")
                tipRow(number: "2", text: "flexible_tip_2")
                tipRow(number: "3", text: "flexible_tip_3")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(flexibleCycleColor.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 輔助 Views
    private func featureRow(icon: String, title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 28)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(themeManager.primaryTextColor)
            
            Spacer()
        }
    }
    
    private func tipRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(flexibleCycleColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(flexibleCycleColor)
            }
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
            
            Spacer()
        }
    }
    
    // MARK: - 彈性週期配色
    private var flexibleCycleColor: Color {
        switch themeManager.currentTheme {
        case .muji:
            return Color(hex: "#B07D62") // Muji 暖棕色
        case .dark:
            return Color(hex: "#5AC8FA") // 深色模式青色
        case .light:
            return Color(hex: "#34C759") // 淺色模式綠色
        case .system:
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? Color(hex: "#5AC8FA") : Color(hex: "#34C759")
        }
    }
    
    // MARK: - 儲存方法
    private func saveFlexibleCycle() {
        HapticManager.shared.impact(style: .medium)
        auth.addCycle(start: startDate, end: endDate, region: .flexible)
        
        let isCycleNotifOn = UserDefaults.standard.bool(forKey: "isCycleReminderEnabled")
        if isCycleNotifOn {
            let tempCycle = Cycle(id: UUID().uuidString, start: startDate, end: endDate, region: .flexible)
            NotificationManager.shared.scheduleCycleReminders(enabled: true, currentCycle: tempCycle)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

