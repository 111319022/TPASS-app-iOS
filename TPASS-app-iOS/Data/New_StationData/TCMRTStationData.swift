import Foundation
import SwiftUI

final class TCMRTStationData {
    @MainActor static let shared = TCMRTStationData()

    let lines: [MRTLine]

    private let stationNameENByZH: [String: String]
    private let stationNameZHByEN: [String: String]

    private init() {
        let decoder = JSONDecoder()

        guard let url = Bundle.main.url(forResource: "TCMRT_StationData", withExtension: "json") else {
            print("TCMRTStationData: could not find TCMRT_StationData.json in bundle")
            self.lines = [
                MRTLine(
                    id: "GREEN",
                    code: "GREEN",
                    name: "🟢綠線",
                    color: Color(hex: "#00AA4F"),
                    stations: []
                )
            ]
            self.stationNameENByZH = [:]
            self.stationNameZHByEN = [:]
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let records = try decoder.decode([TDXStationData].self, from: data)
            let sortedRecords = Self.sortedStations(records)

            var stations: [String] = []
            var stationNameENByZH: [String: String] = [:]
            var stationNameZHByEN: [String: String] = [:]

            for record in sortedRecords {
                let zhName = record.StationName.Zh_tw.trimmingCharacters(in: .whitespacesAndNewlines)
                let enName = record.StationName.En.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !zhName.isEmpty else { continue }
                stations.append(zhName)

                if !enName.isEmpty {
                    stationNameENByZH[zhName] = enName
                    stationNameZHByEN[Self.normalizedLookupKey(enName)] = zhName
                }
                stationNameZHByEN[Self.normalizedLookupKey(zhName)] = zhName
            }

            self.lines = [
                MRTLine(
                    id: "GREEN",
                    code: "GREEN",
                    name: "🟢綠線",
                    color: Color(hex: "#00AA4F"),
                    stations: stations
                )
            ]
            self.stationNameENByZH = stationNameENByZH
            self.stationNameZHByEN = stationNameZHByEN
        } catch {
            print("TCMRTStationData: failed to load TCMRT_StationData.json - \(error)")
            self.lines = [
                MRTLine(
                    id: "GREEN",
                    code: "GREEN",
                    name: "🟢綠線",
                    color: Color(hex: "#00AA4F"),
                    stations: []
                )
            ]
            self.stationNameENByZH = [:]
            self.stationNameZHByEN = [:]
        }
    }

    private struct StationIDKey {
        let number: Int
        let suffix: String
    }

    private static func parseStationIDKey(_ stationID: String) -> StationIDKey {
        let numberPart = stationID.filter { $0.isNumber }

        var foundNumber = false
        var suffixPart = ""
        for character in stationID {
            if character.isNumber {
                foundNumber = true
                continue
            }
            if foundNumber {
                suffixPart.append(character)
            }
        }

        return StationIDKey(number: Int(numberPart) ?? Int.max, suffix: suffixPart.uppercased())
    }

    private static func sortedStations(_ stations: [TDXStationData]) -> [TDXStationData] {
        stations.sorted { lhs, rhs in
            let left = parseStationIDKey(lhs.StationID)
            let right = parseStationIDKey(rhs.StationID)

            if left.number != right.number { return left.number < right.number }
            if left.suffix.isEmpty != right.suffix.isEmpty { return left.suffix.isEmpty }
            if left.suffix != right.suffix { return left.suffix < right.suffix }

            return lhs.StationID < rhs.StationID
        }
    }

    private static func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 將使用者輸入的站名（可能是英文）轉成中文標準名稱
    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }

        if stationNameENByZH.keys.contains(trimmed) { return trimmed }

        let normalized = Self.normalizedLookupKey(trimmed)
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