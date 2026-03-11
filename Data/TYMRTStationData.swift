import Foundation
import SwiftUI

class TYMRTStationData {
    @MainActor static let shared = TYMRTStationData()
    
    // 機捷線路定義
    let line: MRTLine = MRTLine(
        id: "A",
        code: "A",
        name: "🟣 機場捷運",
        color: Color(hex: "#8246AF"), // 機捷代表色
        stations: [
            "台北車站", "三重", "新北產業園區", "新莊副都心", "泰山", "泰山貴和", "體育大學", 
            "長庚醫院", "林口", "山鼻", "坑口", "機場第一航廈", "機場第二航廈", "機場旅館", 
            "大園", "橫山", "領航", "高鐵桃園站", "桃園體育園區", "興南", "環北", "老街溪"
        ]
    )
    
    // 英文站名對照 (用於將英文輸入轉回中文 Key 以便查票價)
    private let stationNameENByZH: [String: String] = [
        "台北車站": "Taipei Main Station",
        "三重": "Sanchong",
        "新北產業園區": "New Taipei Industrial Park",
        "新莊副都心": "Xinzhuang Fuduxin",
        "泰山": "Taishan",
        "泰山貴和": "Taishan Guihe",
        "體育大學": "NTSU.",
        "長庚醫院": "Chang Gung Memorial Hospital",
        "林口": "Linkou",
        "山鼻": "Shanbi",
        "坑口": "Kengkou",
        "機場第一航廈": "Airport T1",
        "機場第二航廈": "Airport T2",
        "機場旅館": "Airport Hotel",
        "大園": "Dayuan",
        "橫山": "Hengshan",
        "領航": "Linghang",
        "高鐵桃園站": "Taoyuan HSR Sta.",
        "桃園體育園區": "Taoyuan Sports Park",
        "興南": "Xingnan",
        "環北": "Huanbei",
        "老街溪": "Laojie River"
    ]
    
    private lazy var stationNameZHByEN: [String: String] = {
        var result: [String: String] = [:]
        for (zh, en) in stationNameENByZH {
            result[normalizedLookupKey(en)] = zh
            // 支援代號輸入 (例如輸入 "A1" 也能辨識為 "台北車站")
            if let index = line.stations.firstIndex(of: zh) {
                let code = "A\(index + 1)"
                result[normalizedLookupKey(code)] = zh
                // 特例處理 A14a (機場旅館)
                if zh == "機場旅館" { result["a14a"] = zh }
            }
        }
        return result
    }()
    
    private func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    /// 將使用者輸入的站名 (可能是英文或代號) 轉成中文標準名稱
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
            return "Airport MRT"
        }
        return lineName
    }
    
    /// 根據 TPASS 方案返回可用的機場捷運站點
    func availableStations(for region: TPASSRegion) -> [String] {
        switch region {
        case .flexible:
            // 彈性週期：全線可用
            return line.stations
        case .north:
            // 基北北桃：全線可用（台北車站-老街溪）
            return line.stations
        case .taoZhuZhu:
            // 桃竹竹：只能使用體育大學-老街溪
            guard let startIndex = line.stations.firstIndex(of: "體育大學"),
                  let endIndex = line.stations.firstIndex(of: "老街溪") else {
                return []
            }
            return Array(line.stations[startIndex...endIndex])
        case .taoZhuZhuMiao:
            // 桃竹竹苗：同桃竹竹
            guard let startIndex = line.stations.firstIndex(of: "體育大學"),
                  let endIndex = line.stations.firstIndex(of: "老街溪") else {
                return []
            }
            return Array(line.stations[startIndex...endIndex])
        case .beiYiMegaPASS:
            // 北宜跨城際及雙北：全線可用
            return line.stations
        default:
            // 其他方案不支援機場捷運
            return []
        }
    }
}
