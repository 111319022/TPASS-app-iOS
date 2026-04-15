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
                "苓雅運動園區", "衛武營", "鳳山西站", "鳳山", "大東", "鳳山國中", "大寮"
            ]
        )
    ]
    
    // 英文站名對照表 (已更新至最新版本)
    private let stationNameENByZH: [String: String] = [
            // MARK: - 紅線 Red Line (北到南)
            "岡山車站": "Gangshan Station",
            "岡山高醫": "KMU Gangshan Hospital",
            "橋頭火車站": "Ciaotou Station",
            "橋頭糖廠": "Ciaotou Sugar Refinery",
            "青埔": "Cingpu",
            "都會公園": "Metropolitan Park",
            "後勁": "Houjing",
            "楠梓科技園區": "Nanzih Tech. Industrial Park",
            "油廠國小": "Oil Refinery Ele. School",
            "世運": "World Game",
            "左營": "Zuoying",
            "生態園區": "Ecological District",
            "巨蛋": "Kaohsiung Arena",
            "凹子底": "Aozihdi",
            "後驛": "Houyi",
            "高雄車站": "Kaohsiung Main Sta.",
            "美麗島": "Formosa Boulevard", // 紅橘線交會
            "中央公園": "Central Park",
            "三多商圈": "Sanduo Shopping Dist.",
            "獅甲": "Shihjia",
            "凱旋": "Kaisyuan",
            "前鎮高中": "Cianjhen Sr. High School",
            "草衙": "Caoya",
            "高雄國際機場": "Kaohsiung Intl. Airport",
            "小港": "Siaogang",
            
            // MARK: - 橘線 Orange Line (西到東)
            "哈瑪星": "Hamasen",
            "鹽埕埔": "Yanchengpu",
            "前金": "Cianjin",
            // "美麗島" 已在上方紅線區段
            "信義國小": "Sinyi Ele. School",
            "文化中心": "Cultural Center",
            "五塊厝": "Wukuaicuo",
            "苓雅運動園區": "Lingya Sports Park",
            "衛武營": "Weiwuying",
            "鳳山西站": "Fongshan West",
            "鳳山": "Fongshan",
            "大東": "Dadong",
            "鳳山國中": "Fongshan Jr. High School",
            "大寮": "Daliao"
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
