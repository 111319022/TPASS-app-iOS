import Foundation
import Combine
import SwiftUI
import SwiftData

// MARK: - 數據結構定義（純 UI 用，不需要持久化）
struct RecordStats {
    var maxDailyCost: (date: String, value: Int)
    var maxDailyCount: (date: String, value: Int)
    var maxSingleTrip: (date: String, value: Int, desc: LocalizedStringKey)
}

struct FinancialBreakdown {
    var totalOriginal: Int
    var totalPaid: Int
    var r1Total: Int
    var r2Total: Int

    struct TransportAmountDetail: Identifiable {
        let id = UUID()
        let type: TransportType
        let count: Int
        let amount: Int
    }

    var originalDetails: [TransportAmountDetail]
    var paidDetails: [TransportAmountDetail]

    enum RebateKind: String {
        case r1Mrt
        case r1Tra
        case r2Rail
        case r2Bus
    }

    struct RebateDetail: Identifiable {
        let id = UUID()
        let kind: RebateKind
        let month: String
        let count: Int
        let percent: Int
        let amount: Int
    }

    var r1Details: [RebateDetail]
    var r2Details: [RebateDetail]
}

struct RouteStat: Identifiable {
    var id: String
    var name: String
    var count: Int
    var totalCost: Int
    var type: TransportType
    var routeId: String? = nil
}

struct DNATag: Identifiable {
    let id = UUID()
    let text: LocalizedStringKey
    let description: LocalizedStringKey
    let color: Color
}

struct DailyTripGroup: Identifiable, Equatable {
    var id: String { date }
    let date: String
    let trips: [Trip]
    var dailyTotal: Int { trips.reduce(0) { $0 + $1.paidPrice } }
    
    static func == (lhs: DailyTripGroup, rhs: DailyTripGroup) -> Bool {
        return lhs.date == rhs.date && lhs.trips.map(\.id) == rhs.trips.map(\.id)
    }
}

struct HeatmapItem: Identifiable {
    let id = UUID()
    let date: Date
    let level: Int
    let amount: Int
}

class AppViewModel: ObservableObject {
    //     改用 @Model Class 的陣列
    @Published var trips: [Trip] = [] {
        didSet {
            invalidateTripCaches()
        }
    }
    @Published var favorites: [FavoriteRoute] = []
    @Published var commuterRoutes: [CommuterRoute] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedCycle: Cycle? = nil {
        willSet {
            guard newValue?.id != selectedCycle?.id else { return }
            // 🔧 清除快取，讓 filteredTrips 重新計算（使用 willSet 確保在設定前清除）
            _filteredTripsCache = nil
            _groupedTripsCache = nil
        }
    }
    
    // 🔧 快取過濾後的行程，避免重複計算
    private var _filteredTripsCache: [Trip]? = nil
    private var _groupedTripsCache: [DailyTripGroup]? = nil

    private func invalidateTripCaches() {
        _filteredTripsCache = nil
        _groupedTripsCache = nil
    }
    
    // 🔧 效能優化：共享 DateFormatter 避免重複建立
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
    
    private var modelContext: ModelContext?
    private var currentUserId: String?
    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized: Bool = false
    private var isInitializing: Bool = false
    
    init() {
        // 不在這裡初始化任何SwiftData相關資料
    }

    @MainActor
    func clearInMemoryData() {
        trips = []
        favorites = []
        commuterRoutes = []
        selectedCycle = nil
    }
    
    // ✅ 新的啟動函數：接收 Context 並載入資料（防止重複呼叫）
    @MainActor
    func start(modelContext: ModelContext, userId: String) {
        // 只執行一次，後續呼叫直接跳過
        guard !hasInitialized else { return }
        hasInitialized = true
        
        self.modelContext = modelContext
        self.currentUserId = userId
        
        print("🔄 AppViewModel 啟動 (SwiftData Mode)")
        
        // 1. 執行搬家 (如果有舊資料)
        MigrationManager.migrateIfNeeded(modelContext: modelContext)
        
        // 2. 從資料庫載入資料
        fetchAllData()
    }
    
    @MainActor
    func fetchAllData() {
        guard let context = modelContext else { return }
        
        do {
            // 只載最近 3 個月的資料（通常用戶只關注現在這個週期）
            let calendar = Calendar.current
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            
            // 載入行程 (最近 3 個月，依照建立時間倒序)
            let tripDescriptor = FetchDescriptor<Trip>(
                predicate: #Predicate { $0.createdAt >= threeMonthsAgo },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            self.trips = try context.fetch(tripDescriptor)
            
            // 載入常用路線
            self.favorites = try context.fetch(FetchDescriptor<FavoriteRoute>())
            
            // 載入通勤路線
            self.commuterRoutes = try context.fetch(FetchDescriptor<CommuterRoute>())
            
            // 🔧 清除快取
            _filteredTripsCache = nil
            _groupedTripsCache = nil
            
            print("✅ SwiftData 載入完畢: \(trips.count) 行程（近 3 個月）、\(favorites.count) 常用路線、\(commuterRoutes.count) 通勤路線")
        } catch {
            print("❌ 資料載入失敗: \(error)")
        }
    }
    
    private func saveContext() {
        do {
            try modelContext?.save()
            print("✅ 資料已儲存到 SwiftData")
            errorMessage = nil
        } catch {
            let message = "儲存失敗: \(error.localizedDescription)"
            print("❌ SwiftData 儲存失敗: \(error)")
            errorMessage = message
        }
    }
    
    // MARK: - 核心過濾邏輯
    private func cycleDateRange(for cycle: Cycle) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        return (start, end)
    }

