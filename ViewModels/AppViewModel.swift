import Foundation
import Combine
import SwiftUI
import SwiftData

// MARK: - 常用路線資料結構
struct FavoriteRoute: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: TransportType
    var startStation: String
    var endStation: String
    var routeId: String
    var price: Int
    var isTransfer: Bool
    var isFree: Bool
    
    var title: String {
        if type == .bus || type == .coach {
            return "\(routeId)路 (\(type.displayName))"
        } else {
            return "\(startStation) → \(endStation)"
        }
    }
    
    var displayTitle: String {
        return title
    }
}

// MARK: - 通勤路線資料結構
struct CommuterTripTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: TransportType
    var startStation: String
    var endStation: String
    var routeId: String
    var price: Int
    var isTransfer: Bool
    var isFree: Bool
    var note: String
    var timeSeconds: Int
    
    var displayTitle: String {
        if type == .bus || type == .coach {
            return "\(routeId)路 (\(type.displayName))"
        } else {
            return "\(startStation) → \(endStation)"
        }
    }
    
    var timeString: String {
        let h = timeSeconds / 3600
        let m = (timeSeconds % 3600) / 60
        let s = timeSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    func isSameTemplate(as other: CommuterTripTemplate) -> Bool {
        return type == other.type &&
        startStation == other.startStation &&
        endStation == other.endStation &&
        routeId == other.routeId &&
        price == other.price &&
        isTransfer == other.isTransfer &&
        isFree == other.isFree &&
        note == other.note &&
        timeSeconds == other.timeSeconds
    }
}

struct CommuterRoute: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var trips: [CommuterTripTemplate]
    
    var tripCount: Int { trips.count }
}

// MARK: - 數據結構定義
struct RecordStats {
    var maxDailyCost: (date: String, value: Int)
    var maxDailyCount: (date: String, value: Int)
    var maxSingleTrip: (date: String, value: Int, desc: String)
}

struct FinancialBreakdown {
    var totalOriginal: Int
    var totalPaid: Int
    var r1Total: Int
    var r2Total: Int
    var originalDetails: [(String, String)]
    var paidDetails: [(String, String)]
    var r1Details: [(String, String)]
    var r2Details: [(String, String)]
}

struct RouteStat: Identifiable {
    var id: String
    var name: String
    var count: Int
    var totalCost: Int
    var type: TransportType
}

struct DNATag: Identifiable {
    let id = UUID()
    let text: String
    let description: String
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
    @Published var trips: [Trip] = []
    @Published var isLoading: Bool = false
    @Published var selectedCycle: Cycle? = nil {
        didSet {
            guard selectedCycle?.id != oldValue?.id else { return }
            reloadTripsForCurrentCycle()
        }
    }
    
    @Published var favorites: [FavoriteRoute] = []
    @Published var commuterRoutes: [CommuterRoute] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    
    init() {
        // 初始化
    }
    
    // MARK: - 核心過濾邏輯
    var filteredTrips: [Trip] {
        if let cycle = selectedCycle {
            let calendar = Calendar.current
            
            // 取得週期的開始日期（00:00:00）
            let cycleStartDate = calendar.startOfDay(for: cycle.start)
            // 取得週期的結束日期（23:59:59）
            let cycleEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cycle.end)) ?? cycle.end
            
            print("🔍 週期過濾: \(cycleStartDate) ~ \(cycleEndDate)")
            
