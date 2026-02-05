import Foundation
import SwiftUI

class KMRTStationData {
    @MainActor static let shared = KMRTStationData()
    
    // 高雄捷運線路定義
    let lines: [MRTLine] = [
        MRTLine(
            id: "RED",
            code: "RED",
            name: "🔴紅線",
            color: Color(hex: "#E31937"), // 高雄捷運紅線標準色
            stations: [
                "小港", "高雄國際機場", "草衙", "前鎮高中", "凱旋", "獅甲", "三多商圈",
                "中央公園", "美麗島", "高雄車站", "後驛", "凹子底", "巨蛋", "生態園區",
                "左營", "世運", "油廠國小", "楠梓科技園區", "後勁", "都會公園", "青埔",
                "橋頭糖廠", "橋頭火車站", "岡山高醫", "岡山車站"
            ]
        ),
        MRTLine(
            id: "ORANGE",
            code: "ORANGE",
            name: "🟠橘線",
            color: Color(hex: "#FF6B35"), // 高雄捷運橘線標準色
            stations: [
                "哈瑪星", "鹽埕埔", "前金", "美麗島", "信義國小", "文化中心", "五塊厝",
                "苓雅運動園區", "衛武營", "鳳山西站", "鳳山", " 大東", "鳳山國中", "大寮"
            ]
        )
    ]
    
    // 英文站名對照表 (已更新至最新版本)
    private let stationNameENByZH: [String: String] = [
        "三多商圈": "Sanduo Shopping Dist.",
        "世運": "World Game",
        "中央公園": "Central Park",
        "五塊厝": "Wukuaicuo",
        "信義國小": "Sinyi Ele. School",
        "凱旋": "Kaisyuan",
        "凹子底": "Aozihdi",
        "前金": "Cianjin",
        "前鎮高中": "Cianjhen Sr. High School",
        "哈瑪星": "Hamasen",
        "大寮": "Daliao",
        "大東": "Dadong",
        "小港": "Siaogang",
        "岡山車站": "Gangshan Station",
        "岡山高醫": "KMU Gangshan Hospital",
        "左營": "Zuoying",
        "巨蛋": "Kaohsiung Arena",
        "後勁": "Houjing",
        "後驛": "Houyi",
        "文化中心": "Cultural Center",
        "楠梓科技園區": "Nanzih Tech. Industrial Park",
        "橋頭火車站": "Ciaotou Station",
        "橋頭糖廠": "Ciaotou Sugar Refinery",
        "油廠國小": "Oil Refinery Ele. School",
        "獅甲": "Shihjia",
        "生態園區": "Ecological District",
        "美麗島": "Formosa Boulevard",
        "苓雅運動園區": "Lingya Sports Park",
        "草衙": "Caoya",
        "衛武營": "Weiwuying",
        "都會公園": "Metropolitan Park",
        "青埔": "Cingpu",
        "高雄國際機場": "Kaohsiung Intl. Airport",
        "高雄車站": "Kaohsiung Main Sta.",
        "鳳山": "Fongshan",
        "鳳山國中": "Fongshan Jr. High School",
        "鳳山西站": "Fongshan West",
        "鹽埕埔": "Yanchengpu"
    ]
    
    // MARK: - Helper Methods
    
    private lazy var stationNameZHByEN: [String: String] = {
        var result: [String: String] = [:]
        for (zh, en) in stationNameENByZH {
            result[normalizedLookupKey(en)] = zh
        }
        return result
    }()
    
    private func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    /// 將使用者輸入的站名（可能是英文）轉成中文標準名稱
    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        
        // 如果已經是中文 Key 則直接回傳
        if stationNameENByZH.keys.contains(trimmed) { return trimmed }
        
        // 查表轉換
        let normalized = normalizedLookupKey(trimmed)
        return stationNameZHByEN[normalized] ?? trimmed
    }
    
    /// 顯示站名（支援多語言）
    func displayStationName(_ stationName: String, languageCode: String) -> String {
        if languageCode.starts(with: "en") {
            return stationNameENByZH[stationName] ?? stationName
        }
        return stationName
    }
    
    /// 顯示線路名稱（支援多語言）
    func displayLineName(_ lineName: String, languageCode: String) -> String {
        if languageCode.starts(with: "en") {
            if lineName.contains("紅") { return "🔴 Red Line" }
            if lineName.contains("橘") { return "🟠 Orange Line" }
        }
        return lineName
    }
}
