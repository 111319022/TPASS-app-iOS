import SwiftUI
import SwiftData

struct CyclesView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: AppViewModel
    @Query(sort: \TransitCard.createdAt, order: .reverse) private var cards: [TransitCard]
    
    @State private var showAddCycleSheet = false
    @State private var selectedCycleForEdit: Cycle? = nil
    @State private var showFlexibleCycleSheet = false  // 彈性記帳週期的新增頁面
    
    private var currentCycles: [Cycle] {
        let today = Calendar.current.startOfDay(for: Date())
        return (auth.currentUser?.cycles ?? [])
            .filter { cycle in
                let startDay = Calendar.current.startOfDay(for: cycle.start)
                let endDay = Calendar.current.startOfDay(for: cycle.end)
                return startDay <= today && endDay >= today
            }
            .sorted { $0.start < $1.start }
    }
    
    private var futureCycles: [Cycle] {
        let today = Calendar.current.startOfDay(for: Date())
        return (auth.currentUser?.cycles ?? [])
            .filter { cycle in
                let startDay = Calendar.current.startOfDay(for: cycle.start)
                return startDay > today
            }
            .sorted { $0.start < $1.start }
    }
    
    private var pastCycles: [Cycle] {
        let today = Calendar.current.startOfDay(for: Date())
        return (auth.currentUser?.cycles ?? [])
            .filter { cycle in
                let endDay = Calendar.current.startOfDay(for: cycle.end)
                return endDay < today
            }
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
        case .purple:
            return Color(hex: "#8071ad") // 紫色模式紫色
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
                        
                        if let name = cardName(for: cycle.cardId) {
                            HStack(spacing: 4) {
                                Image(systemName: "creditcard.fill")
                                    .font(.caption2)
                                Text(name)
                                    .font(.caption)
                            }
                            .foregroundColor(themeManager.accentColor.opacity(0.8))
                        }
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
    
    // MARK: - 卡片輔助方法
    private func cardName(for cardId: String?) -> String? {
        guard let cardId else { return nil }
        return cards.first(where: { $0.id.uuidString == cardId })?.name
    }
    
    // MARK: - 辅助方法
    private func cycleDateRange(_ cycle: Cycle) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return "\(formatter.string(from: cycle.start)) ~ \(formatter.string(from: cycle.end))"
    }
    
    private func daysRemaining(_ cycle: Cycle) -> String {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let endDay = calendar.startOfDay(for: cycle.end)
        let startDay = calendar.startOfDay(for: cycle.start)
        
        if endDay < now {
            return String(localized: "expired")
        } else if startDay > now {
            let days = calendar.dateComponents([.day], from: now, to: startDay).day ?? 0
            return String(format: NSLocalizedString("days_until_start", comment: ""), days)
        } else {
            // 計算剩餘天數，包含今天（+1）
            let days = (calendar.dateComponents([.day], from: now, to: endDay).day ?? 0) + 1
            return String(format: NSLocalizedString("days_remaining", comment: ""), days)
        }
    }
}

