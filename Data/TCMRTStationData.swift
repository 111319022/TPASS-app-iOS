import Foundation
import SwiftUI

class TCMRTStationData {
    static let shared = TCMRTStationData()
    
    // 台中捷運線路定義
    let lines: [MRTLine] = [
        MRTLine(
            id: "RED",
            code: "RED",
            name: "🔴紅線",
            color: Color(hex: "#E31937"), // 台中捷運紅線
            stations: [
                "北屯總站", "舊社", "松竹", "四民主義", "北屯國小", "陸光", "文心北路", "大坑",
                "文心中清交", "文心中華", "新時代", "文心中港", "南屯", "豐樂公園", "東興", "南岡",
                "文心南路", "烏日高鐵", "九德"
            ]
        ),
        MRTLine(
            id: "GREEN",
            code: "GREEN",
            name: "🟢綠線",
            color: Color(hex: "#00AA4F"), // 台中捷運綠線
            stations: [
                "高鐵台中站", "烏日", "大慶", "松子路", "機場", "中平", "精科", "龍井",
                "水安宮", "沙鹿", "梧棲國小", "靜浦"
            ]
        )
    ]
    
    // 英文站名對照
    private let stationNameENByZH: [String: String] = [
        // 紅線
        "北屯總站": "Beitun Main Station",
        "舊社": "Jiushe",
        "松竹": "Songzhu",
        "四民主義": "Four People's Principles",
        "北屯國小": "Beitun Elementary",
        "陸光": "Luguang",
        "文心北路": "Wenxin North Rd.",
        "大坑": "Dakeng",
        "文心中清交": "Wenxin Zhongqing Jiao",
        "文心中華": "Wenxin Zhonghua",
        "新時代": "New Era",
        "文心中港": "Wenxin Zhonggang",
        "南屯": "Nantun",
        "豐樂公園": "Fongle Park",
        "東興": "Dongxing",
        "南岡": "Nangang",
        "文心南路": "Wenxin South Rd.",
        "烏日高鐵": "Wuri High Speed Rail",
        "九德": "Jiude",
        
        // 綠線
        "高鐵台中站": "Taichung HSR Station",
        "烏日": "Wuri",
        "大慶": "Daqing",
        "松子路": "Songzi Rd.",
        "機場": "Airport",
        "中平": "Zhongping",
        "精科": "Jingke",
        "龍井": "Longjing",
        "水安宮": "Shui'an Temple",
        "沙鹿": "Shalu",
        "梧棲國小": "Wuqi Elementary",
        "靜浦": "Jingpu"
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
            if lineName.contains("綠") { return "🟢 Green Line" }
        }
        return lineName
    }
}
