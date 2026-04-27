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
                        
                        // 彈性記帳週期按鈕（獨立區塊）
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
        return themeManager.cycleAccentColor
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
        let summary = financialSummary(for: cycle)
        
        return Button(action: {
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
                
                // 支出與回本資訊
                cycleFinancialSection(summary: summary, isCurrent: isCurrent)
                
                HStack(spacing: 16) {
                    cycleInfoItem(icon: "calendar", text: daysRemaining(cycle))
                    Spacer()
                    cycleInfoItem(icon: "tram.fill", text: String(format: NSLocalizedString("cycle_trip_count", comment: ""), summary.tripCount))
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
    
    // MARK: - 週期支出與回本率區塊
    private func cycleFinancialSection(summary: CycleFinancialSummary, isCurrent: Bool) -> some View {
        VStack(spacing: 8) {
            // 實際總支出（實付 - 轉乘折扣）
            HStack {
                Text("cycle_actual_spending")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                Spacer()
                Text("$\(summary.actualSpending)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            // 回本率（僅限有月費的方案）
            if summary.monthlyPrice > 0 {
                let barColor = progressBarColor(isBreakeven: summary.isBreakeven, isCurrent: isCurrent)
                
                HStack {
                    Text("cycle_payback_rate")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("\(summary.paybackRate)%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(barColor)
                        
                        Image(systemName: summary.isBreakeven ? "checkmark.circle.fill" : "arrow.up.circle")
                            .font(.caption)
                            .foregroundColor(barColor)
                    }
                }
                
                // 回本進度條
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(uiColor: .systemGray4))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(width: min(geometry.size.width * CGFloat(summary.paybackRate) / 100.0, geometry.size.width), height: 6)
                    }
                }
                .frame(height: 6)
                
                // 月費 vs 實付對比
                HStack {
                    Text(String(format: NSLocalizedString("cycle_monthly_cost", comment: ""), summary.monthlyPrice))
                        .font(.caption2)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Spacer()
                    if summary.isBreakeven {
                        Text(String(format: NSLocalizedString("cycle_saved_amount", comment: ""), summary.netSavings))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(barColor)
                    } else {
                        Text(String(format: NSLocalizedString("cycle_remaining_to_breakeven", comment: ""), abs(summary.netSavings)))
                            .font(.caption2)
                            .foregroundColor(barColor)
                    }
                }
            }
        }
    }
    
    /// 進度條顏色
    private func progressBarColor(isBreakeven: Bool, isCurrent: Bool) -> Color {
        if isCurrent {
            return isBreakeven ? .green : themeManager.accentColor
        } else {
            // 過去週期：依回本狀態使用深綠/深橘，在灰色背景上清晰可見，深色模式下維持亮色
            if isBreakeven {
                return Color(uiColor: UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor(red: 0.30, green: 0.78, blue: 0.40, alpha: 1.0)
                        : UIColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0)
                })
            } else {
                return Color(uiColor: UIColor { tc in
                    tc.userInterfaceStyle == .dark
                        ? UIColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1.0)
                        : UIColor(red: 0.80, green: 0.45, blue: 0.10, alpha: 1.0)
                })
            }
        }
    }
    
    // MARK: - 周期訊息項
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
    
    // MARK: - 空狀態
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
    
    // MARK: - 週期行程查詢
    private func tripsForCycle(_ cycle: Cycle) -> [Trip] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        let cycleId = cycle.id
        let cycleCardId = cycle.cardId
        
        return viewModel.trips.filter { trip in
            guard trip.createdAt >= start && trip.createdAt <= end else { return false }
            if let tripCycleId = trip.cycleId { return tripCycleId == cycleId }
            if let cCardId = cycleCardId, let tCardId = trip.cardId { return tCardId == cCardId }
            return true
        }
    }
    
    /// 計算週期的支出統計
    private struct CycleFinancialSummary {
        let tripCount: Int
        let totalOriginal: Int   // 原價總計
        let totalPaid: Int       // 實付總計（含轉乘折扣後）
        let monthlyPrice: Int    // 方案月費
        let r1Total: Int         // 常客回饋（R1）
        let r2Total: Int         // TPASS2 回饋（R2）
        
        /// 實際總支出 = 實付 - R1 - R2
        var actualSpending: Int { max(0, totalPaid - r1Total - r2Total) }
        
        /// 回本率 = 實際總支出 / 月費 × 100（彈性週期無月費則為 0）
        var paybackRate: Int {
            guard monthlyPrice > 0 else { return 0 }
            return Int((Double(actualSpending) / Double(monthlyPrice)) * 100)
        }
        
        /// 是否已回本
        var isBreakeven: Bool { paybackRate >= 100 }
        
        /// 淨省金額 = 實際總支出 - 月費（正值表示已回本超出的部分）
        var netSavings: Int { actualSpending - monthlyPrice }
    }
    
    private func financialSummary(for cycle: Cycle) -> CycleFinancialSummary {
        let cycleTrips = tripsForCycle(cycle)
        let totalOriginal = cycleTrips.reduce(0) { $0 + $1.originalPrice }
        let totalPaid = cycleTrips.reduce(0) { $0 + $1.paidPrice }
        let monthlyPrice = cycle.region.monthlyPrice
        
        // 計算 R1/R2 回饋（與 AppViewModel.financialStats 同邏輯）
        let (r1, r2) = calculateRebates(cycleTrips: cycleTrips, cycle: cycle)
        
        return CycleFinancialSummary(
            tripCount: cycleTrips.count,
            totalOriginal: totalOriginal,
            totalPaid: totalPaid,
            monthlyPrice: monthlyPrice,
            r1Total: r1,
            r2Total: r2
        )
    }
    
    /// 計算 R1/R2 回饋，與 AppViewModel.financialStats 同邏輯：
    /// - 回饋門檻（次數）使用全域所有行程的月次數（globalCounts）
    /// - 回饋金額只計算該週期內的行程金額（cycleSums）
    private func calculateRebates(cycleTrips: [Trip], cycle: Cycle) -> (r1: Int, r2: Int) {
        // --- 1. 統計該週期內的行程（用於計算回饋金額）---
        struct CycleMonthStats {
            var originalSums: [TransportType: Int] = [:]
            var paidSums: [TransportType: Int] = [:]
        }
        var cycleMonthlyStats: [String: CycleMonthStats] = [:]
        
        for trip in cycleTrips {
            let monthKey = String(trip.dateStr.prefix(7))
            var stats = cycleMonthlyStats[monthKey] ?? CycleMonthStats()
            let r1Original = trip.isFree ? 0 : trip.originalPrice
            stats.originalSums[trip.type, default: 0] += r1Original
            stats.paidSums[trip.type, default: 0] += trip.paidPrice
            cycleMonthlyStats[monthKey] = stats
        }
        
        // --- 2. 統計全域的月次數（用於判斷回饋門檻）---
        // 與 AppViewModel 一致：使用所有 trips，若週期有綁卡則只計同卡行程
        let allCycles = auth.currentUser?.cycles ?? []
        let cycleCardMap: [String: String?] = Dictionary(
            uniqueKeysWithValues: allCycles.map { ($0.id, $0.cardId) }
        )
        let activeCardId = cycle.cardId
        
        var globalMonthlyCounts: [String: [TransportType: Int]] = [:]
        
        for trip in viewModel.trips {
            if let cId = activeCardId {
                if let tripCycleId = trip.cycleId {
                    let tripCycleCardId = cycleCardMap[tripCycleId] ?? nil
                    if tripCycleCardId != cId { continue }
                } else {
                    if trip.cardId != cId { continue }
                }
            }
            let monthKey = String(trip.dateStr.prefix(7))
            globalMonthlyCounts[monthKey, default: [:]][trip.type, default: 0] += 1
        }
        
        // --- 3. 計算回饋 ---
        var r1 = 0, r2 = 0
        
        for (month, stats) in cycleMonthlyStats {
            let gCounts = globalMonthlyCounts[month] ?? [:]
            
            // R1 北捷：全域次數判門檻，週期金額算回饋
            let mrtCount = gCounts[.mrt] ?? 0
            let mrtOriginal = stats.originalSums[.mrt] ?? 0
            var mrtRate = 0.0
            if mrtCount > 40 { mrtRate = 0.15 }
            else if mrtCount > 20 { mrtRate = 0.10 }
            else if mrtCount > 10 { mrtRate = 0.05 }
            r1 += Int(Double(mrtOriginal) * mrtRate)
            
            // R1 台鐵
            let traCount = gCounts[.tra] ?? 0
            let traOriginal = stats.originalSums[.tra] ?? 0
            var traRate = 0.0
            if traCount > 40 { traRate = 0.20 }
            else if traCount > 20 { traRate = 0.15 }
            else if traCount > 10 { traRate = 0.10 }
            r1 += Int(Double(traOriginal) * traRate)
            
            // R2 北捷
            let r2MrtCount = gCounts[.mrt] ?? 0
            let r2MrtPaid = stats.paidSums[.mrt] ?? 0
            if r2MrtCount >= 11 { r2 += Int(Double(r2MrtPaid) * 0.02) }
            
            // R2 台鐵
            let r2TraCount = gCounts[.tra] ?? 0
            let r2TraPaid = stats.paidSums[.tra] ?? 0
            if r2TraCount >= 11 { r2 += Int(Double(r2TraPaid) * 0.02) }
            
            // R2 公車/客運
            let busCount = (gCounts[.bus] ?? 0) + (gCounts[.coach] ?? 0)
            let busPaid = (stats.paidSums[.bus] ?? 0) + (stats.paidSums[.coach] ?? 0)
            var busRate = 0.0
            if busCount > 30 { busRate = 0.30 }
            else if busCount >= 11 { busRate = 0.15 }
            r2 += Int(Double(busPaid) * busRate)
            
            // R2 輕軌（淡海、安坑）
            let lrtCount = gCounts[.lrt] ?? 0
            let lrtPaid = stats.paidSums[.lrt] ?? 0
            if lrtCount >= 11 { r2 += Int(Double(lrtPaid) * 0.02) }
        }
        
        return (r1, r2)
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
        return themeManager.cycleAccentColor
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

