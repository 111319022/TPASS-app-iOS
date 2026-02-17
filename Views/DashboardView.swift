import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("AppLanguage") private var appLanguage: String = "zh-Hant"
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showDNAModal = false
    @State private var selectedDNATag: DNATag?
    
    var cardBackground: Color {
        switch themeManager.currentTheme {
        case .muji:
            return Color.white
        case .light:
            return Color.white
        case .dark:
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .system:
            return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
        }
    }
    
    private var tripsUnitKey: LocalizedStringKey { "trips_unit" }
    
    // 🔥 新增：獲取當前周期的方案，若無則用當前設置方案
    private var currentCycleRegion: TPASSRegion {
        viewModel.activeCycle?.region ?? auth.currentRegion
    }
    
    private var roiValue: Int {
        let monthlyPrice = currentCycleRegion.monthlyPrice
        return monthlyPrice > 0 ? Int((Double(viewModel.financialStats.totalPaid) / Double(monthlyPrice)) * 100) : 0
    }
    private var isBreakeven: Bool { roiValue >= 100 }
    
    var body: some View {
        NavigationView { dashboardRoot }
    }
    
    private var dashboardRoot: some View {
        ZStack {
            Rectangle().fill(themeManager.backgroundColor).ignoresSafeArea()
            dashboardScrollContent
        }
        .navigationTitle("dashboardTitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("dashboardTitle")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                    .id(appLanguage)
            }
        }
        .alert(
            Text(selectedDNATag?.text ?? LocalizedStringKey("close")),
            isPresented: Binding(
                get: { selectedDNATag != nil },
                set: { if !$0 { selectedDNATag = nil } }
            )
        ) {
            Button("close", role: .cancel) { }
        } message: {
            if let desc = selectedDNATag?.description {
                Text(desc)
            }
        }
        .onAppear {
            if viewModel.selectedCycle == nil, let first = auth.currentUser?.cycles.first {
                viewModel.selectedCycle = first
            }
        }
        .onChange(of: auth.currentUser) { oldValue, newValue in
            if viewModel.selectedCycle == nil, let first = newValue?.cycles.first {
                viewModel.selectedCycle = first
            }
        }
    }
    
    private var dashboardScrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                cyclePickerSection
                dnaTagsSection
                summarySection
                VsBlockView(financialStats: viewModel.financialStats, region: currentCycleRegion)
                    .padding(.horizontal)
                financeSection
                recordsSection
                roiRaceSection
                heatmapSection
                transportInsightSection
                timeDistributionSection
                topRoutesSection
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
    }
    
    private var cyclePickerSection: some View {
        Menu {
            Button { viewModel.selectedCycle = nil } label: {
                Label("currentCycleAuto", systemImage: viewModel.selectedCycle == nil ? "checkmark" : "")
            }
            Divider()
            if let cycles = auth.currentUser?.cycles {
                ForEach(cycles) { cycle in
                    Button { viewModel.selectedCycle = cycle } label: {
                        Label(cycle.title, systemImage: viewModel.selectedCycle?.id == cycle.id ? "checkmark" : "")
                    }
                }
            }
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar").foregroundColor(.secondary)
                    Text(viewModel.cycleDateRange)
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let region = currentCycleRegion as TPASSRegion? {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor)
                        Text(region.displayNameKey)
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var dnaTagsSection: some View {
        if !viewModel.commuterDNA.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.commuterDNA) { tag in
                        Button(action: { selectedDNATag = tag }) {
                            Text("#\(Text(tag.text))")
                                .font(.caption)
                                .bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    themeManager.currentTheme == .muji
                                    ? themeManager.dnaColor(hex: tag.color.toHex() ?? "")
                                    : tag.color
                                )
                                .cornerRadius(15)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var summarySection: some View {
        HStack(spacing: 15) {
            SummaryStatCard(
                title: "totalTrips_label",
                value: "\(viewModel.filteredTrips.count)",
                unit: tripsUnitKey
            )
            SummaryStatCard(
                title: "breakeven_rate",
                value: "\(roiValue)%",
                unit: nil,
                color: isBreakeven ? Color(hex: "#2ecc71") : Color(hex: "#e74c3c")
            )
        }
        .padding(.horizontal)
    }
    
    private var financeSection: some View {
        let stats = viewModel.financialStats
        return VStack(spacing: 0) {
            FinanceTransportRowGroup(title: "originalPrice", amount: stats.totalOriginal, color: themeManager.primaryTextColor, details: stats.originalDetails)
            Divider()
            FinanceTransportRowGroup(title: "actualExpenseDetail", sub: "actualExpenseNote", amount: stats.totalPaid, color: themeManager.primaryTextColor, details: stats.paidDetails)
            Divider()
            FinanceRebateRowGroup(title: "commonRebate", amount: -stats.r1Total, color: .orange, details: stats.r1Details)
            Divider()
            FinanceRebateRowGroup(title: "tpass2Rebate", amount: -stats.r2Total, color: .orange, details: stats.r2Details)
        }
        .background(cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var recordsSection: some View {
        let rec = viewModel.recordStats
        let busyVal = Text("\(rec.maxDailyCount.value)") + Text(tripsUnitKey)
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            RecordCard(
                title: "maxDailyExpense",
                val: Text("$\(rec.maxDailyCost.value)"),
                sub: Text(rec.maxDailyCost.date),
                icon: "dollarsign.circle.fill",
                color: themeManager.recordColor(.cost)
            )
            RecordCard(
                title: "maxDailyBusy",
                val: busyVal,
                sub: Text(rec.maxDailyCount.date),
                icon: "figure.run",
                color: themeManager.recordColor(.count)
            )
            RecordCard(
                title: "maxSingleTrip",
                val: Text("$\(rec.maxSingleTrip.value)"),
                sub: Text(rec.maxSingleTrip.desc),
                icon: "crown.fill",
                color: themeManager.recordColor(.single)
            )
        }
        .padding(.horizontal)
    }
    
    private var roiRaceSection: some View {
        let monthlyPrice = currentCycleRegion.monthlyPrice
        let latest = viewModel.dailyCumulativeStats.last?.cumulative ?? 0
        let progressPct = monthlyPrice > 0 ? Int(Double(latest) / Double(monthlyPrice) * 100) : 0
        let summary = String(format: NSLocalizedString("a11y_tpass_progress", comment: ""), latest, monthlyPrice, progressPct)
        return ChartContainer(title: "tpassRaceProgress", icon: "flag.checkered", accessibilitySummary: Text(summary)) {
            Chart {
                RuleMark(y: .value("TPASS", monthlyPrice))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.red)
                ForEach(viewModel.dailyCumulativeStats, id: \.date) { item in
                    LineMark(x: .value("date", item.date, unit: .day), y: .value("price", item.cumulative))
                        .foregroundStyle(themeManager.accentColor)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("date", item.date, unit: .day), y: .value("price", item.cumulative))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.accentColor.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .chartYAxis { AxisMarks { value in AxisValueLabel { if let v = value.as(Int.self) { Text("\(v)") } } } }
            .frame(height: 200)
        }
    }
    
    private var heatmapSection: some View {
        let activeDays = viewModel.heatmapData.filter { $0.level > 0 }.count
        let totalDays = viewModel.heatmapData.count
        let summary = String(format: NSLocalizedString("a11y_active_days", comment: ""), activeDays, totalDays)
        return ChartContainer(title: "commuterHeatmap", icon: "calendar", accessibilitySummary: Text(summary)) {
            HeatmapView(data: viewModel.heatmapData)
        }
    }
    
    private var transportInsightSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "tram.fill")
                    .accessibilityHidden(true)
                Text("transportInsight")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            .padding(.bottom, 5)
            
            let savings = (viewModel.financialStats.totalOriginal - viewModel.financialStats.totalPaid)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SavingSmallCard(title: "transfer_saving", amount: savings, color: .orange)
                SavingSmallCard(title: "rebate_total", amount: viewModel.financialStats.r1Total + viewModel.financialStats.r2Total, color: .blue)
            }
            .padding(.bottom, 10)
            
            ForEach(viewModel.transportStats, id: \.type) { stat in
                TransportDetailRow(stat: stat)
                Divider()
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var timeDistributionSection: some View {
        let ws = viewModel.weekStats
        let summary = String(format: NSLocalizedString("a11y_weekday_weekend", comment: ""), ws.weekday, ws.weekdayPct, ws.weekend, ws.weekendPct)
        return ChartContainer(title: "timeDistribution", icon: "calendar.badge.clock", accessibilitySummary: Text(summary)) {
            timeDistributionChart(ws)
        }
    }
    
    private var topRoutesSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "map.fill")
                    .accessibilityHidden(true)
                Text("topRoutes")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            ForEach(viewModel.topRoutes.indices, id: \.self) { idx in
                TopRouteRow(
                    rank: idx + 1,
                    route: viewModel.topRoutes[idx],
                    tripsUnitKey: tripsUnitKey
                )
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    private func getTransportDisplayName(_ type: TransportType) -> LocalizedStringKey {
        // 北捷、台中捷運、高雄捷運統一使用 metros key
        if type == .mrt || type == .tcmrt || type == .kmrt {
            return "metros"
        }
        return type.displayName
    }
    
    @ViewBuilder
    private func timeDistributionChart(_ ws: (weekday: Int, weekend: Int, weekdayPct: Int, weekendPct: Int)) -> some View {
        VStack(spacing: 16) {
            // 平日 vs 假日比較
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color.blue).frame(width: geo.size.width * Double(ws.weekdayPct) / 100)
                    Rectangle().fill(Color.red).frame(width: geo.size.width * Double(ws.weekendPct) / 100)
                }
            }
            .frame(height: 20)
            .cornerRadius(10)
            
            HStack {
                Label("\(Text("weekday")) $\(ws.weekday) (\(ws.weekdayPct)%)", systemImage: "circle.fill").foregroundColor(.blue).font(.caption)
                Spacer()
                Label("\(Text("weekend")) $\(ws.weekend) (\(ws.weekendPct)%)", systemImage: "circle.fill").foregroundColor(.red).font(.caption)
            }
            
            // 時段分布
            timeSlotDistribution()
            
            Divider()
            
            // 時段詳細統計
            timeSlotDetails()
        }
    }
    
    @ViewBuilder
    private func timeSlotDistribution() -> some View {
        let slotTotals = viewModel.timeSlotStats
        let slotSum = max(slotTotals.reduce(0) { $0 + $1.weekday + $1.weekend }, 1)
        let palette = slotPalette(themeManager.currentTheme, colorScheme)
        
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme == .dark || colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                HStack(spacing: 0) {
                    ForEach(Array(slotTotals.enumerated()), id: \.offset) { idx, slot in
                        Rectangle()
                            .fill(palette[min(idx, palette.count - 1)])
                            .frame(width: geo.size.width * CGFloat(slot.weekday + slot.weekend) / CGFloat(slotSum))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(height: 18)
        
        timeSlotLegend()
    }
    
    @ViewBuilder
    private func timeSlotLegend() -> some View {
        let slotTotals = viewModel.timeSlotStats
        let slotSum = max(slotTotals.reduce(0) { $0 + $1.weekday + $1.weekend }, 1)
        let palette = slotPalette(themeManager.currentTheme, colorScheme)
        let legendColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        
        HStack {
            Spacer(minLength: 0)
            LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 8) {
                ForEach(Array(slotTotals.enumerated()), id: \.offset) { idx, slot in
                    let pct = Int(round(Double(slot.weekday + slot.weekend) / Double(slotSum) * 100))
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(palette[min(idx, palette.count - 1)])
                            .frame(width: 14, height: 14)
                        Text("\(Text(slot.label)) \(pct)%")
                            .font(.caption2)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder
    private func timeSlotDetails() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("timeDistribution").font(.caption).foregroundColor(.secondary)
            ForEach(Array(viewModel.timeSlotStats.enumerated()), id: \.offset) { _, slot in
                timeSlotDetailRow(slot)
            }
        }
    }
    
    @ViewBuilder
    private func timeSlotDetailRow(_ slot: (label: LocalizedStringKey, weekday: Int, weekend: Int)) -> some View {
        let total = max(slot.weekday + slot.weekend, 1)
        
        HStack(spacing: 8) {
            Text(slot.label).font(.caption).frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color.blue.opacity(0.8)).frame(width: geo.size.width * CGFloat(slot.weekday) / CGFloat(total))
                    Rectangle().fill(Color.red.opacity(0.8)).frame(width: geo.size.width * CGFloat(slot.weekend) / CGFloat(total))
                }
            }
            .frame(height: 10)
            (Text("\(slot.weekday + slot.weekend)") + Text(tripsUnitKey))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func slotPalette(_ theme: AppTheme, _ colorScheme: ColorScheme?) -> [Color] {
        let isDark: Bool = {
            switch theme {
            case .dark: return true
            case .light, .muji: return false
            case .system: return colorScheme == .dark
            }
        }()
        switch theme {
        case .muji:
            return [
                Color(hex: "#9AA0A6"), // 清晨/深夜 - 柔灰
                Color(hex: "#5E81AC"), // 上午 - 靜謐藍
                Color(hex: "#D08770"), // 下午 - 溫暖杏
                Color(hex: "#B48EAD")  // 晚上 - 薰衣紫
            ]
        case .dark where isDark, .system where isDark:
            return [
                Color(hex: "#8E8E93"), // 清晨/深夜 - 中灰
                Color(hex: "#5AC8FA"), // 上午 - 淺亮藍
                Color(hex: "#FFD166"), // 下午 - 琥珀
                Color(hex: "#BF5AF2")  // 晚上 - 亮紫
            ]
        default: // light/system-light
            return [
                Color(hex: "#9CA3AF"), // 清晨/深夜 - 灰
                Color(hex: "#1E88E5"), // 上午 - 藍
                Color(hex: "#FB8C00"), // 下午 - 橘
                Color(hex: "#9C27B0")  // 晚上 - 紫
            ]
        }
    }
    
    // MARK: - Components (支援 ThemeManager)
    
    struct VsBlockView: View {
        @EnvironmentObject var themeManager: ThemeManager
        @EnvironmentObject var auth: AuthService
        @Environment(\.colorScheme) var colorScheme
        let financialStats: FinancialBreakdown
        let region: TPASSRegion  // 🔥 新增：接收該週期的方案
        
        var cardBackground: Color {
            switch themeManager.currentTheme {
            case .muji:
                return Color.white
            case .light:
                return Color.white
            case .dark:
                return Color(uiColor: .secondarySystemGroupedBackground)
            case .system:
                return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
            }
        }
        
        var body: some View {
            let actual = financialStats.totalPaid - financialStats.r1Total - financialStats.r2Total
            let monthlyPrice = region.monthlyPrice  // 🔥 改用傳入的方案
            let diff = monthlyPrice - actual
            let saved = actual < monthlyPrice ? 0 : actual - monthlyPrice
            let statusText = saved > 0
                ? String(format: NSLocalizedString("a11y_breakeven_saved", comment: ""), saved)
                : String(format: NSLocalizedString("a11y_not_breakeven_remaining", comment: ""), diff)
            
            ZStack {
                cardBackground
                HStack {
                    VStack {
                        Text("actualExpense").font(.caption).foregroundColor(.secondary)
                        Text("$\(actual)").font(.title).bold().foregroundColor(themeManager.primaryTextColor)
                    }
                    Spacer()
                    Text("VS").font(.title3).italic().foregroundColor(.gray)
                    Spacer()
                    VStack {
                        Text("tpassCost").font(.caption).foregroundColor(.secondary)
                        Text("$\(monthlyPrice)").font(.title).bold().foregroundColor(themeManager.primaryTextColor)
                    }
                }.padding()
            }
            .cornerRadius(16)
            .overlay(
                VStack {
                    Spacer()
                    if saved > 0 { Text("breakeven_complete $\(saved)").font(.caption).bold().padding(5).background(Color.green).foregroundColor(.white).cornerRadius(5) }
                    else { Text("notBreakeven $\(diff)").font(.caption).bold().padding(5).background(Color.red).foregroundColor(.white).cornerRadius(5) }
                }.padding(.bottom, -10)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(format: NSLocalizedString("a11y_actual_vs_tpass", comment: ""), actual, monthlyPrice)))
            .accessibilityValue(Text(statusText))
        }
    }
    
    struct FinanceRowGroup: View {
        let title: LocalizedStringKey
        var sub: LocalizedStringKey? = nil
        let amount: Int
        let color: Color
        let details: [(String, String)]
        @State private var isExpanded = false
        
        var body: some View {
            VStack(spacing: 0) {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(title).font(.subheadline).foregroundColor(.primary)
                            if let sub { Text(sub).font(.caption2).foregroundColor(.gray) }
                        }
                        Spacer()
                        Text("$\(amount)").bold().foregroundColor(color)
                        if !details.isEmpty {
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray).rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .padding(15)
                }
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text("$\(amount)"))
                .accessibilityHint(details.isEmpty ? Text("a11y_no_details") : Text(isExpanded ? "a11y_hide_details" : "a11y_show_details"))
                if isExpanded && !details.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(details.indices, id: \.self) { idx in
                            HStack {
                                Text(details[idx].0).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text(details[idx].1).font(.caption).bold().foregroundColor(.primary)
                            }
                            .padding(.horizontal, 15).padding(.vertical, 8).background(Color.gray.opacity(0.05))
                            if idx < details.count - 1 { Divider().padding(.leading, 15) }
                        }
                    }
                    .padding(.bottom, 5)
                }
            }
        }
    }
    
    struct FinanceTransportRowGroup: View {
        let title: LocalizedStringKey
        var sub: LocalizedStringKey? = nil
        let amount: Int
        let color: Color
        let details: [FinancialBreakdown.TransportAmountDetail]
        @State private var isExpanded = false
        
        private func labelText(for detail: FinancialBreakdown.TransportAmountDetail) -> Text {
            Text(detail.type.displayName)
            + Text(" (")
            + Text("\(detail.count)")
            + Text("trips_unit")
            + Text(")")
        }
        
        var body: some View {
            VStack(spacing: 0) {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(title).font(.subheadline).foregroundColor(.primary)
                            if let sub { Text(sub).font(.caption2).foregroundColor(.gray) }
                        }
                        Spacer()
                        Text("$\(amount)").bold().foregroundColor(color)
                        if !details.isEmpty {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .padding(15)
                }
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text("$\(amount)"))
                .accessibilityHint(details.isEmpty ? Text("a11y_no_details") : Text(isExpanded ? "a11y_hide_details" : "a11y_show_details"))
                if isExpanded && !details.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(details) { d in
                            HStack {
                                labelText(for: d)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("-$\(d.amount)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.05))
                        }
                    }
                    .padding(.bottom, 5)
                }
            }
        }
    }
    
    struct FinanceRebateRowGroup: View {
        let title: LocalizedStringKey
        var sub: LocalizedStringKey? = nil
        let amount: Int
        let color: Color
        let details: [FinancialBreakdown.RebateDetail]
        @State private var isExpanded = false
        
        private func labelText(for detail: FinancialBreakdown.RebateDetail) -> Text {
            let formattedMonth = detail.month.replacingOccurrences(of: "-", with: ".")
            switch detail.kind {
            case .r1Mrt:
                return Text("rebate_r1_mrt_item \(formattedMonth) \(detail.count) \(detail.percent)")
            case .r1Tra:
                return Text("rebate_r1_tra_item \(formattedMonth) \(detail.count) \(detail.percent)")
            case .r2Bus:
                return Text("rebate_r2_bus_item \(formattedMonth) \(detail.count) \(detail.percent)")
            case .r2Rail:
                return Text("rebate_r2_rail_item \(formattedMonth) \(detail.count) \(detail.percent)")
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(title).font(.subheadline).foregroundColor(.primary)
                            if let sub { Text(sub).font(.caption2).foregroundColor(.gray) }
                        }
                        Spacer()
                        Text("$\(amount)").bold().foregroundColor(color)
                        if !details.isEmpty {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .padding(15)
                }
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text("$\(amount)"))
                .accessibilityHint(details.isEmpty ? Text("a11y_no_details") : Text(isExpanded ? "a11y_hide_details" : "a11y_show_details"))
                if isExpanded && !details.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(details) { d in
                            HStack {
                                labelText(for: d)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("-$\(d.amount)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.05))
                        }
                    }
                    .padding(.bottom, 5)
                }
            }
        }
    }
    
    struct HeatmapView: View {
        let data: [HeatmapItem]
        @EnvironmentObject var themeManager: ThemeManager // 引入以支援無印風色系
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        
        var body: some View {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(data) { item in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForLevel(item.level))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(themeManager.primaryTextColor, lineWidth: Calendar.current.isDateInToday(item.date) ? 1.5 : 0))
                }
            }
            .accessibilityHidden(true)
        }
        
        func colorForLevel(_ level: Int) -> Color {
            // 🔥 無印風特製熱力圖色階
            if themeManager.currentTheme == .muji {
                switch level {
                case 0: return Color.gray.opacity(0.1)
                case 1: return Color(hex: "#D8E6D6") // 極淺綠
                case 2: return Color(hex: "#BCE0BC") // 淺綠
                case 3: return Color(hex: "#A8C9A4") // 抹茶
                case 4: return Color(hex: "#7A9E7E") // 深抹茶
                default: return Color.gray.opacity(0.1)
                }
            } else {
                // 原本的 GitHub 風格
                switch level {
                case 0: return Color.gray.opacity(0.2)
                case 1: return Color(hex: "#9be9a8")
                case 2: return Color(hex: "#40c463")
                case 3: return Color(hex: "#30a14e")
                case 4: return Color(hex: "#216e39")
                default: return Color.gray.opacity(0.2)
                }
            }
        }
    }
    
    struct ChartContainer<Content: View>: View {
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.colorScheme) var colorScheme
        let title: LocalizedStringKey; let icon: String; var accessibilitySummary: Text? = nil; let content: () -> Content

        init(
            title: LocalizedStringKey,
            icon: String,
            accessibilitySummary: Text? = nil,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.title = title
            self.icon = icon
            self.accessibilitySummary = accessibilitySummary
            self.content = content
        }
        
        var cardBackground: Color {
            switch themeManager.currentTheme {
            case .muji:
                return Color.white
            case .light:
                return Color.white
            case .dark:
                return Color(uiColor: .secondarySystemGroupedBackground)
            case .system:
                return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
            }
        }
        
        var body: some View {
            let base = VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: icon)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                content()
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(16)
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(title))

            if let summary = accessibilitySummary {
                base.accessibilityValue(summary)
            } else {
                base
            }
        }
    }
    
    struct SummaryStatCard: View {
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.colorScheme) var colorScheme
        let title: LocalizedStringKey; let value: String; let unit: LocalizedStringKey?; var color: Color = .primary
        
        var cardBackground: Color {
            switch themeManager.currentTheme {
            case .muji:
                return Color.white
            case .light:
                return Color.white
            case .dark:
                return Color(uiColor: .secondarySystemGroupedBackground)
            case .system:
                return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
            }
        }
        
        var body: some View {
            VStack {
                Text(title).font(.caption).foregroundColor(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value).font(.title2).bold().foregroundColor(color)
                    if let unit {
                        Text(unit).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity).padding().background(cardBackground).cornerRadius(12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityValue(unit == nil ? Text(value) : Text(value) + Text(" ") + Text(unit!))
        }
    }
    
    struct RecordCard: View {
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.colorScheme) var colorScheme
        let title: LocalizedStringKey; let val: Text; let sub: Text; let icon: String; let color: Color
        
        var cardBackground: Color {
            switch themeManager.currentTheme {
            case .muji:
                return Color.white
            case .light:
                return Color.white
            case .dark:
                return Color(uiColor: .secondarySystemGroupedBackground)
            case .system:
                return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
            }
        }
        
        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color).font(.system(size: 20)).frame(width: 44, height: 44).background(color.opacity(0.1)).clipShape(Circle())
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .center)
                val
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                sub
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity).padding(12).background(cardBackground).cornerRadius(12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityValue(val + Text(", ") + sub)
        }
    }
    
    struct SavingSmallCard: View {
        @EnvironmentObject var themeManager: ThemeManager
        //@EnvironmentObject var localizationManager: LocalizationManager
        let title: LocalizedStringKey; let amount: Int; let color: Color
        var body: some View {
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundColor(.gray)
                Text("$\(amount)").font(.title3).bold().foregroundColor(color)
            }
            .frame(maxWidth: .infinity).padding(10)
            .background(themeManager.currentTheme == .muji ? Color.black.opacity(0.05) : Color(uiColor: .systemGroupedBackground))
            .cornerRadius(8).overlay(Rectangle().fill(color).frame(width: 3), alignment: .leading)
        }
    }
    
    struct TransportDetailRow: View {
        @EnvironmentObject var themeManager: ThemeManager
        //@EnvironmentObject var localizationManager: LocalizationManager
        let stat: (type: TransportType, total: Int, count: Int, percent: Double, avg: Int, max: Int)
        
        private func getTransportDisplayName(_ type: TransportType) -> LocalizedStringKey {
            // 北捷、台中捷運、高雄捷運統一使用 metros key
            if type == .mrt || type == .tcmrt || type == .kmrt {
                return "metros"
            }
            return type.displayName
        }
        
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    // 🔥 使用 ThemeManager 顏色
                    Image(systemName: stat.type.systemIconName).foregroundColor(themeManager.transportColor(stat.type))
                    Text(getTransportDisplayName(stat.type)).bold().foregroundColor(themeManager.primaryTextColor)
                    Spacer()
                    (Text("\(stat.count)") + Text("trips_unit"))
                        .font(.caption)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(5)
                }
                HStack(alignment: .bottom) {
                    Text("$\(stat.total)").font(.title3).bold().foregroundColor(themeManager.primaryTextColor)
                    Text("actualPayment").font(.caption2).foregroundColor(.gray)
                    Spacer()
                    (Text("percentage") + Text(" \(Int(stat.percent * 100))%"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                // 🔥 使用 ThemeManager 顏色
                GeometryReader { geo in Rectangle().fill(themeManager.transportColor(stat.type)).frame(width: geo.size.width * stat.percent) }.frame(height: 4).cornerRadius(2).background(Color.gray.opacity(0.1))
                HStack {
                    (Text("average") + Text(" $\(stat.avg)")).font(.caption)
                    Spacer()
                    (Text("highest") + Text(" $\(stat.max)")).font(.caption)
                }
                .foregroundColor(.gray)
            }.padding(.vertical, 5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(getTransportDisplayName(stat.type)))
            .accessibilityValue(Text(String(format: NSLocalizedString("a11y_transport_stats", comment: ""), stat.count, stat.total, stat.avg, stat.max)))
        }
    }
    
    struct TopRouteRow: View {
        @EnvironmentObject var themeManager: ThemeManager
        
        let rank: Int
        let route: RouteStat
        let tripsUnitKey: LocalizedStringKey
        
        private var routeNameText: Text {
            let lang = Locale.current.identifier
            
            // 🔥 整合修改：統一處理 北捷、機捷、台鐵、台中捷運、高雄捷運 的雙語站名顯示
            if route.type == .mrt || route.type == .tymrt || route.type == .tra || route.type == .tcmrt || route.type == .kmrt {
                // 拆解 "起點 ↔ 終點" 字串
                let parts = route.name.split(separator: "↔").map { $0.trimmingCharacters(in: .whitespaces) }
                
                if parts.count == 2 {
                    let startName: String
                    let endName: String
                    
                    // 根據不同運具類型，去查各自的 StationData
                    switch route.type {
                    case .mrt:
                        startName = StationData.shared.displayStationName(parts[0], languageCode: lang)
                        endName = StationData.shared.displayStationName(parts[1], languageCode: lang)
                    case .tymrt:
                        startName = TYMRTStationData.shared.displayStationName(parts[0], languageCode: lang)
                        endName = TYMRTStationData.shared.displayStationName(parts[1], languageCode: lang)
                    case .tra:
                        startName = TRAStationData.shared.displayStationName(parts[0], languageCode: lang)
                        endName = TRAStationData.shared.displayStationName(parts[1], languageCode: lang)
                    case .tcmrt:
                        startName = TCMRTStationData.shared.displayStationName(parts[0], languageCode: lang)
                        endName = TCMRTStationData.shared.displayStationName(parts[1], languageCode: lang)
                    case .kmrt:
                        startName = KMRTStationData.shared.displayStationName(parts[0], languageCode: lang)
                        endName = KMRTStationData.shared.displayStationName(parts[1], languageCode: lang)
                    default:
                        startName = String(parts[0])
                        endName = String(parts[1])
                    }
                    
                    // 組合成 "Start ↔ End"
                    return Text("\(startName) ↔ \(endName)")
                }
            }
            
            // 處理公車、客運（顯示路線編號 + 運具類型）
            if let routeId = route.routeId, (route.type == .bus || route.type == .coach) {
                return Text("route_title_bus \(routeId)") + Text(" (") + Text(route.type.displayName) + Text(")")
            }
            
            // 其他情況直接顯示原始名稱
            return Text(route.name)
        }
        
        var body: some View {
            HStack {
                Text("\(rank)")
                    .font(.caption)
                    .frame(width: 20, height: 20)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                Image(systemName: route.type.systemIconName)
                    .foregroundColor(themeManager.transportColor(route.type))
                routeNameText
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                (Text("\(route.count)") + Text(tripsUnitKey))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(route.totalCost)")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(themeManager.primaryTextColor)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(format: NSLocalizedString("a11y_ranked_route_format", comment: ""), rank)) + routeNameText)
            .accessibilityValue(Text(String(format: NSLocalizedString("a11y_route_stats_format", comment: ""), route.count, route.totalCost)))
        }
    }
}