            return trips.filter { trip in
                let inRange = trip.createdAt >= cycleStartDate && trip.createdAt <= cycleEndDate
                if inRange {
                    print("   ✅ \(trip.dateStr) \(trip.timeStr) (包含)")
                } else {
                    print("   ⏭️  \(trip.dateStr) \(trip.timeStr) (排除)")
                }
                return inRange
            }.sorted { $0.createdAt < $1.createdAt }
        } else {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.year, .month], from: now)
            return trips.filter { trip in
                let tC = calendar.dateComponents([.year, .month], from: trip.createdAt)
                return tC.year == components.year && tC.month == components.month
            }.sorted { $0.createdAt < $1.createdAt }
        }
    }
    
    // MARK: - 列表分組
    var groupedTrips: [DailyTripGroup] {
        let sorted = filteredTrips.sorted { $0.createdAt > $1.createdAt }
        let grouped = Dictionary(grouping: sorted) { $0.dateStr }
        let sortedDates = grouped.keys.sorted(by: >)
        return sortedDates.map { date in
            DailyTripGroup(date: date, trips: grouped[date] ?? [])
        }
    }
    
    // MARK: - 1. 財務總覽
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
            if cycleMonthlyStats[monthKey] == nil { cycleMonthlyStats[monthKey] = MonthStats() }
            
            let r1OriginalPrice = trip.isFree ? 0 : trip.originalPrice
            cycleMonthlyStats[monthKey]!.originalSums[trip.type, default: 0] += r1OriginalPrice
            
            cycleMonthlyStats[monthKey]!.paidSums[trip.type, default: 0] += trip.paidPrice
            cycleMonthlyStats[monthKey]!.counts[trip.type, default: 0] += 1
        }
        
        for trip in trips {
            let monthKey = String(trip.dateStr.prefix(7))
            if globalMonthlyCounts[monthKey] == nil { globalMonthlyCounts[monthKey] = [:] }
            globalMonthlyCounts[monthKey]![trip.type, default: 0] += 1
        }
        
        var r1_total = 0
        var r2_total = 0
        var r1_list: [(String, String)] = []
        var r2_list: [(String, String)] = []
        
        let sortedMonths = cycleMonthlyStats.keys.sorted()
        
        for month in sortedMonths {
            let stats = cycleMonthlyStats[month]!
            let gCounts = globalMonthlyCounts[month] ?? [:]
            let monthLabel = String(month.suffix(2)) + "月"
            
            let mrtCount = gCounts[.mrt] ?? 0
            let mrtSum = stats.originalSums[.mrt] ?? 0
            var mrtRate = 0.0
            if mrtCount > 40 { mrtRate = 0.15 }
            else if mrtCount > 20 { mrtRate = 0.10 }
            else if mrtCount > 10 { mrtRate = 0.05 }
            let mrtRebate = Int(Double(mrtSum) * mrtRate)
            r1_total += mrtRebate
            if mrtRebate > 0 {
                r1_list.append(("[\(monthLabel)] 北捷 \(mrtCount)趟 (\(Int(mrtRate*100))%)", "-$\(mrtRebate)"))
            }
            
            let traCount = gCounts[.tra] ?? 0
            let traSum = stats.originalSums[.tra] ?? 0
            var traRate = 0.0
            if traCount > 40 { traRate = 0.20 }
            else if traCount > 20 { traRate = 0.15 }
            else if traCount > 10 { traRate = 0.10 }
            let traRebate = Int(Double(traSum) * traRate)
            r1_total += traRebate
            if traRebate > 0 {
                r1_list.append(("[\(monthLabel)] 台鐵 \(traCount)趟 (\(Int(traRate*100))%)", "-$\(traRebate)"))
            }
            
            let c_mrt = gCounts[.mrt] ?? 0
            let c_tra = gCounts[.tra] ?? 0
            let c_tymrt = gCounts[.tymrt] ?? 0
            let c_lrt = gCounts[.lrt] ?? 0
            let railCount = c_mrt + c_tra + c_tymrt + c_lrt
            
            let p_mrt = stats.paidSums[.mrt] ?? 0
            let p_tra = stats.paidSums[.tra] ?? 0
            let p_tymrt = stats.paidSums[.tymrt] ?? 0
            let p_lrt = stats.paidSums[.lrt] ?? 0
            let railPaid = p_mrt + p_tra + p_tymrt + p_lrt
            
            if railCount >= 11 {
                let rebate = Int(Double(railPaid) * 0.02)
                r2_total += rebate
                if rebate > 0 {
                    r2_list.append(("[\(monthLabel)] 軌道 \(railCount)趟 (2%)", "-$\(rebate)"))
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
                r2_list.append(("[\(monthLabel)] 公車 \(busCount)趟 (\(Int(busRate*100))%)", "-$\(busRebate)"))
            }
        }
        
        let sortedOriginal = typeOriginalSums.sorted { $0.value > $1.value }
        let original_details = sortedOriginal.filter { $0.value > 0 }.map { (type, amount) in
            ("\(type.displayName) (\(typeCounts[type] ?? 0)趟)", "$\(amount)")
        }
        
        let sortedPaid = typePaidSums.sorted { $0.value > $1.value }
        let paid_details = sortedPaid.filter { $0.value > 0 }.map { (type, amount) in
            ("\(type.displayName) (\(typeCounts[type] ?? 0)趟)", "$\(amount)")
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
    var commuterDNA: [DNATag] {
        var tags: [DNATag] = []
        let trips = filteredTrips
        if trips.isEmpty { return [] }
        
        let totalCount = Double(trips.count)
        let typeCounts = Dictionary(grouping: trips, by: { $0.type }).mapValues { Double($0.count) }
        
        if let topMode = typeCounts.max(by: { a, b in a.value < b.value })?.key {
            switch topMode {
            case .mrt: tags.append(DNATag(text: "🚇 北捷成癮者", description: "捷運搭乘次數居冠", color: Color(hex: "#00d2ff")))
            case .bus: tags.append(DNATag(text: "🚌 公車達人", description: "公車搭乘次數居冠", color: Color(hex: "#2ecc71")))
            case .tra: tags.append(DNATag(text: "🚆 鐵道迷", description: "台鐵搭乘次數居冠", color: Color(hex: "#bdc3c7")))
            case .tymrt: tags.append(DNATag(text: "✈️ 國門飛人", description: "機捷搭乘次數居冠", color: Color(hex: "#9b59b6")))
            default: break
            }
        }
        
        if totalCount > 100 {
            tags.append(DNATag(text: "🔥 狂熱通勤", description: "累積行程超過 100 趟", color: Color(hex: "#ff7675")))
        } else if totalCount > 50 {
            tags.append(DNATag(text: "📅 規律生活", description: "累積行程超過 50 趟", color: Color(hex: "#55efc4")))
        }
        
        let netProfit = financialStats.totalOriginal - 1200
        if netProfit > 1200 {
            tags.append(DNATag(text: "💸 倒賺省長", description: "淨收益超過 $1200", color: Color(hex: "#ffeaa7")))
        } else if netProfit > 0 {
            tags.append(DNATag(text: "💰 回本大師", description: "已回本開始獲利", color: Color(hex: "#55efc4")))
        }
        
        let calendar = Calendar.current
        let earlyBirds = trips.filter {
            let h = calendar.component(.hour, from: $0.createdAt)
            return h < 8
        }.count
        if Double(earlyBirds) / totalCount > 0.3 {
            tags.append(DNATag(text: "☀️ 早鳥部隊", description: "08:00 前行程佔比 > 30%", color: Color(hex: "#74b9ff")))
        }
        
        let nightOwls = trips.filter {
            let h = calendar.component(.hour, from: $0.createdAt)
            return h > 21
        }.count
        if Double(nightOwls) / totalCount > 0.2 {
            tags.append(DNATag(text: "🌙 深夜旅人", description: "21:00 後行程佔比 > 20%", color: Color(hex: "#a29bfe")))
        }
        
        let c_mrt = typeCounts[.mrt] ?? 0
        let c_tra = typeCounts[.tra] ?? 0
        let c_tymrt = typeCounts[.tymrt] ?? 0
        let c_lrt = typeCounts[.lrt] ?? 0
        let railCount = c_mrt + c_tra + c_tymrt + c_lrt
        
        if railCount / totalCount > 0.8 {
            tags.append(DNATag(text: "🚉 軌道之友", description: "80% 以上行程使用軌道運輸", color: Color(hex: "#81ecec")))
        }
        
        if (typeCounts[.bike] ?? 0) > 10 {
            tags.append(DNATag(text: "🚴 腳動力先鋒", description: "Ubike 搭乘超過 10 趟", color: Color(hex: "#55efc4")))
        }
        
        if (typeCounts[.coach] ?? 0) > 5 {
            tags.append(DNATag(text: "🏙️ 跨區移動者", description: "客運搭乘超過 5 趟", color: Color(hex: "#fab1a0")))
        }
        
        let dayCounts = Dictionary(grouping: trips, by: { $0.dateStr }).mapValues { $0.count }
        if dayCounts.values.contains(where: { $0 >= 10 }) {
            tags.append(DNATag(text: "🔋 能量滿點", description: "單日搭乘超過 10 趟", color: Color(hex: "#fd79e4")))
        }
        
        return tags
    }
    
    // MARK: - 其他屬性
    var cycleDateRange: String {
        if let cycle = selectedCycle { return cycle.title }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy/MM/dd"
        if let first = filteredTrips.first?.createdAt, let last = filteredTrips.last?.createdAt {
            return "\(fmt.string(from: first)) - \(fmt.string(from: last))"
        }
        return "本月週期"
    }
    
    var currentMonthTotal: Int { filteredTrips.reduce(0) { $0 + $1.paidPrice } }
    var roi: Int { Int((Double(currentMonthTotal) / 1200.0) * 100) }
    var tpassSavings: Int { filteredTrips.reduce(0) { $0 + ($1.originalPrice - $1.paidPrice) } }
    
    var recordStats: RecordStats {
        var dailyCost: [String: Int] = [:]
        var dailyCount: [String: Int] = [:]
        var maxSingle = (date: "--", value: 0, desc: "")
        
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
    
    var dailyCumulativeStats: [(date: Date, cumulative: Int)] {
        var result: [(Date, Int)] = []
        var runningTotal = 0
        let grouped = Dictionary(grouping: filteredTrips) { trip -> Date in
            let c = Calendar.current.dateComponents([.year, .month, .day], from: trip.createdAt)
            return Calendar.current.date(from: c)!
        }
        let sortedDates = grouped.keys.sorted()
        for date in sortedDates {
            runningTotal += grouped[date]?.reduce(0) { $0 + $1.paidPrice } ?? 0
            result.append((date, runningTotal))
        }
        return result
    }
    
    var transportStats: [(type: TransportType, total: Int, count: Int, percent: Double, avg: Int, max: Int)] {
        let trips = filteredTrips
        let totalSpend = Double(financialStats.totalPaid)
        if totalSpend == 0 { return [] }
        
        var stats: [TransportType: (cost: Int, count: Int, max: Int)] = [:]
        for t in trips {
            stats[t.type, default: (0,0,0)].cost += t.paidPrice
            stats[t.type, default: (0,0,0)].count += 1
            if t.originalPrice > stats[t.type]!.max { stats[t.type]!.max = t.originalPrice }
        }
        
        return stats.map { (type, val) in
            let cost = val.cost
            let count = val.count
            let maxVal = val.max
            return (type, cost, count, Double(cost)/totalSpend, cost/max(1, count), maxVal)
        }.sorted { $0.total > $1.total }
    }
    
    var timeSlotStats: [(label: String, weekday: Int, weekend: Int)] {
        var slots: [(String, Int, Int)] = [
            ("清晨/深夜", 0, 0),
            ("上午", 0, 0),
            ("下午", 0, 0),
            ("晚上", 0, 0)
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
    
    var topRoutes: [RouteStat] {
        var routes: [String: RouteStat] = [:]
        for trip in filteredTrips {
            var key = ""; var name = ""
            if (trip.type == .bus || trip.type == .coach) && !trip.routeId.isEmpty {
                key = "\(trip.type.rawValue)_\(trip.routeId)"
                name = "\(trip.routeId) 路\(trip.type == .coach ? "客運" : "公車")"
            } else if !trip.startStation.isEmpty && !trip.endStation.isEmpty {
                let stations = [trip.startStation, trip.endStation].sorted()
                key = "stations_\(stations.joined())"
                name = "\(stations[0]) ↔ \(stations[1])"
            } else { continue }
            
            if routes[key] == nil { routes[key] = RouteStat(id: key, name: name, count: 0, totalCost: 0, type: trip.type) }
            routes[key]!.count += 1
            routes[key]!.totalCost += (trip.isFree ? 0 : trip.paidPrice)
        }
        return Array(routes.values).sorted { $0.count > $1.count }.prefix(5).map { $0 }
    }
    
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
            let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"
            let dateStr = f.string(from: currentDate)
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
    
    // MARK: - 讀取邏輯（本地專用）
    func start(userId: String) {
        currentUserId = userId
        print("🔄 AppViewModel 已初始化，用戶 ID: \(userId)")
        reloadTripsForCurrentCycle()
        loadFavorites()
        loadCommuterRoutes()
    }
    
    private func currentDateRange() -> (Date, Date) {
        let calendar = Calendar.current
        if let cycle = selectedCycle {
            let start = calendar.startOfDay(for: cycle.start)
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
            return (start, end)
        } else {
            let now = Date()
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? now
            return (monthStart, monthEnd)
        }
    }
    
    private func reloadTripsForCurrentCycle() {
        print("📱 正在從本地重新載入行程資料...")
        loadTripsFromLocal()
    }
    
    private func loadTripsFromLocal() {
        if let data = UserDefaults.standard.data(forKey: "saved_trips_v1"),
           let decoded = try? JSONDecoder().decode([Trip].self, from: data) {
            self.trips = decoded
            print("✅ 從本地載入 \(decoded.count) 筆行程")
        } else {
            self.trips = []
            print("⚠️ 本地無行程資料")
        }
    }
    
    private func saveTripsToLocal() {
        do {
            let encoded = try JSONEncoder().encode(trips)
            UserDefaults.standard.set(encoded, forKey: "saved_trips_v1")
            print("✅ 行程已儲存到本地")
        } catch {
            print("❌ 儲存到本地失敗: \(error)")
        }
    }
    
    func replaceTripsWith(_ newTrips: [Trip]) {
        trips = newTrips
        saveTripsToLocal()
    }
    
    // MARK: - CRUD 操作
    
    func addTrip(_ trip: Trip) {
        print("🚀 [AppViewModel] 正在新增行程: \(trip.type.displayName) $\(trip.paidPrice)")
        trips.append(trip)
        saveTripsToLocal()
    }
    
    func updateTrip(_ trip: Trip) {
        print("🔄 [AppViewModel] 正在更新行程 ID: \(trip.id)")
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        }
        saveTripsToLocal()
    }
    
    func deleteTrip(_ trip: Trip) {
        print("🗑️ [AppViewModel] 正在刪除行程 ID: \(trip.id)")
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips.remove(at: index)
        }
        saveTripsToLocal()
    }
    
    // MARK: - 快速操作 (Quick Actions)
    
    func duplicateTrip(_ trip: Trip) {
        let newTrip = Trip(
            id: UUID().uuidString,
            userId: trip.userId,
            createdAt: Date(),
            type: trip.type,
            originalPrice: trip.originalPrice,
            paidPrice: trip.paidPrice,
            isTransfer: trip.isTransfer,
            isFree: trip.isFree,
            startStation: trip.startStation,
            endStation: trip.endStation,
            routeId: trip.routeId,
            note: trip.note
        )
        addTrip(newTrip)
    }
    
    func createReturnTrip(_ trip: Trip) {
        let shouldSwap = (trip.type != .bus)
        let newStart = shouldSwap ? trip.endStation : trip.startStation
        let newEnd = shouldSwap ? trip.startStation : trip.endStation
        
        let newTrip = Trip(
            id: UUID().uuidString,
            userId: trip.userId,
            createdAt: Date(),
            type: trip.type,
            originalPrice: trip.originalPrice,
            paidPrice: trip.paidPrice,
            isTransfer: trip.isTransfer,
            isFree: trip.isFree,
            startStation: newStart,
            endStation: newEnd,
            routeId: trip.routeId,
            note: trip.note
        )
        addTrip(newTrip)
    }

    func duplicateDayTrips(from dateStr: String) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayTrips = trips.filter { $0.dateStr == dateStr }
        guard !dayTrips.isEmpty else { return }
        for trip in dayTrips {
            let comps = calendar.dateComponents([.hour, .minute, .second], from: trip.createdAt)
            let newDate = calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: today) ?? today
            let newTrip = Trip(
                id: UUID().uuidString,
                userId: trip.userId,
                createdAt: newDate,
                type: trip.type,
                originalPrice: trip.originalPrice,
                paidPrice: trip.paidPrice,
                isTransfer: trip.isTransfer,
                isFree: trip.isFree,
                startStation: trip.startStation,
                endStation: trip.endStation,
                routeId: trip.routeId,
                note: trip.note
            )
            addTrip(newTrip)
        }
    }
    
    func deleteDayTrips(on dateStr: String) {
        let beforeCount = trips.count
        trips.removeAll { $0.dateStr == dateStr }
        if trips.count != beforeCount {
            saveTripsToLocal()
        }
    }
    
    func toggleTransfer(_ trip: Trip) {
        let identity = AuthService.shared.currentUser?.identity ?? .adult
        let discount: Int = (identity == .student) ? 6 : 8
        
        let newIsTransfer = !trip.isTransfer
        let newPaidPrice = newIsTransfer ? max(0, trip.originalPrice - discount) : trip.originalPrice
        
        let updatedTrip = Trip(
            id: trip.id,
            userId: trip.userId,
            createdAt: trip.createdAt,
            type: trip.type,
            originalPrice: trip.originalPrice,
            paidPrice: newPaidPrice,
            isTransfer: newIsTransfer,
            isFree: trip.isFree,
            startStation: trip.startStation,
            endStation: trip.endStation,
            routeId: trip.routeId,
            note: trip.note
        )
        updateTrip(updatedTrip)
    }
    
    // MARK: - Favorites Logic (本地儲存)
    
    func loadFavorites() {
        print("📱 正在載入常用路線...")
        loadFavoritesFromLocal()
    }
    
    private func loadFavoritesFromLocal() {
        if let data = UserDefaults.standard.data(forKey: "saved_favorites_v1"),
           let decoded = try? JSONDecoder().decode([FavoriteRoute].self, from: data) {
            self.favorites = decoded
            print("✅ 已從本地載入 \(decoded.count) 條常用路線")
        } else {
            self.favorites = []
            print("⚠️ 本地無常用路線資料")
        }
    }
    
    private func saveFavoritesToLocal() {
        do {
            let encoded = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(encoded, forKey: "saved_favorites_v1")
            print("✅ 常用路線已儲存到本地")
        } catch {
            print("❌ 儲存常用路線到本地失敗: \(error)")
        }
    }
    
    func replaceFavoritesWith(_ newFavorites: [FavoriteRoute]) {
        favorites = newFavorites
        saveFavoritesToLocal()
    }
    
    func addToFavorites(from trip: Trip) {
        let newFav = FavoriteRoute(
            type: trip.type,
            startStation: trip.startStation,
            endStation: trip.endStation,
            routeId: trip.routeId,
            price: trip.originalPrice,
            isTransfer: trip.isTransfer,
            isFree: trip.isFree
        )
        
        if favorites.contains(where: { $0.title == newFav.title && $0.price == newFav.price }) {
            print("⚠️ 常用路線已存在，跳過新增")
            return
        }
        
        favorites.append(newFav)
        saveFavoritesToLocal()
        print("✅ 常用路線已新增到本地")
    }
    
    func removeFavorite(_ fav: FavoriteRoute) {
        if let index = favorites.firstIndex(where: { $0.id == fav.id }) {
            favorites.remove(at: index)
        }
        saveFavoritesToLocal()
        print("✅ 常用路線已從本地刪除")
    }
    
    func quickAddTrip(from fav: FavoriteRoute) {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        let identity = AuthService.shared.currentUser?.identity ?? .adult
        let discount = (identity == .student) ? 6 : 8
        let paidPrice: Int
        if fav.isFree {
            paidPrice = 0
        } else if fav.isTransfer {
            paidPrice = max(0, fav.price - discount)
        } else {
            paidPrice = fav.price
        }
        
        let newTrip = Trip(
            id: UUID().uuidString,
            userId: userId,
            createdAt: Date(),
            type: fav.type,
            originalPrice: fav.price,
            paidPrice: paidPrice,
            isTransfer: fav.isTransfer,
            isFree: fav.isFree,
            startStation: fav.startStation,
            endStation: fav.endStation,
            routeId: fav.routeId,
            note: ""
        )
        
        addTrip(newTrip)
    }

    // MARK: - Commuter Routes Logic (本地儲存)
    func loadCommuterRoutes() {
        print("📱 正在載入通勤路線...")
        loadCommuterRoutesFromLocal()
    }
    
    private func loadCommuterRoutesFromLocal() {
        if let data = UserDefaults.standard.data(forKey: "saved_commuter_routes_v1"),
           let decoded = try? JSONDecoder().decode([CommuterRoute].self, from: data) {
            self.commuterRoutes = decoded
            print("✅ 已從本地載入 \(decoded.count) 條通勤路線")
        } else {
            self.commuterRoutes = []
            print("⚠️ 本地無通勤路線資料")
        }
    }
    
    private func saveCommuterRoutesToLocal() {
        do {
            let encoded = try JSONEncoder().encode(commuterRoutes)
            UserDefaults.standard.set(encoded, forKey: "saved_commuter_routes_v1")
            print("✅ 通勤路線已儲存到本地")
        } catch {
            print("❌ 儲存通勤路線到本地失敗: \(error)")
        }
    }
    
    func addToCommuterRoute(from trip: Trip, name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: trip.createdAt)
        let timeSeconds = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
        
        let template = CommuterTripTemplate(
            type: trip.type,
            startStation: trip.startStation,
            endStation: trip.endStation,
            routeId: trip.routeId,
            price: trip.originalPrice,
            isTransfer: trip.isTransfer,
            isFree: trip.isFree,
            note: trip.note,
            timeSeconds: timeSeconds
        )
        
        if let index = commuterRoutes.firstIndex(where: { $0.name.lowercased() == cleanName.lowercased() }) {
            if commuterRoutes[index].trips.contains(where: { $0.isSameTemplate(as: template) }) {
                print("⚠️ 通勤路線內已有相同行程，跳過新增")
                return
            }
            commuterRoutes[index].trips.append(template)
        } else {
            commuterRoutes.append(CommuterRoute(name: cleanName, trips: [template]))
        }
        saveCommuterRoutesToLocal()
        print("✅ 通勤路線已新增到本地")
    }
    
    func removeCommuterRoute(_ route: CommuterRoute) {
        if let index = commuterRoutes.firstIndex(where: { $0.id == route.id }) {
            commuterRoutes.remove(at: index)
        }
        saveCommuterRoutesToLocal()
        print("✅ 通勤路線已刪除")
    }
    
    func removeCommuterTrip(routeId: UUID, tripId: UUID) {
        guard let routeIndex = commuterRoutes.firstIndex(where: { $0.id == routeId }) else { return }
        commuterRoutes[routeIndex].trips.removeAll { $0.id == tripId }
        if commuterRoutes[routeIndex].trips.isEmpty {
            commuterRoutes.remove(at: routeIndex)
        }
        saveCommuterRoutesToLocal()
    }
    
    private func paidPriceForTemplate(_ template: CommuterTripTemplate) -> Int {
        let identity = AuthService.shared.currentUser?.identity ?? .adult
        let discount = (identity == .student) ? 6 : 8
        if template.isFree { return 0 }
        if template.isTransfer { return max(0, template.price - discount) }
        return template.price
    }
    
    func quickAddCommuterRoute(_ route: CommuterRoute) {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for template in route.trips {
            let h = template.timeSeconds / 3600
            let m = (template.timeSeconds % 3600) / 60
            let s = template.timeSeconds % 60
            let newDate = calendar.date(bySettingHour: h, minute: m, second: s, of: today) ?? today
            
            let newTrip = Trip(
                id: UUID().uuidString,
                userId: userId,
                createdAt: newDate,
                type: template.type,
                originalPrice: template.price,
                paidPrice: paidPriceForTemplate(template),
                isTransfer: template.isTransfer,
                isFree: template.isFree,
                startStation: template.startStation,
                endStation: template.endStation,
                routeId: template.routeId,
                note: template.note
            )
            addTrip(newTrip)
        }
    }
}