    private func isDate(_ date: Date, in cycle: Cycle) -> Bool {
        let range = cycleDateRange(for: cycle)
        return date >= range.start && date <= range.end
    }

    private func preferredDuplicateDate(for trip: Trip) -> Date {
        guard let cycle = selectedCycle else { return Date() }
        if isDate(Date(), in: cycle) { return Date() }
        if isDate(trip.createdAt, in: cycle) { return trip.createdAt }
        let range = cycleDateRange(for: cycle)
        return range.start
    }

    private func preferredDuplicateDay(for dayTrips: [Trip]) -> Date {
        let calendar = Calendar.current
        guard let cycle = selectedCycle else {
            return calendar.startOfDay(for: Date())
        }
        if isDate(Date(), in: cycle) { return calendar.startOfDay(for: Date()) }
        if let firstTrip = dayTrips.first, isDate(firstTrip.createdAt, in: cycle) {
            return calendar.startOfDay(for: firstTrip.createdAt)
        }
        let range = cycleDateRange(for: cycle)
        return calendar.startOfDay(for: range.end)
    }
    
    @MainActor
    func resolveCycle(for date: Date) -> Cycle? {
        let cycles = AuthService.shared.currentUser?.cycles ?? []
        guard !cycles.isEmpty else { return nil }
        _ = Calendar.current
        let target = date
        let matches = cycles.filter { cycle in
            let range = cycleDateRange(for: cycle)
            return target >= range.start && target <= range.end
        }
        if matches.isEmpty { return nil }
        return matches.sorted {
            if $0.start != $1.start { return $0.start > $1.start }
            return $0.end < $1.end
        }.first
    }
    
    @MainActor
    var activeCycle: Cycle? {
        selectedCycle ?? resolveCycle(for: Date())
    }
    
    @MainActor
    func cycleForTrip(date: Date) -> Cycle? {
        selectedCycle ?? resolveCycle(for: date)
    }
    
    @MainActor
    func cycleById(_ id: String?) -> Cycle? {
        guard let id else { return nil }
        return AuthService.shared.currentUser?.cycles.first { $0.id == id }
    }
    
