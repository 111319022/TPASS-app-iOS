import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle().fill(themeManager.backgroundColor).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // 1. 週期選擇
                        Menu {
                            Button { viewModel.selectedCycle = nil } label: {
                                Label(localizationManager.localized("currentCycleAuto"), systemImage: viewModel.selectedCycle == nil ? "checkmark" : "")
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
                            HStack {
                                Image(systemName: "calendar").foregroundColor(.secondary)
                                Text(viewModel.cycleDateRange).font(.headline).foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                Image(systemName: "chevron.down").font(.caption).foregroundColor(.secondary)
                            }
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // 2. DNA 標籤 (顏色需透過 ViewModel 修改，見下一步)
                        if !viewModel.commuterDNA.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(viewModel.commuterDNA) { tag in
                                        Button(action: { selectedDNATag = tag }) {
                                            Text("#\(localizationManager.localized(tag.text))")
                                                .font(.caption).bold()
                                                .padding(.horizontal, 10).padding(.vertical, 5)
                                            // 🔥 使用 themeManager 轉換顏色
                                                .background(themeManager.currentTheme == .muji ? themeManager.dnaColor(hex: tag.color.toHex() ?? "") : tag.color)
                                                .cornerRadius(15)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // 3. 總結卡片
                        HStack(spacing: 15) {
                            SummaryStatCard(title: localizationManager.localized("totalTrips_label"), value: "\(viewModel.filteredTrips.count)", unit: localizationManager.currentLanguage == .english ? " " + localizationManager.localized("trips_unit").trimmingCharacters(in: .whitespaces) : localizationManager.localized("trips_unit"))
                            let roi = viewModel.roi
                            let isBreakeven = roi >= 100
                            SummaryStatCard(
                                title: localizationManager.localized("breakeven_rate"),
                                value: "\(roi)%",
                                unit: "",
                                color: isBreakeven ? Color(hex: "#2ecc71") : Color(hex: "#e74c3c")
                            )
                        }
                        .padding(.horizontal)
                            
                            // 4. VS 區塊
                            VsBlockView(financialStats: viewModel.financialStats)
                                .padding(.horizontal)
                            
                            // 5. 財務細項
                            VStack(spacing: 0) {
                                let stats = viewModel.financialStats
                                FinanceRowGroup(title: localizationManager.localized("originalPrice"), amount: stats.totalOriginal, color: themeManager.primaryTextColor, details: stats.originalDetails)
                                Divider()
                                FinanceRowGroup(title: localizationManager.localized("actualExpenseDetail"), sub: localizationManager.localized("actualExpenseNote"), amount: stats.totalPaid, color: themeManager.primaryTextColor, details: stats.paidDetails)
                                Divider()
                                FinanceRowGroup(title: localizationManager.localized("commonRebate"), amount: -stats.r1Total, color: .orange, details: stats.r1Details)
                                Divider()
                                FinanceRowGroup(title: localizationManager.localized("tpass2Rebate"), amount: -stats.r2Total, color: .orange, details: stats.r2Details)
                            }
                            .background(cardBackground).cornerRadius(16).padding(.horizontal)
                            
                            // 6. 極限紀錄
                            let rec = viewModel.recordStats
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                RecordCard(
                                    title: localizationManager.localized("maxDailyExpense"),
                                    val: "$\(rec.maxDailyCost.value)",
                                    sub: rec.maxDailyCost.date,
                                    icon: "dollarsign.circle.fill",
                                    color: themeManager.recordColor(.cost) // 🔥 修改這裡
                                )
                                RecordCard(
                                    title: localizationManager.currentLanguage == .english ? (localizationManager.localized("maxDailyBusy") + "\n") : localizationManager.localized("maxDailyBusy"),
                                    val: localizationManager.currentLanguage == .english ? "\(rec.maxDailyCount.value) " + localizationManager.localized("trips_unit").trimmingCharacters(in: .whitespaces) : "\(rec.maxDailyCount.value)" + localizationManager.localized("trips_unit"),
                                    sub: rec.maxDailyCount.date,
                                    icon: "figure.run",
                                    color: themeManager.recordColor(.count) // 🔥 修改這裡
                                )
                                RecordCard(
                                    title: localizationManager.localized("maxSingleTrip"),
                                    val: "$\(rec.maxSingleTrip.value)",
                                    sub: rec.maxSingleTrip.desc,
                                    icon: "crown.fill",
                                    color: themeManager.recordColor(.single) // 🔥 修改這裡
                                )
                            }
                            .padding(.horizontal)
                            
                            // 7. ROI 競速
                            ChartContainer(title: localizationManager.localized("tpassRaceProgress"), icon: "flag.checkered") {
                                Chart {
                                    RuleMark(y: .value("TPASS", 1200))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                        .foregroundStyle(.red)
                                    
                                    ForEach(viewModel.dailyCumulativeStats, id: \.date) { item in
                                        LineMark(x: .value(localizationManager.localized("date"), item.date, unit: .day), y: .value(localizationManager.localized("price"), item.cumulative))
                                            .foregroundStyle(themeManager.accentColor) // 🔥 主題色
                                            .interpolationMethod(.catmullRom)
                                        AreaMark(x: .value(localizationManager.localized("date"), item.date, unit: .day), y: .value(localizationManager.localized("price"), item.cumulative))
                                            .foregroundStyle(LinearGradient(colors: [themeManager.accentColor.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                                    }
                                }
                                .chartYAxis { AxisMarks { value in AxisValueLabel { if let v = value.as(Int.self) { Text("\(v)") } } } }
                                .frame(height: 200)
                            }
                            
                            // 8. 熱力圖
                            ChartContainer(title: localizationManager.localized("commuterHeatmap"), icon: "calendar") {
                                HeatmapView(data: viewModel.heatmapData)
                            }
                            
                            // 9. 運具深度透視
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "tram.fill")
                                    Text(localizationManager.localized("transportInsight")).font(.headline).foregroundColor(themeManager.primaryTextColor)
                                }
                                .padding(.bottom, 5)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    let savings = (viewModel.financialStats.totalOriginal - viewModel.financialStats.totalPaid)
                                    SavingSmallCard(title: localizationManager.localized("transfer_saving"), amount: savings, color: .orange)
                                    SavingSmallCard(title: localizationManager.localized("rebate_total"), amount: viewModel.financialStats.r1Total + viewModel.financialStats.r2Total, color: .blue)
                                }
                                .padding(.bottom, 10)
                                
                                ForEach(viewModel.transportStats, id: \.type) { stat in
                                    TransportDetailRow(stat: stat)
                                    Divider()
                                }
                            }
                            .padding().background(cardBackground).cornerRadius(16).padding(.horizontal)
                            
                            // 10. 平日 vs 假日 + 時段分布
                            let ws = viewModel.weekStats
                            ChartContainer(title: localizationManager.localized("timeDistribution"), icon: "calendar.badge.clock") {
                                VStack(spacing: 16) {
                                    GeometryReader { geo in
                                        HStack(spacing: 0) {
                                            Rectangle().fill(Color.blue).frame(width: geo.size.width * Double(ws.weekdayPct) / 100)
                                            Rectangle().fill(Color.red).frame(width: geo.size.width * Double(ws.weekendPct) / 100)
                                        }
                                    }
                                    .frame(height: 20)
                                    .cornerRadius(10)
                                    HStack {
                                        Label("\(localizationManager.localized("weekday")) $\(ws.weekday) (\(ws.weekdayPct)%)", systemImage: "circle.fill").foregroundColor(.blue).font(.caption)
                                        Spacer()
                                        Label("\(localizationManager.localized("weekend")) $\(ws.weekend) (\(ws.weekendPct)%)", systemImage: "circle.fill").foregroundColor(.red).font(.caption)
                                    }
                                    // 時段總分布（百分比堆疊）
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
                                                    Text("\(localizationManager.localized(slot.label)) \(pct)%")
                                        .font(.caption).foregroundColor(.gray)
                                                        .font(.caption2)
                                                        .foregroundColor(themeManager.primaryTextColor)
                                                }
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    Divider()
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(localizationManager.localized("timeDistribution")).font(.caption).foregroundColor(.secondary)
                                        ForEach(viewModel.timeSlotStats, id: \.label) { slot in
                                            let total = max(slot.weekday + slot.weekend, 1)
                                            HStack(spacing: 8) {
                                                Text(localizationManager.localized(slot.label)).font(.caption).frame(width: 80, alignment: .leading)
                                                GeometryReader { geo in
                                                    HStack(spacing: 0) {
                                                        Rectangle().fill(Color.blue.opacity(0.8)).frame(width: geo.size.width * CGFloat(slot.weekday) / CGFloat(total))
                                                        Rectangle().fill(Color.red.opacity(0.8)).frame(width: geo.size.width * CGFloat(slot.weekend) / CGFloat(total))
                                                    }
                                                }
                                                .frame(height: 10)
                                                let tripsUnit = localizationManager.currentLanguage == .english ? " " + localizationManager.localized("trips_unit").trimmingCharacters(in: .whitespaces) : localizationManager.localized("trips_unit")
                                                Text("\(slot.weekday + slot.weekend)\(tripsUnit)").font(.caption2).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 11. 熱門路線
                            VStack(alignment: .leading) {
                                HStack { Image(systemName: "map.fill"); Text(localizationManager.localized("topRoutes")).font(.headline).foregroundColor(themeManager.primaryTextColor) }
                                ForEach(Array(viewModel.topRoutes.enumerated()), id: \.element.id) { idx, route in
                                    HStack {
                                        Text("\(idx+1)").font(.caption).frame(width: 20, height: 20).background(Color.gray.opacity(0.2)).clipShape(Circle())
                                        // 🔥 使用主題色
                                        Image(systemName: route.type.systemIconName).foregroundColor(themeManager.transportColor(route.type))
                                        Text(route.name).font(.subheadline).bold().foregroundColor(themeManager.primaryTextColor)
                                        Spacer()
                                        let tripsUnit = localizationManager.currentLanguage == .english ? " " + localizationManager.localized("trips_unit").trimmingCharacters(in: .whitespaces) : localizationManager.localized("trips_unit")
                                        Text("\(route.count)\(tripsUnit)").font(.caption).foregroundColor(.secondary)
                                        Text("$\(route.totalCost)").font(.subheadline).bold().foregroundColor(themeManager.primaryTextColor)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding().background(cardBackground).cornerRadius(16).padding(.horizontal)
                            Spacer(minLength: 50)
                        }
                        .padding(.vertical)
                    }
                }
                .navigationTitle(localizationManager.localized("dashboardTitle"))
                .navigationBarTitleDisplayMode(.inline)
                .alert(localizationManager.localized(selectedDNATag?.text ?? ""), isPresented: Binding(get: { selectedDNATag != nil }, set: { if !$0 { selectedDNATag = nil } })) {
                    Button(localizationManager.localized("close"), role: .cancel) { }
                } message: {
                    Text(localizationManager.localized(selectedDNATag?.description ?? ""))
                }
                .onAppear {
                    if viewModel.selectedCycle == nil, let first = auth.currentUser?.cycles.first { viewModel.selectedCycle = first }
                }
                .onChange(of: auth.currentUser) { user in
                    if viewModel.selectedCycle == nil, let first = user?.cycles.first { viewModel.selectedCycle = first }
                }
            }
        }
    }

    // 顏色配置：清晨/深夜、上午、下午、晚上（依主題調整）
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
        case .dark, .system where isDark:
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
        @EnvironmentObject var localizationManager: LocalizationManager
        @Environment(\.colorScheme) var colorScheme
        let financialStats: FinancialBreakdown
        
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
            let diff = 1200 - actual
            let saved = actual < 1200 ? 0 : actual - 1200
            
            ZStack {
                cardBackground
                HStack {
                    VStack {
                        Text(localizationManager.localized("actualExpense")).font(.caption).foregroundColor(.secondary)
                        Text("$\(actual)").font(.title).bold().foregroundColor(themeManager.primaryTextColor)
                    }
                    Spacer()
                    Text("VS").font(.title3).italic().foregroundColor(.gray)
                    Spacer()
                    VStack {
                        Text(localizationManager.localized("tpassCost")).font(.caption).foregroundColor(.secondary)
                        Text("$1200").font(.title).bold().foregroundColor(themeManager.primaryTextColor)
                    }
                }.padding()
            }
            .cornerRadius(16)
            .overlay(
                VStack {
                    Spacer()
                    if saved > 0 { Text(localizationManager.localizedFormat("breakeven_complete", "$\(saved)")).font(.caption).bold().padding(5).background(Color.green).foregroundColor(.white).cornerRadius(5) }
                    else { Text(localizationManager.localizedFormat("notBreakeven", "$\(diff)")).font(.caption).bold().padding(5).background(Color.red).foregroundColor(.white).cornerRadius(5) }
                }.padding(.bottom, -10)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    struct FinanceRowGroup: View {
        let title: String
        var sub: String = ""
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
                            if !sub.isEmpty { Text(sub).font(.caption2).foregroundColor(.gray) }
                        }
                        Spacer()
                        Text("$\(amount)").bold().foregroundColor(color)
                        if !details.isEmpty {
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray).rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .padding(15)
                }
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
        let title: String; let icon: String; let content: () -> Content
        
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
            VStack(alignment: .leading, spacing: 15) {
                HStack { Image(systemName: icon); Text(title).font(.headline).foregroundColor(themeManager.primaryTextColor) }
                content()
            }
            .padding().background(cardBackground).cornerRadius(16).padding(.horizontal)
        }
    }
    
    struct SummaryStatCard: View {
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.colorScheme) var colorScheme
        let title: String; let value: String; let unit: String; var color: Color = .primary
        
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
                    Text(unit).font(.caption).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding().background(cardBackground).cornerRadius(12)
        }
    }
    
    struct RecordCard: View {
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.colorScheme) var colorScheme
        let title: String; let val: String; let sub: String; let icon: String; let color: Color
        
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
                Text(val)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(themeManager.primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(sub)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity).padding(12).background(cardBackground).cornerRadius(12)
        }
    }
    
    struct SavingSmallCard: View {
        @EnvironmentObject var themeManager: ThemeManager
        @EnvironmentObject var localizationManager: LocalizationManager
        let title: String; let amount: Int; let color: Color
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
        @EnvironmentObject var localizationManager: LocalizationManager
        let stat: (type: TransportType, total: Int, count: Int, percent: Double, avg: Int, max: Int)
        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    // 🔥 使用 ThemeManager 顏色
                    Image(systemName: stat.type.systemIconName).foregroundColor(themeManager.transportColor(stat.type))
                    Text(stat.type.displayName).bold().foregroundColor(themeManager.primaryTextColor)
                    Spacer()
                    let tripsUnit = localizationManager.currentLanguage == .english ? " " + localizationManager.localized("trips_unit").trimmingCharacters(in: .whitespaces) : localizationManager.localized("trips_unit")
                    Text("\(stat.count)" + tripsUnit).font(.caption).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(5)
                }
                HStack(alignment: .bottom) {
                    Text("$\(stat.total)").font(.title3).bold().foregroundColor(themeManager.primaryTextColor)
                    Text(localizationManager.localized("actualPayment")).font(.caption2).foregroundColor(.gray)
                    Spacer()
                    Text(localizationManager.localized("percentage") + " \(Int(stat.percent * 100))%").font(.caption).foregroundColor(.gray)
                }
                // 🔥 使用 ThemeManager 顏色
                GeometryReader { geo in Rectangle().fill(themeManager.transportColor(stat.type)).frame(width: geo.size.width * stat.percent) }.frame(height: 4).cornerRadius(2).background(Color.gray.opacity(0.1))
                HStack { Text(localizationManager.localized("average") + " $\(stat.avg)").font(.caption); Spacer(); Text(localizationManager.localized("highest") + " $\(stat.max)").font(.caption) }.foregroundColor(.gray)
            }.padding(.vertical, 5)
        }
    }

