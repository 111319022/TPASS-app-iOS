import Foundation
import SwiftUI

// MARK: - 交通工具類型
enum TransportType: String, Codable, CaseIterable, Identifiable {
    case mrt, bus, coach, tra, tymrt, lrt, bike
    
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
