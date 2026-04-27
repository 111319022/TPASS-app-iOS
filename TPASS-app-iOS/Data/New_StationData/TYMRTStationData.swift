import Foundation
import SwiftUI

final class TYMRTStationData {
    @MainActor static let shared = TYMRTStationData()

    let line: MRTLine

    private let stationNameENByZH: [String: String]
    private let fareNameByLookupKey: [String: String]

    private init() {
        let decoder = JSONDecoder()

        guard let url = Bundle.main.url(forResource: "TYMRT_StationData", withExtension: "json") else {
            print("TYMRTStationData: could not find TYMRT_StationData.json in bundle")
            self.line = MRTLine(id: "A", code: "A", name: "🟣 機場捷運", color: Color("Colors/TransitLines/Line_TYMRT_A"), stations: [])
            self.stationNameENByZH = [:]
            self.fareNameByLookupKey = [:]
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let records = try decoder.decode([TDXStationData].self, from: data)
            let sortedRecords = Self.sortedStations(records)

            var stations: [String] = []
            var stationNameENByZH: [String: String] = [:]
            var fareNameByLookupKey: [String: String] = [:]

            for record in sortedRecords {
                let rawZH = record.StationName.Zh_tw.trimmingCharacters(in: .whitespacesAndNewlines)
                let rawEN = record.StationName.En.trimmingCharacters(in: .whitespacesAndNewlines)

                let zhName = Self.normalizeDisplayStationNameZH(rawZH)
                let enName = Self.normalizeDisplayStationNameEN(rawEN)
                let fareName = Self.normalizeFareStationNameZH(rawZH)

                guard !zhName.isEmpty else { continue }

                stations.append(zhName)

                if !enName.isEmpty {
                    stationNameENByZH[zhName] = enName
                    fareNameByLookupKey[Self.normalizedLookupKey(enName)] = fareName
                }

                // 相容舊資料與多種輸入格式
                fareNameByLookupKey[Self.normalizedLookupKey(zhName)] = fareName
                fareNameByLookupKey[Self.normalizedLookupKey(rawZH)] = fareName
                fareNameByLookupKey[Self.normalizedLookupKey(rawEN)] = fareName
                fareNameByLookupKey[Self.normalizedLookupKey(record.StationID)] = fareName

                let noStationSuffixZH = Self.removeTrailingStationSuffix(rawZH)
                if noStationSuffixZH != rawZH {
                    fareNameByLookupKey[Self.normalizedLookupKey(noStationSuffixZH)] = fareName
                }

                let noStationSuffixEN = Self.removeTrailingStationSuffixEN(rawEN)
                if noStationSuffixEN != rawEN {
                    fareNameByLookupKey[Self.normalizedLookupKey(noStationSuffixEN)] = fareName
                }
            }

            fareNameByLookupKey[Self.normalizedLookupKey("桃園高鐵站")] = "高鐵桃園站"
            fareNameByLookupKey[Self.normalizedLookupKey("高鐵桃園站")] = "高鐵桃園站"

            self.line = MRTLine(
                id: "A",
                code: "A",
                name: "🟣 機場捷運",
                color: Color("Colors/TransitLines/Line_TYMRT_A"),
                stations: stations
            )
            self.stationNameENByZH = stationNameENByZH
            self.fareNameByLookupKey = fareNameByLookupKey
        } catch {
            print("TYMRTStationData: failed to load TYMRT_StationData.json - \(error)")
            self.line = MRTLine(id: "A", code: "A", name: "🟣 機場捷運", color: Color("Colors/TransitLines/Line_TYMRT_A"), stations: [])
            self.stationNameENByZH = [:]
            self.fareNameByLookupKey = [:]
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

    private static func removeTrailingStationSuffix(_ value: String) -> String {
        guard value.hasSuffix("站") else { return value }
        return String(value.dropLast())
    }

    private static func normalizeFareStationNameZH(_ value: String) -> String {
        // 與既有票價 key 相容：A1/A18 的 key 仍使用「台北車站 / 高鐵桃園站」
        if value == "台北車站" || value == "高鐵桃園站" || value == "桃園高鐵站" {
            if value == "桃園高鐵站" { return "高鐵桃園站" }
            return value
        }
        return removeTrailingStationSuffix(value)
    }

    private static func removeTrailingStationSuffixEN(_ value: String) -> String {
        guard value.lowercased().hasSuffix(" station") else { return value }
        return String(value.dropLast(" station".count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeDisplayStationNameZH(_ value: String) -> String {
        if value == "台北車站" { return value }
        if value == "高鐵桃園站" || value == "桃園高鐵站" { return "桃園高鐵站" }
        return removeTrailingStationSuffix(value)
    }

    private static func normalizeDisplayStationNameEN(_ value: String) -> String {
        removeTrailingStationSuffixEN(value)
    }

    private static func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 將使用者輸入的站名 (可能是英文或代號) 轉成中文標準名稱
    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }

        let normalized = Self.normalizedLookupKey(trimmed)
        if let mappedFareName = fareNameByLookupKey[normalized] {
            return mappedFareName
        }

        if stationNameENByZH.keys.contains(trimmed) {
            return Self.normalizeFareStationNameZH(trimmed)
        }

        return trimmed
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
            return line.stations
        case .north:
            return line.stations
        case .taoZhuZhu:
            guard let startIndex = line.stations.firstIndex(of: "體育大學"),
                  let endIndex = line.stations.firstIndex(of: "老街溪") else {
                return []
            }
            return Array(line.stations[startIndex...endIndex])
        case .taoZhuZhuMiao:
            guard let startIndex = line.stations.firstIndex(of: "體育大學"),
                  let endIndex = line.stations.firstIndex(of: "老街溪") else {
                return []
            }
            return Array(line.stations[startIndex...endIndex])
        case .beiYiMegaPASS:
            return line.stations
        default:
            return []
        }
    }
}