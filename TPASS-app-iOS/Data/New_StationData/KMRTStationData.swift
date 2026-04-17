import Foundation
import SwiftUI

final class KMRTStationData {
    @MainActor static let shared = KMRTStationData()

    let lines: [MRTLine]

    private let stationNameENByZH: [String: String]
    private let stationNameZHByEN: [String: String]

    private struct LineMetadata {
        let id: String
        let code: String
        let name: String
        let colorHex: String
    }

    private static let lineOrder: [String] = ["RED", "ORANGE"]

    private static let lineMetadataByCode: [String: LineMetadata] = [
        "RED": LineMetadata(id: "RED", code: "RED", name: "🔴紅線", colorHex: "#E31937"),
        "ORANGE": LineMetadata(id: "ORANGE", code: "ORANGE", name: "🟠橘線", colorHex: "#FF6B35")
    ]

    private init() {
        let decoder = JSONDecoder()

        guard let url = Bundle.main.url(forResource: "KMRT_StationData", withExtension: "json") else {
            print("KMRTStationData: could not find KMRT_StationData.json in bundle")
            self.lines = []
            self.stationNameENByZH = [:]
            self.stationNameZHByEN = [:]
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let records = try decoder.decode([TDXStationData].self, from: data)

            var groupedStationsByLine: [String: [TDXStationData]] = [:]
            var stationNameENByZH: [String: String] = [:]
            var stationNameZHByEN: [String: String] = [:]

            for record in records {
                guard let lineCode = Self.resolveLineCode(from: record.StationID) else { continue }

                groupedStationsByLine[lineCode, default: []].append(record)

                let zhName = record.StationName.Zh_tw.trimmingCharacters(in: .whitespacesAndNewlines)
                let enName = record.StationName.En.trimmingCharacters(in: .whitespacesAndNewlines)
                if !zhName.isEmpty, !enName.isEmpty {
                    stationNameENByZH[zhName] = enName
                    stationNameZHByEN[Self.normalizedLookupKey(enName)] = zhName
                }
                stationNameZHByEN[Self.normalizedLookupKey(zhName)] = zhName
            }

            var loadedLines: [MRTLine] = []
            for code in Self.lineOrder {
                guard let metadata = Self.lineMetadataByCode[code],
                      let recordsForLine = groupedStationsByLine[code],
                      !recordsForLine.isEmpty else {
                    continue
                }

                let stationNames = recordsForLine.map {
                    $0.StationName.Zh_tw.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                loadedLines.append(
                    MRTLine(
                        id: metadata.id,
                        code: metadata.code,
                        name: metadata.name,
                        color: Color(hex: metadata.colorHex),
                        stations: stationNames
                    )
                )
            }

            self.lines = loadedLines
            self.stationNameENByZH = stationNameENByZH
            self.stationNameZHByEN = stationNameZHByEN
        } catch {
            print("KMRTStationData: failed to load KMRT_StationData.json - \(error)")
            self.lines = []
            self.stationNameENByZH = [:]
            self.stationNameZHByEN = [:]
        }
    }

    private static func resolveLineCode(from stationID: String) -> String? {
        let upper = stationID.uppercased()
        if upper.hasPrefix("R") { return "RED" }
        if upper.hasPrefix("O") { return "ORANGE" }
        return nil
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
            if lineName.contains("紅") { return "🔴 Red Line" }
            if lineName.contains("橘") { return "🟠 Orange Line" }
        }
        return lineName
    }
}