import Foundation
import SwiftUI

class TCMRTStationData {
    @MainActor static let shared = TCMRTStationData()
    
    // 台中捷運線路定義 (目前僅有一條綠線)
    let lines: [MRTLine] = [
        MRTLine(
            id: "GREEN",
            code: "GREEN",
            name: "🟢綠線",
            color: Color(hex: "#00AA4F"), // 台中捷運綠線標準色
            stations: [
                "北屯總站", "舊社", "松竹", "四維國小", "文心崇德", "文心中清",
                "文華高中", "文心櫻花", "市政府", "水安宮", "文心森林公園", "南屯",
                "豐樂公園", "大慶", "九張犁", "九德", "烏日", "高鐵臺中站"
            ]
        )
    ]
    
    // 英文站名對照表
    private let stationNameENByZH: [String: String] = [
        "九張犁": "Jiuzhangli",
        "九德": "Jiude",
        "北屯總站": "Beitun Main Station",
        "南屯": "Nantun",
        "四維國小": "Sihwei Elementary School",
        "大慶": "Daqing",
        "市政府": "Taichung City Hall",
        "文心中清": "Wenxin Zhongqing",
        "文心崇德": "Wenxin Chongde",
        "文心森林公園": "Wenxin Forest Park",
        "文心櫻花": "Wenxin Yinghua",
        "文華高中": "Wenhua Senior High School",
        "松竹": "Songzhu",
        "水安宮": "Shui-an Temple",
        "烏日": "Wuri",
        "舊社": "Jiushe",
        "豐樂公園": "Feng-le Park",
        "高鐵臺中站": "HSR Taichung Station"
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
            if lineName.contains("綠") { return "🟢 Green Line" }
        }
        return lineName
    }
}
