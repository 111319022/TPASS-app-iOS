import Foundation
import SwiftUI

struct MRTLine: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let color: Color
    let stations: [String]
}

final class StationData {
    @MainActor static let shared = StationData()

    let lines: [MRTLine]

    private let stationNameENByZH: [String: String]
    private let stationNameZHByEN: [String: String]

    private struct LineMetadata {
        let id: String
        let code: String
        let name: String
        let colorHex: String
    }

    private static let lineOrder: [String] = ["BL", "R", "G", "O", "BR", "Y"]

    private static let lineMetadataByCode: [String: LineMetadata] = [
        "BL": LineMetadata(id: "BL", code: "BL", name: "🔵板南線", colorHex: "#0070BD"),
        "R": LineMetadata(id: "R", code: "R", name: "🔴淡水信義線", colorHex: "#E3002C"),
        "G": LineMetadata(id: "G", code: "G", name: "🟢松山新店線", colorHex: "#008659"),
        "O": LineMetadata(id: "O", code: "O", name: "🟠中和新蘆線", colorHex: "#F8B61C"),
        "BR": LineMetadata(id: "BR", code: "BR", name: "🟤文湖線", colorHex: "#C48C31"),
        "Y": LineMetadata(id: "Y", code: "Y", name: "🟡環狀線", colorHex: "#FDBB2D")
    ]

    private static let lineNameENByZH: [String: String] = [
        "🔵板南線": "🔵 Blue line",
        "🔴淡水信義線": "🔴 Red Line",
        "🟢松山新店線": "🟢 Green Line",
        "🟠中和新蘆線": "🟠 Orange Line",
        "🟤文湖線": "🟤 Brown Line",
        "🟡環狀線": "🟡 Circular Line"
    ]

    private init() {
        let decoder = JSONDecoder()

        var groupedStationsByLine: [String: [TDXStationData]] = [:]
        var stationNameENByZH: [String: String] = [:]
        var stationNameZHByEN: [String: String] = [:]

        let resources = ["TPEMRT_StationData", "NTPCMRT_StationData"]
        for resource in resources {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
                print("StationData: could not find \(resource).json in bundle")
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let stations = try decoder.decode([TDXStationData].self, from: data)

                for station in stations {
                    let lineCode = Self.extractLineCode(from: station.StationID)
                    guard Self.lineMetadataByCode[lineCode] != nil else { continue }

                    groupedStationsByLine[lineCode, default: []].append(station)

                    let zhName = station.StationName.Zh_tw.trimmingCharacters(in: .whitespacesAndNewlines)
                    let enName = station.StationName.En.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !zhName.isEmpty, !enName.isEmpty {
                        stationNameENByZH[zhName] = enName
                        stationNameZHByEN[Self.normalizedLookupKey(enName)] = zhName
                    }
                }
            } catch {
                print("StationData: failed to load \(resource).json - \(error)")
            }
        }

        var loadedLines: [MRTLine] = []
        for code in Self.lineOrder {
            guard let metadata = Self.lineMetadataByCode[code],
                  let records = groupedStationsByLine[code],
                  !records.isEmpty else {
                continue
            }

            let sortedStations = Self.sortedStations(records)
            let stationNames = sortedStations.map { $0.StationName.Zh_tw.trimmingCharacters(in: .whitespacesAndNewlines) }

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
    }

    private struct StationIDKey {
        let prefix: String
        let number: Int
        let suffix: String
    }

    private static func extractLineCode(from stationID: String) -> String {
        String(stationID.prefix { !$0.isNumber }).uppercased()
    }

    private static func parseStationIDKey(_ stationID: String) -> StationIDKey {
        var prefix = ""
        var numberPart = ""
        var suffix = ""
        var readingNumber = false

        for character in stationID {
            if character.isNumber {
                readingNumber = true
                numberPart.append(character)
            } else if readingNumber {
                suffix.append(character)
            } else {
                prefix.append(character)
            }
        }

        return StationIDKey(
            prefix: prefix.uppercased(),
            number: Int(numberPart) ?? Int.max,
            suffix: suffix.uppercased()
        )
    }

    private static func sortedStations(_ stations: [TDXStationData]) -> [TDXStationData] {
        stations.sorted { lhs, rhs in
            let left = parseStationIDKey(lhs.StationID)
            let right = parseStationIDKey(rhs.StationID)

            if left.prefix != right.prefix { return left.prefix < right.prefix }
            if left.number != right.number { return left.number < right.number }

            if left.suffix.isEmpty != right.suffix.isEmpty {
                return left.suffix.isEmpty
            }
            if left.suffix != right.suffix { return left.suffix < right.suffix }

            return lhs.StationID < rhs.StationID
        }
    }
}

extension StationData {
    private static var defaultLanguageCode: String {
        if let stored = UserDefaults.standard.string(forKey: "AppLanguage"), !stored.isEmpty {
            return stored
        }
        return Locale.current.identifier
    }

    private static func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func displayLineName(_ zhLineName: String, languageCode: String? = nil) -> String {
        let lang = languageCode ?? Self.defaultLanguageCode
        guard lang.lowercased().hasPrefix("en") else { return zhLineName }
        return Self.lineNameENByZH[zhLineName] ?? zhLineName
    }

    func displayStationName(_ zhStationName: String, languageCode: String? = nil) -> String {
        let lang = languageCode ?? Self.defaultLanguageCode
        guard lang.lowercased().hasPrefix("en") else { return zhStationName }
        return stationNameENByZH[zhStationName] ?? zhStationName
    }

    /// 將使用者輸入（可能是英文）正規化回中文 key，避免 fareDB 查不到。
    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        if stationNameENByZH.keys.contains(trimmed) { return trimmed }
        let normalized = Self.normalizedLookupKey(trimmed)
        return stationNameZHByEN[normalized] ?? trimmed
    }
}