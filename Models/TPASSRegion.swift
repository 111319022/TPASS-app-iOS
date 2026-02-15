import SwiftUI

enum TPASSRegion: String, CaseIterable, Codable {
    case north = "基北北桃"
    case taoZhuZhu = "桃竹竹"
    case taoZhuZhuMiao = "桃竹竹苗"
    case zhuZhuMiao = "竹竹苗"
    case beiYiMegaPASS = "北宜跨城際及雙北"
    case beiYi = "北宜跨城際"
    case yilan = "宜蘭縣都市內"
    case yilan3Days = "宜蘭好行三日券"
    case central = "中彰投苗(非市民)"
    case centralCitizen = "中彰投苗(市民)"
    case south = "南高屏"
    case kaohsiung = "高雄"

    static var allCases: [TPASSRegion] {
        return [.north, .taoZhuZhu, .taoZhuZhuMiao, .zhuZhuMiao, .beiYiMegaPASS, .beiYi, .yilan, .yilan3Days, .central, .centralCitizen, .south, .kaohsiung]
    }
    
    var displayName: String {
        self.rawValue
    }
    
    var displayNameKey: LocalizedStringKey {
        switch self {
        case .north:
            return "plan_north"
        case .taoZhuZhu:
            return "plan_taoyuan_hsinchu"
        case .taoZhuZhuMiao:
            return "plan_TaoMiao"
        case .zhuZhuMiao:
            return "plan_ZhuMiao"
        case .beiYiMegaPASS:
            return "plan_BeiYiMegaPASS"
        case .beiYi:
            return "plan_BeiYi"
        case .yilan:
            return "plan_Yilan"
        case .yilan3Days:
            return "plan_Yilan3Days"
        case .central:
            return "plan_central_non_resident"
        case .centralCitizen:
            return "plan_central_resident"
        case .south:
            return "plan_south"
        case .kaohsiung:
            return "plan_kaohsiung"
        }
    }

    var monthlyPrice: Int {
        switch self {
        case .north: return 1200
        case .taoZhuZhu: return 799
        case .taoZhuZhuMiao: return 1200
        case .zhuZhuMiao: return 699
        case .beiYiMegaPASS: return 2300
        case .beiYi: return 1800
        case .yilan: return 750
        case .yilan3Days: return 299
        case .central: return 999
        case .centralCitizen: return 699
        case .south: return 999
        case .kaohsiung: return 399
        }
    }
    
    // 1. 定義該地區支援的運具
    var supportedModes: [TransportType] {
        switch self {
        case .north:
            return [.mrt, .bus, .coach, .tra, .tymrt, .lrt, .bike]
        case .taoZhuZhu:
            return [.tra, .bus, .coach, .tymrt, .bike]
        case .taoZhuZhuMiao:
            return [.tra, .bus, .coach, .tymrt, .bike]
        case .zhuZhuMiao:
            return [.tra, .bus, .coach, .bike]
        case .beiYiMegaPASS:
            return [.mrt, .bus, .coach, .tra, .tymrt, .lrt, .bike]
        case .beiYi:
            return [.bus, .coach, .tra, .bike]
        case .yilan, .yilan3Days:
            return [.bus, .coach, .tra]
        case .central, .centralCitizen:
            return [.tcmrt, .bus, .coach, .tra, .bike]
        case .south, .kaohsiung:
            return [.kmrt, .bus, .coach, .tra, .bike, .lrt, .ferry]
        }
    }
    
    // 2. 定義該地區公車的預設起跳價
    func defaultBusPrice(identity: Identity) -> String {
        switch self {
        case .north:
            // 雙北公車：全票15，學生12
            return identity == .student ? "12" : "15"
        case .taoZhuZhu:
            // 桃園市區公車：全票18，學生15
            return identity == .student ? "18" : "18"
        case .taoZhuZhuMiao, .zhuZhuMiao:
            // 桃竹竹苗/竹竹苗：全票15，學生15
            return identity == .student ? "15" : "15"
        case .beiYiMegaPASS, .beiYi:
            // 北宜跨城際：全票15，學生12
            return identity == .student ? "12" : "15"
        case .yilan, .yilan3Days:
            // 宜蘭：全票15，學生10
            return identity == .student ? "10" : "15"
        case .central:
            // 台中市區公車：全票20，學生15
            return identity == .student ? "15" : "15"
        case .south, .kaohsiung:
            // 高雄公車：全票12x，學生10
            return identity == .student ? "10" : "12"
        case .centralCitizen:
            // 台中市區公車：市民前十公里0
            return identity == .student ? "0" : "0"
        }
    }
    
    // 3. 定義該地區支援的轉乘優惠類型
    var supportedTransferTypes: [TransferDiscountType] {
        switch self {
        case .north:
            return [.taipei, .taoyuan_tymrt_bus, .taoyuan_bus_tymrt]
        case .taoZhuZhu:
            return [.taoyuan_tymrt_bus, .taoyuan_bus_tymrt, .hsinchu]
        case .taoZhuZhuMiao:
            return [.taoyuan_tymrt_bus, .taoyuan_bus_tymrt,  .hsinchu]
        case .zhuZhuMiao:
            return [.hsinchu]
        case .beiYiMegaPASS, .beiYi:
            return [.taipei, .yilan]
        case .yilan, .yilan3Days:
            return [.yilan]
        case .central, .centralCitizen:
            return [.taichung]
        case .south:
            return [.kaohsiungMrtBus, .kaohsiungBike, .tainanTraBus]
        case .kaohsiung:
            return [.kaohsiungMrtBus, .kaohsiungBike]
        }
    }
    
    // 別名：可用的轉乘優惠類型
    var availableTransferTypes: [TransferDiscountType] {
        return supportedTransferTypes
    }
    
