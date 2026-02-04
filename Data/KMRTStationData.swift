import Foundation
import SwiftUI

class KMRTStationData {
    static let shared = KMRTStationData()
    
    // 高雄捷運線路定義
    let lines: [MRTLine] = [
        MRTLine(
            id: "RED",
            code: "RED",
            name: "🔴紅線",
            color: Color(hex: "#E31937"), // 高雄捷運紅線
            stations: [
                "南港", "小港", "獅甲", "衛武營", "美麗島", "中央公園", "高雄車站", "高雄站",
                "信義國小", "六合", "五塊厝", "巨蛋", "生態公園", "左營站", "文化中心", "體育場",
                "橄欖球場"
            ]
        ),
        MRTLine(
            id: "ORANGE",
            code: "ORANGE",
            name: "🟠橘線",
            color: Color(hex: "#FF6B35"), // 高雄捷運橘線
            stations: [
                "西子灣", "英國領事館", "高雄文化中心", "五塊厝", "技擊館", "夢時代", "旅遊服務中心",
                "科工館", "軟體園區", "民族", "劉家港", "鳳山站", "鳳山老街", "鳳東", "鳯北"
            ]
        )
    ]
    
    // 英文站名對照
    private let stationNameENByZH: [String: String] = [
        // 紅線
        "南港": "Nangang",
        "小港": "Xiaogang",
        "獅甲": "Shigia",
        "衛武營": "Weiuying",
        "美麗島": "Formosa Boulevard",
        "中央公園": "Central Park",
        "高雄車站": "Kaohsiung Main Station",
        "高雄站": "Kaohsiung Station",
        "信義國小": "Xinyi Elementary",
        "六合": "Liuhe",
        "五塊厝": "Wukuaicuo",
        "巨蛋": "Arena",
        "生態公園": "Ecology Park",
        "左營站": "Zuoying Station",
        "文化中心": "Cultural Center",
        "體育場": "Sports Arena",
        "橄欖球場": "Rugby Stadium",
        
        // 橘線
        "西子灣": "Sizihwan",
        "英國領事館": "British Consulate",
        "高雄文化中心": "Kaohsiung Cultural Center",
        "技擊館": "Martial Arts Arena",
        "夢時代": "Dream Mall",
        "旅遊服務中心": "Tourist Service Center",
        "科工館": "Science Museum",
        "軟體園區": "Software Park",
        "民族": "Minzu",
        "劉家港": "Liujiag",
        "鳳山站": "Fengshan Station",
        "鳳山老街": "Fengshan Old Street",
        "鳳東": "Fengdong",
        "鳯北": "Fengnorth",
        
    ]
    
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
            if lineName.contains("輕軌") { return "🟡 LRT" }
        }
        return lineName
    }
}