// MARK: - 添加周期视图
struct AddCycleView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \TransitCard.createdAt, order: .reverse) private var cards: [TransitCard]
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var selectedRegion: TPASSRegion = .north
    @State private var showOverlapAlert = false
    @State private var selectedCardId: String? = nil
    
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
                Section(header: Text("transit_card"), footer: Text("card_binding_description")) {
                    if cards.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("無綁定卡片")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryTextColor)

                            NavigationLink {
                                TransitCardManagementView()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(themeManager.accentColor)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("create_first_card")
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.primaryTextColor)
                                    }

                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.accentColor.opacity(0.08))
                                )
                            }
                        }
                    } else {
                        Picker("transit_card", selection: $selectedCardId) {
                            Text("no_card_selected").tag(nil as String?)
                            ForEach(cards) { card in
                                Text(card.name).tag(card.id.uuidString as String?)
                            }
                        }
                    }
                }
                
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
                            auth.addCycle(start: startDate, end: endDate, region: selectedRegion, cardId: selectedCardId)
                            
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
                    auth.addCycle(start: startDate, end: endDate, region: selectedRegion, cardId: selectedCardId)
                    
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
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \TransitCard.createdAt, order: .reverse) private var cards: [TransitCard]
    
    let cycle: Cycle
    
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedRegion: TPASSRegion
    @State private var selectedModes: Set<TransportType>
    @State private var selectedCardId: String?
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
        _selectedCardId = State(initialValue: cycle.cardId)
        // 彈性週期：讀取已儲存的運具選擇，nil 表示全選
        let modes = cycle.selectedModes ?? Array(TPASSRegion.flexible.supportedModes)
        _selectedModes = State(initialValue: Set(modes))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("transit_card"), footer: Text("card_binding_description")) {
                    if cards.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("無綁定卡片")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryTextColor)

                            NavigationLink {
                                TransitCardManagementView()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(themeManager.accentColor)
                                    Text("create_first_card")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.accentColor.opacity(0.08))
                                )
                            }
                        }
                    } else {
                        Picker("transit_card", selection: $selectedCardId) {
                            Text("no_card_selected").tag(nil as String?)
                            ForEach(cards) { card in
                                Text(card.name).tag(card.id.uuidString as String?)
                            }
                        }
                    }
                }
                
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
                
                if selectedRegion == .flexible {
                    Section(header: Text("flexible_select_modes")) {
                        let allModes = TPASSRegion.flexible.supportedModes
                        let isAllSelected = selectedModes.count == allModes.count
                        
                        HStack {
                            Spacer()
                            Button(isAllSelected ? "flexible_deselect_all" : "flexible_select_all") {
                                HapticManager.shared.impact(style: .light)
                                if isAllSelected {
                                    selectedModes = Set([allModes.first!])
                                } else {
                                    selectedModes = Set(allModes)
                                }
                            }
                            .font(.caption)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(allModes) { mode in
                                let isSelected = selectedModes.contains(mode)
                                Button {
                                    HapticManager.shared.impact(style: .light)
                                    if isSelected {
                                        if selectedModes.count > 1 {
                                            selectedModes.remove(mode)
                                        }
                                    } else {
                                        selectedModes.insert(mode)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: mode.systemIconName)
                                            .font(.system(size: 18))
                                        Text(mode.displayName)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? mode.color.opacity(0.15) : Color.gray.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? mode.color : Color.clear, lineWidth: 1.5)
                                    )
                                    .foregroundColor(isSelected ? mode.color : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
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
                        let allModes = TPASSRegion.flexible.supportedModes
                        let modesToSave: [TransportType]? = (selectedRegion == .flexible && selectedModes.count < allModes.count) ? Array(selectedModes) : nil
                        auth.updateCycle(cycle, start: startDate, end: endDate, region: selectedRegion, selectedModes: modesToSave, cardId: selectedCardId)
                        viewModel.refreshSelectedCycle()
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
    @Query(sort: \TransitCard.createdAt, order: .reverse) private var cards: [TransitCard]
    
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showOverlapAlert = false
    @State private var showInfoSheet = false  // 顯示說明頁面
    @State private var selectedModes: Set<TransportType> = Set(TPASSRegion.flexible.supportedModes)
    @State private var showModeRequiredAlert = false
    @State private var selectedCardId: String? = nil
    
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
                        
                        // 💳 卡片選擇
                        cardSelectionSection
                        
                        // 📅 日期選擇
                        dateSection
                        
                        // 🚌 運具選擇
                        transportModeSection
                        
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
                        if selectedModes.isEmpty {
                            showModeRequiredAlert = true
                        } else if hasDateOverlap {
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
            .alert("flexible_mode_required", isPresented: $showModeRequiredAlert) {
                Button("confirm", role: .cancel) { }
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
    
    // MARK: - 運具選擇
    private var transportModeSection: some View {
        let allModes = TPASSRegion.flexible.supportedModes
        let isAllSelected = selectedModes.count == allModes.count
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(flexibleCycleColor)
                Text("flexible_select_modes")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                    if isAllSelected {
                        // 取消全選：保留第一個
                        selectedModes = Set([allModes.first!])
                    } else {
                        selectedModes = Set(allModes)
                    }
                } label: {
                    Text(isAllSelected ? "flexible_deselect_all" : "flexible_select_all")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(flexibleCycleColor)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(allModes) { mode in
                    let isSelected = selectedModes.contains(mode)
                    Button {
                        HapticManager.shared.impact(style: .light)
                        if isSelected {
                            if selectedModes.count > 1 {
                                selectedModes.remove(mode)
                            }
                        } else {
                            selectedModes.insert(mode)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.systemIconName)
                                .font(.system(size: 20))
                            Text(mode.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? mode.color.opacity(0.15) : Color.gray.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? mode.color : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundColor(isSelected ? mode.color : themeManager.secondaryTextColor.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
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
    
    // MARK: - 卡片選擇
    private var cardSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(flexibleCycleColor)
                Text("transit_card")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            VStack(spacing: 10) {
                if cards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("無綁定卡片")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryTextColor)

                        NavigationLink {
                            TransitCardManagementView()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(flexibleCycleColor)

                                Text("create_first_card")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.primaryTextColor)

                                Spacer()
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(flexibleCycleColor.opacity(0.08))
                            )
                        }
                    }
                } else {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        selectedCardId = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 18))
                                .foregroundColor(themeManager.secondaryTextColor)

                            Text("no_card_selected")
                                .font(.subheadline)
                                .foregroundColor(themeManager.primaryTextColor)

                            Spacer()

                            Image(systemName: selectedCardId == nil ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(selectedCardId == nil ? flexibleCycleColor : themeManager.secondaryTextColor.opacity(0.35))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedCardId == nil ? flexibleCycleColor.opacity(0.12) : themeManager.cardBackgroundColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedCardId == nil ? flexibleCycleColor.opacity(0.55) : themeManager.secondaryTextColor.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(cards) { card in
                        let cardId = card.id.uuidString
                        let isSelected = selectedCardId == cardId

                        Button {
                            HapticManager.shared.impact(style: .light)
                            selectedCardId = cardId
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(isSelected ? flexibleCycleColor : themeManager.secondaryTextColor)

                                Text(card.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(isSelected ? flexibleCycleColor : themeManager.secondaryTextColor.opacity(0.35))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? flexibleCycleColor.opacity(0.12) : themeManager.cardBackgroundColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? flexibleCycleColor.opacity(0.55) : themeManager.secondaryTextColor.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(flexibleCycleColor.opacity(0.2), lineWidth: 1)
            )
            
            Text("card_binding_description")
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
                .padding(.horizontal, 4)
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
        case .light, .purple:
            return Color(hex: "#34C759") // 淺色模式綠色
        case .system:
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            return isDark ? Color(hex: "#5AC8FA") : Color(hex: "#34C759")
        }
    }
    
    // MARK: - 儲存方法
    private func saveFlexibleCycle() {
        HapticManager.shared.impact(style: .medium)
        let allModes = TPASSRegion.flexible.supportedModes
        let modesToSave: [TransportType]? = selectedModes.count == allModes.count ? nil : Array(selectedModes)
        auth.addCycle(start: startDate, end: endDate, region: .flexible, selectedModes: modesToSave, cardId: selectedCardId)
        
        let isCycleNotifOn = UserDefaults.standard.bool(forKey: "isCycleReminderEnabled")
        if isCycleNotifOn {
            let tempCycle = Cycle(id: UUID().uuidString, start: startDate, end: endDate, region: .flexible)
            NotificationManager.shared.scheduleCycleReminders(enabled: true, currentCycle: tempCycle)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

