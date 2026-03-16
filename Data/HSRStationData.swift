import Foundation
import SwiftUI

class HSRStationData {
    @MainActor static let shared = HSRStationData()

    let line: MRTLine = MRTLine(
        id: "HSR",
        code: "HSR",
        name: "台灣高鐵",
        color: Color(hex: "#FF6600"),
        stations: [
            "南港", "台北", "板橋", "桃園", "新竹", "苗栗", "台中", "彰化", "雲林", "嘉義", "台南", "左營"
        ]
    )

    private let stationNameENByZH: [String: String] = [
        "南港": "Nangang",
        "台北": "Taipei",
        "板橋": "Banqiao",
        "桃園": "Taoyuan",
        "新竹": "Hsinchu",
        "苗栗": "Miaoli",
        "台中": "Taichung",
        "彰化": "Changhua",
        "雲林": "Yunlin",
        "嘉義": "Chiayi",
        "台南": "Tainan",
        "左營": "Zuoying"
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

    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        if stationNameENByZH.keys.contains(trimmed) { return trimmed }

        let normalized = normalizedLookupKey(trimmed)
        return stationNameZHByEN[normalized] ?? trimmed
    }

    func displayStationName(_ stationName: String, languageCode: String) -> String {
        if languageCode.starts(with: "en") {
            return stationNameENByZH[stationName] ?? stationName
        }
        return stationName
    }

    func displayLineName(_ lineName: String, languageCode: String) -> String {
        if languageCode.starts(with: "en") {
            return "Taiwan High Speed Rail"
        }
        return lineName
    }

    func availableStations(for region: TPASSRegion) -> [String] {
        _ = region
        return line.stations
    }
}