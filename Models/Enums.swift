import Foundation
import SwiftUI

// MARK: - 交通工具類型
enum TransportType: String, Codable, CaseIterable, Identifiable {
    case mrt, bus, coach, tra, tymrt, lrt, bike
    case tcmrt // 🔥 新增：台中捷運
    case kmrt  // 🔥 新增：高雄捷運
    
    var id: String { rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .mrt: return "mrt"
        case .bus: return "bus"
        case .coach: return "coach"
        case .tra: return "tra"
        case .tymrt: return "tymrt"
        case .lrt: return "lrt"
        case .bike: return "bike"
        case .tcmrt: return "tcmrt"
        case .kmrt: return "kmrt"
        }
    }

    var displayNameKey: String {
        rawValue
    }
    
    var color: Color {
        switch self {
        case .mrt: return Color(hex: "#0070BD")
        case .bus: return Color(hex: "#2ECC71")
        case .coach: return Color(hex: "#16A085")
        case .tra: return Color(hex: "#2C3E50")
        case .tymrt: return Color(hex: "#8E44AD")
        case .lrt: return Color(hex: "#F39C12")
        case .bike: return Color(hex: "#D35400")
        case .tcmrt: return Color(hex: "#E31937")  // 台中捷運紅色
        case .kmrt: return Color(hex: "#FF6B35")   // 高雄捷運橘色
        }
    }
    
    var systemIconName: String {
        switch self {
        case .mrt: return "tram.fill"
        case .bus: return "bus.fill"
        case .coach: return "bus.doubledecker.fill"
        case .tra: return "train.side.front.car"
        case .tymrt: return "airplane.departure"
        case .lrt: return "cablecar.fill"
        case .bike: return "bicycle"
        case .tcmrt: return "tram.fill"
        case .kmrt: return "tram.fill"
        }
    }
}

// MARK: - 身分
enum Identity: String, Codable, CaseIterable {
    case adult = "adult"
    case student = "student"
    
    var label: LocalizedStringKey {
        switch self {
        case .adult: return "identity_adult"
        case .student: return "identity_student"
        }
    }
    
    var transferDiscount: Int {
        switch self {
        case .adult: return 8
        case .student: return 6
        }
    }
}

// MARK: - 轉乘優惠類型
enum TransferDiscountType: String, Codable, CaseIterable, Identifiable {
    // 基北北桃
    case taipei = "taipei"              // 雙北/桃園標準轉乘 -8元(成人)/-6元(學生)
    
    // 桃竹竹
    case taoyuan = "taoyuan_citizen"            // 桃園市民轉乘 機捷公車-7元
    
    // 中彰投苗
    case taichung = "taichung_citizen"          // 台中市民轉乘 -10元
    
    // 南高屏/高雄
    case kaohsiungMrtBus = "kaohsiung_mrt_bus"        // 高雄捷運↔公車 -3元
    case kaohsiungBike = "kaohsiung_bike"             // 高雄YouBike↔其他運具 -5元
    case tainanTraBus = "tainan_tra_bus"              // 台南台鐵↔公車 -9元
    
    var id: String { rawValue }
    
    var displayNameKey: LocalizedStringKey {
        switch self {
        case .taipei: return "transfer_taipei"
        case .taoyuan: return "transfer_taoyuan_citizen"
        case .taichung: return "transfer_taichung_citizen"
        case .kaohsiungMrtBus: return "transfer_kaohsiung_mrt_bus"
        case .kaohsiungBike: return "transfer_kaohsiung_bike"
        case .tainanTraBus: return "transfer_tainan_tra_bus"
        }
    }
    
    // 🔥 新增：根據身份返回動態的 displayNameKey
    func displayNameKey(for identity: Identity) -> LocalizedStringKey {
        switch self {
        case .taipei:
            // 雙北/桃園轉乘根據身份顯示
            return identity == .student ? "transfer_taipei_student" : "transfer_taipei_adult"
        default:
            return displayNameKey
        }
    }
    
    func discount(for identity: Identity) -> Int {
        switch self {
        case .taipei:
            return identity == .adult ? 8 : 6
        case .taoyuan:
            return 7
        case .taichung:
            return 10
        case .kaohsiungMrtBus:
            return 3
        case .kaohsiungBike:
            return 5
        case .tainanTraBus:
            return 9
        }
    }
}

// MARK: - 捷運資料來源
enum MetroDataSource {
    case taipei      // MRT
    case taoyuan     // AIRTRAIN
    case taichung    // TCMRT
    case kaohsiung   // KMRT
}