    @MainActor
    var filteredTrips: [Trip] {
        // 🔧 如果有快取就直接回傳，避免重複計算
        if let cached = _filteredTripsCache {
            return cached
        }
        
        let result: [Trip]
        if let cycle = activeCycle {
            let range = cycleDateRange(for: cycle)
            let cycleId = cycle.id
            
            result = trips.filter { trip in
                // 先檢查日期範圍（最快的過濾條件）
                guard trip.createdAt >= range.start && trip.createdAt <= range.end else { return false }
                // 如果有 cycleId 就直接比對
                if let tripCycleId = trip.cycleId { return tripCycleId == cycleId }
                // 否則推論
                if let inferred = resolveCycle(for: trip.createdAt) { return inferred.id == cycleId }
                return true
            }.sorted { $0.createdAt < $1.createdAt }
        } else {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month], from: now)
            result = trips.filter { trip in
                let tC = calendar.dateComponents([.year, .month], from: trip.createdAt)
                return tC.year == components.year && tC.month == components.month
            }.sorted { $0.createdAt < $1.createdAt }
        }
        
        // 🔧 儲存快取
        _filteredTripsCache = result
        return result
    }
    
    // MARK: - 列表分組
    @MainActor
    var groupedTrips: [DailyTripGroup] {
        // 🔧 如果有快取就直接回傳
        if let cached = _groupedTripsCache {
            return cached
        }
        
        let sorted = filteredTrips.sorted { $0.createdAt > $1.createdAt }
        let grouped = Dictionary(grouping: sorted) { $0.dateStr }
        let sortedDates = grouped.keys.sorted(by: >)
        let result = sortedDates.map { date in
            DailyTripGroup(date: date, trips: grouped[date] ?? [])
        }
        
        // 🔧 儲存快取
        _groupedTripsCache = result
        return result
    }
    
    // MARK: - 1. 財務總覽
    @MainActor
    var financialStats: FinancialBreakdown {
        var totalOriginal = 0
        var totalPaid = 0
        
        var typeOriginalSums: [TransportType: Int] = [:]
        var typePaidSums: [TransportType: Int] = [:]
        var typeCounts: [TransportType: Int] = [:]
        
        struct MonthStats {
            var originalSums: [TransportType: Int] = [:]
            var paidSums: [TransportType: Int] = [:]
            var counts: [TransportType: Int] = [:]
        }
        var cycleMonthlyStats: [String: MonthStats] = [:]
        var globalMonthlyCounts: [String: [TransportType: Int]] = [:]
        
        let targetTrips = filteredTrips
        
        for trip in targetTrips {
            totalOriginal += trip.originalPrice
            totalPaid += trip.paidPrice
            
            typeOriginalSums[trip.type, default: 0] += trip.originalPrice
            typePaidSums[trip.type, default: 0] += trip.paidPrice
            typeCounts[trip.type, default: 0] += 1
            
            let monthKey = String(trip.dateStr.prefix(7))
            var monthStats = cycleMonthlyStats[monthKey] ?? MonthStats()

            let r1OriginalPrice = trip.isFree ? 0 : trip.originalPrice
            monthStats.originalSums[trip.type, default: 0] += r1OriginalPrice

            monthStats.paidSums[trip.type, default: 0] += trip.paidPrice
            monthStats.counts[trip.type, default: 0] += 1
            cycleMonthlyStats[monthKey] = monthStats
        }
        
        // � R2 跨方案計算：統計所有週期在同一日曆月的搭乘次數（不限當前週期）
        // 這樣才能正確計算跨方案的回饋百分比
        for trip in trips {  // 使用所有 trips，不只是 targetTrips
            let monthKey = String(trip.dateStr.prefix(7))
            var monthCounts = globalMonthlyCounts[monthKey] ?? [:]
            monthCounts[trip.type, default: 0] += 1
            globalMonthlyCounts[monthKey] = monthCounts
        }
        
        var r1_total = 0
        var r2_total = 0
        var r1_list: [FinancialBreakdown.RebateDetail] = []
        var r2_list: [FinancialBreakdown.RebateDetail] = []
        
        let sortedMonths = cycleMonthlyStats.keys.sorted()
        
        for month in sortedMonths {
            guard let stats = cycleMonthlyStats[month] else { continue }
            let gCounts = globalMonthlyCounts[month] ?? [:]
            
            //     R1 北捷：用所有週期的北捷次數判斷回饋%，但金額只計算當前週期
            let mrtCount = gCounts[.mrt] ?? 0
            let mrtSum = stats.originalSums[.mrt] ?? 0
            var mrtRate = 0.0
            if mrtCount > 40 { mrtRate = 0.15 }
            else if mrtCount > 20 { mrtRate = 0.10 }
            else if mrtCount > 10 { mrtRate = 0.05 }
            let mrtRebate = Int(Double(mrtSum) * mrtRate)
            r1_total += mrtRebate
            if mrtRebate > 0 {
                r1_list.append(
                    FinancialBreakdown.RebateDetail(
                        kind: .r1Mrt,
                        month: month,
                        count: mrtCount,
                        percent: Int(mrtRate * 100),
                        amount: mrtRebate
                    )
                )
            }
            
            //     R1 台鐵：用所有週期的台鐵次數判斷回饋%，但金額只計算當前週期
            let traCount = gCounts[.tra] ?? 0
            let traSum = stats.originalSums[.tra] ?? 0
            var traRate = 0.0
            if traCount > 40 { traRate = 0.20 }
            else if traCount > 20 { traRate = 0.15 }
            else if traCount > 10 { traRate = 0.10 }
            let traRebate = Int(Double(traSum) * traRate)
            r1_total += traRebate
            if traRebate > 0 {
                r1_list.append(
                    FinancialBreakdown.RebateDetail(
                        kind: .r1Tra,
                        month: month,
                        count: traCount,
                        percent: Int(traRate * 100),
                        amount: traRebate
                    )
                )
            }
            
            //     R2軌道類：包含所有捷運系統 + 台鐵 + 輕軌（跨方案計算）
            let c_mrt = gCounts[.mrt] ?? 0
            let c_tra = gCounts[.tra] ?? 0
            let c_tymrt = gCounts[.tymrt] ?? 0
            let c_tcmrt = gCounts[.tcmrt] ?? 0
            let c_kmrt = gCounts[.kmrt] ?? 0
            let c_lrt = gCounts[.lrt] ?? 0
            let railCount = c_mrt + c_tra + c_tymrt + c_tcmrt + c_kmrt + c_lrt
            
            let p_mrt = stats.paidSums[.mrt] ?? 0
            let p_tra = stats.paidSums[.tra] ?? 0
            let p_tymrt = stats.paidSums[.tymrt] ?? 0
            let p_tcmrt = stats.paidSums[.tcmrt] ?? 0
            let p_kmrt = stats.paidSums[.kmrt] ?? 0
            let p_lrt = stats.paidSums[.lrt] ?? 0
            let railPaid = p_mrt + p_tra + p_tymrt + p_tcmrt + p_kmrt + p_lrt
            
            if railCount >= 11 {
                let rebate = Int(Double(railPaid) * 0.02)
                r2_total += rebate
                if rebate > 0 {
                    r2_list.append(
                        FinancialBreakdown.RebateDetail(
                            kind: .r2Rail,
                            month: month,
                            count: railCount,
                            percent: 2,
                            amount: rebate
                        )
                    )
                }
            }
            
            let busCount = (gCounts[.bus] ?? 0) + (gCounts[.coach] ?? 0)
            let busPaid = (stats.paidSums[.bus] ?? 0) + (stats.paidSums[.coach] ?? 0)
            var busRate = 0.0
            if busCount > 30 { busRate = 0.30 }
            else if busCount >= 11 { busRate = 0.15 }
            let busRebate = Int(Double(busPaid) * busRate)
            r2_total += busRebate
            if busRebate > 0 {
                r2_list.append(
                    FinancialBreakdown.RebateDetail(
                        kind: .r2Bus,
                        month: month,
                        count: busCount,
                        percent: Int(busRate * 100),
                        amount: busRebate
                    )
                )
            }
        }
        
        let sortedOriginal = typeOriginalSums.sorted { $0.value > $1.value }
        let original_details: [FinancialBreakdown.TransportAmountDetail] = sortedOriginal
            .filter { $0.value > 0 }
            .map { (type, amount) in
                FinancialBreakdown.TransportAmountDetail(
                    type: type,
                    count: typeCounts[type] ?? 0,
                    amount: amount
                )
            }
        
        let sortedPaid = typePaidSums.sorted { $0.value > $1.value }
        let paid_details: [FinancialBreakdown.TransportAmountDetail] = sortedPaid
            .filter { $0.value > 0 }
            .map { (type, amount) in
                FinancialBreakdown.TransportAmountDetail(
                    type: type,
                    count: typeCounts[type] ?? 0,
                    amount: amount
                )
            }
        
        return FinancialBreakdown(
            totalOriginal: totalOriginal,
            totalPaid: totalPaid,
            r1Total: r1_total,
            r2Total: r2_total,
            originalDetails: original_details,
            paidDetails: paid_details,
            r1Details: r1_list,
            r2Details: r2_list
        )
    }
    
    // MARK: - 通勤 DNA
    @MainActor
    var commuterDNA: [DNATag] {
        var tags: [DNATag] = []
        let trips = filteredTrips
        if trips.isEmpty { return [] }
        
        let totalCount = Double(trips.count)
        let typeCounts = Dictionary(grouping: trips, by: { $0.type }).mapValues { Double($0.count) }
        
        if let topMode = typeCounts.max(by: { a, b in a.value < b.value })?.key {
            switch topMode {
            case .mrt, .tcmrt, .kmrt, .lrt:
                tags.append(DNATag(text: "dna_mrt_addict", description: "dna_mrt_addict_desc", color: Color(hex: "#00d2ff")))
            case .bus:
                tags.append(DNATag(text: "dna_bus_master", description: "dna_bus_master_desc", color: Color(hex: "#2ecc71")))
            case .tra:
                tags.append(DNATag(text: "dna_tra_fan", description: "dna_tra_fan_desc", color: Color(hex: "#bdc3c7")))
            case .tymrt:
                tags.append(DNATag(text: "dna_tymrt_flyer", description: "dna_tymrt_flyer_desc", color: Color(hex: "#9b59b6")))
            default:
                break
            }
        }
        
        if totalCount >= 120 {
            tags.append(DNATag(text: "dna_fanatic_commuter", description: "dna_fanatic_commuter_desc", color: Color(hex: "#ff7675")))
        } else if totalCount > 100 {
            tags.append(DNATag(text: "dna_regular_life", description: "dna_regular_life_desc", color: Color(hex: "#55efc4")))
        }
        
        let monthlyPrice = activeCycle?.region.monthlyPrice ?? AuthService.shared.currentRegion.monthlyPrice
        let netProfit = financialStats.totalOriginal - monthlyPrice
        if netProfit > 1200 {
            tags.append(DNATag(text: "dna_netprofit_king", description: "dna_netprofit_king_desc", color: Color(hex: "#ffeaa7")))
        } else if netProfit > 0 {
            tags.append(DNATag(text: "dna_breakeven_master", description: "dna_breakeven_master_desc", color: Color(hex: "#55efc4")))
        }
        
        let calendar = Calendar.current
        let earlyBirds = trips.filter {
            let h = calendar.component(.hour, from: $0.createdAt)
            return h < 8
        }.count
        if Double(earlyBirds) / totalCount > 0.3 {
            tags.append(DNATag(text: "dna_early_bird", description: "dna_early_bird_desc", color: Color(hex: "#74b9ff")))
        }
        
        let nightOwls = trips.filter {
            let h = calendar.component(.hour, from: $0.createdAt)
            return h > 21
        }.count
        if Double(nightOwls) / totalCount > 0.2 {
            tags.append(DNATag(text: "dna_night_owl", description: "dna_night_owl_desc", color: Color(hex: "#a29bfe")))
        }
        
        let c_mrt = typeCounts[.mrt] ?? 0
        let c_tcmrt = typeCounts[.tcmrt] ?? 0
        let c_kmrt = typeCounts[.kmrt] ?? 0
        let c_tra = typeCounts[.tra] ?? 0
        let c_tymrt = typeCounts[.tymrt] ?? 0
        let c_lrt = typeCounts[.lrt] ?? 0
        let railCount = c_mrt + c_tcmrt + c_kmrt + c_tra + c_tymrt + c_lrt
        
        if railCount / totalCount > 0.8 {
            tags.append(DNATag(text: "dna_rail_friend", description: "dna_rail_friend_desc", color: Color(hex: "#81ecec")))
        }
        
        if (typeCounts[.bike] ?? 0) > 10 {
            tags.append(DNATag(text: "dna_bike_pioneer", description: "dna_bike_pioneer_desc", color: Color(hex: "#55efc4")))
        }
        
        if (typeCounts[.coach] ?? 0) > 5 {
            tags.append(DNATag(text: "dna_cross_region", description: "dna_cross_region_desc", color: Color(hex: "#fab1a0")))
        }
        
        let dayCounts = Dictionary(grouping: trips, by: { $0.dateStr }).mapValues { $0.count }
        if dayCounts.values.contains(where: { $0 >= 10 }) {
            tags.append(DNATag(text: "dna_energy_full", description: "dna_energy_full_desc", color: Color(hex: "#fd79e4")))
        }
        
        return tags
    }
    
    // MARK: - 其他屬性
    @MainActor
    var cycleDateRange: String {
        if let cycle = activeCycle { return cycle.title }
        if let first = filteredTrips.first?.createdAt, let last = filteredTrips.last?.createdAt {
            return "\(Self.dateFormatter.string(from: first)) - \(Self.dateFormatter.string(from: last))"
        }
        return String(localized: "current_cycle_month")
    }
    
    @MainActor
    var currentMonthTotal: Int { filteredTrips.reduce(0) { $0 + $1.paidPrice } }
    @MainActor
    var roi: Int { Int((Double(currentMonthTotal) / 1200.0) * 100) }
    @MainActor
    var tpassSavings: Int { filteredTrips.reduce(0) { $0 + ($1.originalPrice - $1.paidPrice) } }
    
    @MainActor
    var recordStats: RecordStats {
        var dailyCost: [String: Int] = [:]
        var dailyCount: [String: Int] = [:]
        var maxSingle = (date: "--", value: 0, desc: LocalizedStringKey(""))
        
        for trip in filteredTrips {
            let date = String(trip.dateStr.suffix(5))
            let pp = trip.paidPrice
            dailyCost[date, default: 0] += pp
            dailyCount[date, default: 0] += 1
            if pp > maxSingle.value { maxSingle = (date, pp, trip.type.displayName) }
        }
        
        let maxCostPair = dailyCost.max { $0.value < $1.value }
        let maxCountPair = dailyCount.max { $0.value < $1.value }
        
        return RecordStats(
            maxDailyCost: (maxCostPair?.key ?? "--", maxCostPair?.value ?? 0),
            maxDailyCount: (maxCountPair?.key ?? "--", maxCountPair?.value ?? 0),
            maxSingleTrip: maxSingle
        )
    }
    
    @MainActor
    var dailyCumulativeStats: [(date: Date, cumulative: Int)] {
        var result: [(Date, Int)] = []
        var runningTotal = 0
        let grouped = Dictionary(grouping: filteredTrips) { trip -> Date in
            let c = Calendar.current.dateComponents([.year, .month, .day], from: trip.createdAt)
            return Calendar.current.date(from: c) ?? Calendar.current.startOfDay(for: trip.createdAt)
        }
        let sortedDates = grouped.keys.sorted()
        for date in sortedDates {
            runningTotal += grouped[date]?.reduce(0) { $0 + $1.paidPrice } ?? 0
            result.append((date, runningTotal))
        }
        return result
    }
    
    @MainActor
    var transportStats: [(type: TransportType, total: Int, count: Int, percent: Double, avg: Int, max: Int)] {
        let trips = filteredTrips
        let totalSpend = Double(financialStats.totalPaid)
        if totalSpend == 0 { return [] }
        
        var stats: [TransportType: (cost: Int, count: Int, max: Int)] = [:]
        for t in trips {
            var entry = stats[t.type] ?? (0, 0, 0)
            entry.cost += t.paidPrice
            entry.count += 1
            if t.originalPrice > entry.max { entry.max = t.originalPrice }
            stats[t.type] = entry
        }
        
        return stats.map { (type, val) in
            let cost = val.cost
            let count = val.count
            let maxVal = val.max
            return (type, cost, count, Double(cost)/totalSpend, cost/max(1, count), maxVal)
        }.sorted { $0.total > $1.total }
    }
    
    @MainActor
    var timeSlotStats: [(label: LocalizedStringKey, weekday: Int, weekend: Int)] {
            var slots: [(LocalizedStringKey, Int, Int)] = [
                ("early_morning", 0, 0),
                ("morning", 0, 0),
                ("afternoon", 0, 0),
                ("night", 0, 0)
            ]
    
        let calendar = Calendar.current
        for trip in filteredTrips {
            let day = calendar.component(.weekday, from: trip.createdAt)
            let hour = calendar.component(.hour, from: trip.createdAt)
            let isWeekend = day == 1 || day == 7
            let idx: Int
            switch hour {
            case 6..<12: idx = 1
            case 12..<18: idx = 2
            case 18...23: idx = 3
            default: idx = 0
            }
            if isWeekend { slots[idx].2 += 1 } else { slots[idx].1 += 1 }
        }
        return slots
    }
    
    @MainActor
    var weekStats: (weekday: Int, weekend: Int, weekdayPct: Int, weekendPct: Int) {
        var wd = 0, we = 0
        let calendar = Calendar.current
        for trip in filteredTrips {
            let day = calendar.component(.weekday, from: trip.createdAt)
            let val = trip.isFree ? 0 : trip.paidPrice
            if day == 1 || day == 7 { we += val } else { wd += val }
        }
        let total = Double(wd + we)
        let wdPct = total > 0 ? Int((Double(wd)/total)*100) : 0
        return (wd, we, wdPct, 100 - wdPct)
    }
    
    @MainActor
    var topRoutes: [RouteStat] {
        var routes: [String: RouteStat] = [:]
        for trip in filteredTrips {
            var key = ""
            var name = ""
            var routeId: String? = nil
            if (trip.type == .bus || trip.type == .coach) && !trip.routeId.isEmpty {
                let rid = trip.routeId
                key = "\(trip.type.rawValue)_\(rid)"
                name = rid
                routeId = rid
            } else if !trip.startStation.isEmpty && !trip.endStation.isEmpty {
                let stations = [trip.startStation, trip.endStation].sorted()
                key = "stations_\(stations.joined())"
                name = "\(stations[0]) ↔ \(stations[1])"
            } else { continue }
            
            if routes[key] == nil { routes[key] = RouteStat(id: key, name: name, count: 0, totalCost: 0, type: trip.type, routeId: routeId) }
            if var route = routes[key] {
                route.count += 1
                route.totalCost += (trip.isFree ? 0 : trip.paidPrice)
                routes[key] = route
            }
        }
        return Array(routes.values).sorted { $0.count > $1.count }.prefix(5).map { $0 }
    }
    
    @MainActor
    var heatmapData: [HeatmapItem] {
        var map: [String: Int] = [:]
        for trip in filteredTrips { map[trip.dateStr, default: 0] += trip.originalPrice }
        
        var items: [HeatmapItem] = []
        let calendar = Calendar.current
        let startDate: Date
        let endDate: Date
        
        if let cycle = selectedCycle {
            startDate = cycle.start
            endDate = cycle.end
        } else if let first = filteredTrips.first?.createdAt, let last = filteredTrips.last?.createdAt {
            startDate = first; endDate = last
        } else { return [] }
        
        var currentDate = startDate
        let endOfEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        while currentDate <= endOfEndDate {
            let dateStr = Self.dateFormatter.string(from: currentDate)
            let cost = map[dateStr] ?? 0
            
            let level: Int
            if cost == 0 { level = 0 }
            else if cost > 200 { level = 4 }
            else if cost > 100 { level = 3 }
            else if cost > 50 { level = 2 }
            else { level = 1 }
            
            items.append(HeatmapItem(date: currentDate, level: level, amount: cost))
            if let next = calendar.date(byAdding: .day, value: 1, to: currentDate) { currentDate = next } else { break }
        }
        return items
    }
    
    // MARK: - 日期範圍計算
    @MainActor
    private func currentDateRange() -> (Date, Date) {
        let calendar = Calendar.current
        if let cycle = activeCycle {
            let range = cycleDateRange(for: cycle)
            return (range.start, range.end)
        } else {
            let now = Date()
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? now
            return (monthStart, monthEnd)
        }
    }
    
    // MARK: - Favorites Logic

    @MainActor
    func quickAddTrip(from fav: FavoriteRoute) {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        let identity = AuthService.shared.currentUser?.identity ?? .adult
        let paidPrice: Int
        if fav.isFree {
            paidPrice = 0
        } else if fav.isTransfer, let type = fav.transferDiscountType {
            let discount = type.discount(for: identity)
            paidPrice = max(0, fav.price - discount)
        } else {
            paidPrice = fav.price
        }
        
        let createdAt = Date()
        let cycleId = cycleForTrip(date: createdAt)?.id
        let newTrip = Trip(
            id: UUID().uuidString,
            userId: userId,
            createdAt: createdAt,
            type: fav.type,
            originalPrice: fav.price,
            paidPrice: paidPrice,
            isTransfer: fav.isTransfer,
            isFree: fav.isFree,
            startStation: fav.startStation,
            endStation: fav.endStation,
            routeId: fav.routeId,
            note: "",
            transferDiscountType: fav.transferDiscountType,
            cycleId: cycleId
        )
        
        addTrip(newTrip)
    }

    @MainActor
    func quickAddCommuterRoute(_ route: CommuterRoute) {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        guard let context = modelContext else { return }

        let calendar = Calendar.current
        let today = Date()
        let baseDate = calendar.dateComponents([.year, .month, .day], from: today)

        for template in route.trips {
            let hour = template.timeSeconds / 3600
            let minute = (template.timeSeconds % 3600) / 60
            let second = template.timeSeconds % 60

            var comps = baseDate
            comps.hour = hour
            comps.minute = minute
            comps.second = second

            let createdAt = calendar.date(from: comps) ?? today
            let paidPrice = paidPriceForTemplate(template)

            let cycleId = cycleForTrip(date: createdAt)?.id
            let newTrip = Trip(
                id: UUID().uuidString,
                userId: userId,
                createdAt: createdAt,
                type: template.type,
                originalPrice: template.price,
                paidPrice: paidPrice,
                isTransfer: template.isTransfer,
                isFree: template.isFree,
                startStation: template.startStation,
                endStation: template.endStation,
                routeId: template.routeId,
                note: template.note,
                transferDiscountType: template.transferDiscountType,
                cycleId: cycleId
            )

            context.insert(newTrip)
        }

        saveContext()
        invalidateTripCaches()
        fetchAllData()
    }

    // MARK: - Commuter Route Helper
    @MainActor
    private func paidPriceForTemplate(_ template: CommuterTripTemplate) -> Int {
        let identity = AuthService.shared.currentUser?.identity ?? .adult
        if template.isFree { return 0 }
        if template.isTransfer, let type = template.transferDiscountType {
            let discount = type.discount(for: identity)
            return max(0, template.price - discount)
        }
        return template.price
    }
    
    // MARK: - CRUD 操作 (改寫為 SwiftData)
    
    @MainActor
    func addTrip(_ trip: Trip) {
        modelContext?.insert(trip)
        saveContext()
        // 🔧 優化：直接更新陣列而非重新載入
        trips.insert(trip, at: 0)
        _filteredTripsCache = nil
        _groupedTripsCache = nil
    }
    
    @MainActor
    func deleteTrip(_ trip: Trip) {
        modelContext?.delete(trip)
        saveContext()
        // 🔧 優化：直接從陣列移除
        trips.removeAll { $0.id == trip.id }
        _filteredTripsCache = nil
        _groupedTripsCache = nil
    }
    
    @MainActor
    func updateTrip(_ trip: Trip) {
        guard let context = modelContext else { return }
        let tripId = trip.id
        let descriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.id == tripId })
        if let original = try? context.fetch(descriptor).first {
            original.userId = trip.userId
            original.createdAt = trip.createdAt
            original.type = trip.type
            original.originalPrice = trip.originalPrice
            original.paidPrice = trip.paidPrice
            original.isTransfer = trip.isTransfer
            original.isFree = trip.isFree
            original.startStation = trip.startStation
            original.endStation = trip.endStation
            original.routeId = trip.routeId
            original.note = trip.note
            original.cycleId = trip.cycleId
            saveContext()
            // 🔧 優化：只清除快取，不重新載入
            _filteredTripsCache = nil
            _groupedTripsCache = nil
        }
    }
    
    @MainActor
    func replaceTripsWith(_ newTrips: [Trip]) {
        guard let context = modelContext else { return }
        try? context.delete(model: Trip.self)
        for trip in newTrips { context.insert(trip) }
        saveContext()
        fetchAllData()
    }
    
    @MainActor
    func replaceFavoritesWith(_ newFavorites: [FavoriteRoute]) {
        guard let context = modelContext else { return }
        try? context.delete(model: FavoriteRoute.self)
        for favorite in newFavorites { context.insert(favorite) }
        saveContext()
        fetchAllData()
    }
    
    @MainActor
    func addToFavorites(from trip: Trip) {
        let newFav = FavoriteRoute(
            type: trip.type, startStation: trip.startStation, endStation: trip.endStation,
            routeId: trip.routeId, price: trip.originalPrice, isTransfer: trip.isTransfer, isFree: trip.isFree,
            transferDiscountType: trip.transferDiscountType
        )
        if !favorites.contains(where: { $0.title == newFav.title && $0.price == newFav.price }) {
            modelContext?.insert(newFav)
            saveContext()
            favorites.append(newFav)
        }
    }
    
    @MainActor
    func removeFavorite(_ fav: FavoriteRoute) {
        modelContext?.delete(fav)
        saveContext()
        favorites.removeAll { $0.id == fav.id }
    }
    
    @MainActor
    func addToCommuterRoute(from trip: Trip, name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: trip.createdAt)
        let timeSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        
        let template = CommuterTripTemplate(
            type: trip.type, startStation: trip.startStation, endStation: trip.endStation,
            routeId: trip.routeId, price: trip.originalPrice, isTransfer: trip.isTransfer,
            isFree: trip.isFree, note: trip.note, timeSeconds: timeSeconds,
            transferDiscountType: trip.transferDiscountType
        )
        
        if let existingRoute = commuterRoutes.first(where: { $0.name.lowercased() == cleanName.lowercased() }) {
            if !existingRoute.trips.contains(where: { $0.isSameTemplate(as: template) }) {
                existingRoute.trips.append(template)
            }
        } else {
            let newRoute = CommuterRoute(name: cleanName, trips: [template])
            modelContext?.insert(newRoute)
            commuterRoutes.append(newRoute)
        }
        saveContext()
        invalidateTripCaches()
    }
    
    @MainActor
    func removeCommuterRoute(_ route: CommuterRoute) {
        modelContext?.delete(route)
        saveContext()
        commuterRoutes.removeAll { $0.id == route.id }
    }
    
    @MainActor
    func removeCommuterTrip(routeId: UUID, tripId: UUID) {
        guard let route = commuterRoutes.first(where: { $0.id == routeId }) else { return }
        route.trips.removeAll { $0.id == tripId }
        if route.trips.isEmpty {
            modelContext?.delete(route)
            commuterRoutes.removeAll { $0.id == routeId }
        }
        saveContext()
    }
    
    @MainActor
    func duplicateTrip(_ trip: Trip) {
        guard let userId = currentUserId else { return }
        let createdAt = preferredDuplicateDate(for: trip)
        let cycleId = trip.cycleId ?? cycleForTrip(date: createdAt)?.id
        let newTrip = Trip(
            id: UUID().uuidString,
            userId: userId,
            createdAt: createdAt,
            type: trip.type,
            originalPrice: trip.originalPrice,
            paidPrice: trip.paidPrice,
            isTransfer: trip.isTransfer,
            isFree: trip.isFree,
            startStation: trip.startStation,
            endStation: trip.endStation,
            routeId: trip.routeId,
            note: trip.note,
            transferDiscountType: trip.transferDiscountType,
            cycleId: cycleId
        )
        modelContext?.insert(newTrip)
        saveContext()
        trips.insert(newTrip, at: 0)
        _filteredTripsCache = nil
        _groupedTripsCache = nil
    }
    
    @MainActor
    func createReturnTrip(_ trip: Trip) {
        guard let userId = currentUserId else { return }
        // 🔧 修正：如果有填寫起訖站就對調，無論是什麼運具
        let hasStations = !trip.startStation.isEmpty && !trip.endStation.isEmpty
        let shouldSwap = hasStations
        let newStart = shouldSwap ? trip.endStation : trip.startStation
        let newEnd = shouldSwap ? trip.startStation : trip.endStation
        let createdAt = preferredDuplicateDate(for: trip)
        let cycleId = trip.cycleId ?? cycleForTrip(date: createdAt)?.id
        
        let newTrip = Trip(
            id: UUID().uuidString,
            userId: userId,
            createdAt: createdAt,
            type: trip.type,
            originalPrice: trip.originalPrice,
            paidPrice: trip.paidPrice,
            isTransfer: trip.isTransfer,
            isFree: trip.isFree,
            startStation: newStart,
            endStation: newEnd,
            routeId: trip.routeId,
            note: trip.note,
            transferDiscountType: trip.transferDiscountType,
            cycleId: cycleId
        )
        modelContext?.insert(newTrip)
        saveContext()
        trips.insert(newTrip, at: 0)
        _filteredTripsCache = nil
        _groupedTripsCache = nil
    }

    @MainActor
    func duplicateDayTrips(from dateStr: String) {
        guard let userId = currentUserId else { return }
        let calendar = Calendar.current
        let dayTrips = trips.filter { $0.dateStr == dateStr }
        guard !dayTrips.isEmpty else { return }
        let targetDay = preferredDuplicateDay(for: dayTrips)
        duplicateDayTrips(from: dateStr, targetDay: targetDay)
    }

    @MainActor
    func duplicateDayTrips(from dateStr: String, targetDay: Date) {
        guard let userId = currentUserId else { return }
        let calendar = Calendar.current
        let dayTrips = trips.filter { $0.dateStr == dateStr }
        guard !dayTrips.isEmpty else { return }
        let normalizedTarget = calendar.startOfDay(for: targetDay)

        for trip in dayTrips {
            let comps = calendar.dateComponents([.hour, .minute, .second], from: trip.createdAt)
            let newDate = calendar.date(
                bySettingHour: comps.hour ?? 0,
                minute: comps.minute ?? 0,
                second: comps.second ?? 0,
                of: normalizedTarget
            ) ?? normalizedTarget
            let cycleId = trip.cycleId ?? cycleForTrip(date: newDate)?.id
            let newTrip = Trip(
                id: UUID().uuidString,
                userId: userId,
                createdAt: newDate,
                type: trip.type,
                originalPrice: trip.originalPrice,
                paidPrice: trip.paidPrice,
                isTransfer: trip.isTransfer,
                isFree: trip.isFree,
                startStation: trip.startStation,
                endStation: trip.endStation,
                routeId: trip.routeId,
                note: trip.note,
                cycleId: cycleId
            )
            modelContext?.insert(newTrip)
            trips.insert(newTrip, at: 0)
        }
        saveContext()
        invalidateTripCaches()
    }
    
    @MainActor
    func deleteDayTrips(on dateStr: String) {
        let dayTrips = trips.filter { $0.dateStr == dateStr }
        for trip in dayTrips {
            modelContext?.delete(trip)
        }
        trips.removeAll { $0.dateStr == dateStr }
        saveContext()
        _filteredTripsCache = nil
        _groupedTripsCache = nil
    }
    
    @MainActor
    func toggleTransfer(_ trip: Trip) {
        let identity = AuthService.shared.currentUser?.identity ?? .adult
        let region = cycleById(trip.cycleId)?.region ?? cycleForTrip(date: trip.createdAt)?.region ?? AuthService.shared.currentRegion
        
        trip.isTransfer = !trip.isTransfer
        
        if trip.isTransfer {
            // 打開轉乘：使用該地區的預設轉乘類型
            trip.transferDiscountType = region.defaultTransferType
            let discount = region.defaultTransferType.discount(for: identity)
            trip.paidPrice = max(0, trip.originalPrice - discount)
        } else {
            // 關閉轉乘
            trip.transferDiscountType = nil
            trip.paidPrice = trip.originalPrice
        }
        
        saveContext()
    }
    
    //     新增：根據轉乘類型更新行程
    @MainActor
    func setTransferType(_ trip: Trip, transferType: TransferDiscountType?) {
        let identity = AuthService.shared.currentUser?.identity ?? .adult
        
        trip.transferDiscountType = transferType
        
        if let transferType = transferType {
            trip.isTransfer = true
            let discount = transferType.discount(for: identity)
            trip.paidPrice = max(0, trip.originalPrice - discount)
        } else {
            trip.isTransfer = false
            trip.paidPrice = trip.originalPrice
        }
        
        saveContext()
        invalidateTripCaches()
    }
}
