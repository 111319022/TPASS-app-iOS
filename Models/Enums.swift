import Foundation
import SwiftUI

// MARK: - 交通工具類型
enum TransportType: String, Codable, CaseIterable, Identifiable {
    case mrt, bus, coach, tra, tymrt, lrt, bike
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mrt: return "北捷"
        case .bus: return "公車"
        case .coach: return "客運"
        case .tra: return "台鐵"
        case .tymrt: return "機捷"
        case .lrt: return "輕軌"
        case .bike: return "Ubike"
        }
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
        }
    }
}

// MARK: - 身分
enum Identity: String, Codable, CaseIterable {
    case adult = "adult"
    case student = "student"
    
    var label: String {
        switch self {
        case .adult: return "全票"
        case .student: return "學生"
        }
    }
    
    var transferDiscount: Int {
        switch self {
        case .adult: return 8
        case .student: return 6
        }
    }
}