    // 4. 獲取該地區的預設轉乘優惠類型
    var defaultTransferType: TransferDiscountType {
        switch self {
        case .north:
            return .taipei
        case .taoZhuZhu:
            return .taoyuan_tymrt_bus
        case .taoZhuZhuMiao, .zhuZhuMiao:
            return .taoyuan_tymrt_bus
        case .beiYiMegaPASS, .beiYi:
            return .taipei
        case .yilan, .yilan3Days:
            return .yilan
        case .central, .centralCitizen:
            return .taichung
        case .south:
            return .kaohsiungMrtBus
        case .kaohsiung:
            return .kaohsiungMrtBus
        }
    }
    
    // 🔥 5. 台鐵區域定義 - 統一整合所有TPASS方案的台鐵站點範圍
    // 每個方案對應的台鐵可用站點範圍
    struct TRARegionInfo {
        let name: String
        let ranges: [(start: String, end: String)]
    }
    
    private static let traRegionMap: [TPASSRegion: TRARegionInfo] = [
        .north: TRARegionInfo(name: "基北北桃(全部)", ranges: [("0900", "1140"), ("7290", "7390")]),
        .taoZhuZhu: TRARegionInfo(name: "桃竹竹", ranges: [("1080", "1230")]),
        .taoZhuZhuMiao: TRARegionInfo(name: "桃竹竹苗", ranges: [("1080", "1250"), ("2110", "2180"), ("3140", "3190")]),
        .zhuZhuMiao: TRARegionInfo(name: "竹竹苗", ranges: [("1150", "1250"), ("2110", "2180"), ("3140", "3190")]),
        .beiYiMegaPASS: TRARegionInfo(name: "北宜跨城際及雙北", ranges: [("0900", "1140"), ("7070", "7390")]),
        .beiYi: TRARegionInfo(name: "北宜跨城際", ranges: [("0900", "1075"), ("7070", "7390")]),
        .yilan: TRARegionInfo(name: "宜蘭縣都市內", ranges: [("7070", "7280")]),
        .yilan3Days: TRARegionInfo(name: "宜蘭好行三日券", ranges: [("0900", "1075"), ("7070", "7390")]),
        .central: TRARegionInfo(name: "中彰投苗", ranges: [
            ("1240", "1250"),  // 縱貫北段：崎頂到竹南
            ("1250", "2260"),  // 海線：竹南到追分
            ("3360", "3360"),  // 海線：彰化（特殊點）
            ("3140", "3360"),  // 山線：造橋到彰化
            ("3360", "3430"),  // 縱貫南段：彰化到二水
            ("3430", "3436")   // 集集線：二水到車埕
        ]),
        .centralCitizen: TRARegionInfo(name: "中彰投苗(市民)", ranges: [
            ("1240", "1250"),
            ("1250", "2260"),
            ("3360", "3360"),
            ("3140", "3360"),
            ("3360", "3430"),
            ("3430", "3436")
        ]),
        .south: TRARegionInfo(name: "南高屏", ranges: [("4110", "5160")]),
        .kaohsiung: TRARegionInfo(name: "高雄", ranges: [("4290", "4460")])
    ]
    
    func traRegionName() -> String {
        return TPASSRegion.traRegionMap[self]?.name ?? self.displayName
    }
    
    // MARK: - 3. 台鐵站點範圍定義
    /// 回傳該地區支援的台鐵站點區間 [(起始站ID, 結束站ID)]
    /// 陣列設計是為了支援不連續的區間（例如主線 + 支線）
    func traStationIDRange() -> [(String, String)] {
        switch self {
        case .north:
            return [
                ("0900", "1140"), // 基隆 - 新富
                ("7290", "7390"), // 八堵 - 蘇澳 (宜蘭線全線)
                ("7360", "7362"), // 深澳線：海科館 - 八斗子
                ("7330", "7336")  // 平溪線：大華 - 菁桐
            ]
        case .taoZhuZhu:
            return [
                ("1080", "1230"), // 桃園 - 香山
                ("1191", "1208")  // 內灣/六家線：千甲-內灣
            ]
        case .taoZhuZhuMiao:
            return [
                ("1080", "1250"), // 桃園 - 竹南
                ("2110", "2180"), // 談文 - 苑裡
                ("3140", "3190")  // 造橋 - 三義
            ]
        case .zhuZhuMiao:
            return [
                ("1150", "1250"), // 北湖 - 竹南
                ("2110", "2180"), // 談文 - 苑裡
                ("3140", "3190")  // 造橋 - 三義
            ]
        case .beiYiMegaPASS:
            return [
                ("0900", "1140"), // 基隆 - 新富
                ("7070", "7390")  // 漢本 - 暖暖
            ]
        case .beiYi, .yilan3Days:
            return [
                ("0900", "1075"), // 基隆 - 鳳鳴
                ("7070", "7390")  // 漢本 - 暖暖
            ]
        case .yilan:
            return [
                ("7070", "7280")  // 漢本 - 石城
            ]
        case .central, .centralCitizen:
            return [
                ("1240", "1250"),  // 縱貫北段：崎頂到竹南
                ("1250", "2260"),  // 海線：竹南到追分
                ("3360", "3360"),  // 海線：彰化（特殊點）
                ("3140", "3360"),  // 山線：造橋到彰化
                ("3360", "3430"),  // 縱貫南段：彰化到二水
                ("3430", "3436")   // 集集線：二水到車埕
            ]
        case .south:
            return [
                ("4110", "5160"), // 後壁 - 枋山
                ("4270", "4272")  // 沙崙線
            ]
        case .kaohsiung:
            return [
                ("4290", "4460")  // 大湖 - 九曲堂
            ]
        }
    }
}

