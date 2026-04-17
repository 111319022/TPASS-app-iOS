import Foundation

final class LRTStationData {
    @MainActor static let shared = LRTStationData()

    let lines: [LRTLine]

    private let stationNameENByZH: [String: String]
    private let stationNameZHByEN: [String: String]

    private struct LineResource {
        let id: String
        let code: String
        let name: String
        let colorHex: String
        let fileName: String
    }

    private init() {
        let lineResources: [LineResource] = [
            LineResource(id: "KLRT", code: "KLRT", name: "🟢高雄輕軌", colorHex: "#4F9D4A", fileName: "KLRT_StationData"),
            LineResource(id: "NTDLRT", code: "NTDLRT", name: "🔴淡海輕軌", colorHex: "#F3A07A", fileName: "NTDLRT_StationData"),
            LineResource(id: "NTALRT", code: "NTALRT", name: "🟤安坑輕軌", colorHex: "#CFA052", fileName: "NTALRT_StationData")
        ]

        var loadedLines: [LRTLine] = []
        var stationNameENByZH: [String: String] = [:]
        var stationNameZHByEN: [String: String] = [:]
        let decoder = JSONDecoder()

        for resource in lineResources {
            guard let url = Bundle.main.url(forResource: resource.fileName, withExtension: "json") else {
                print("LRTStationData: could not find \(resource.fileName).json in bundle")
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let stationDataList = try decoder.decode([TDXStationData].self, from: data)
                let stations = stationDataList.map { stationData in
                    let station = LRTStation(
                        stationID: stationData.StationID,
                        nameZH: stationData.StationName.Zh_tw,
                        nameEN: stationData.StationName.En,
                        longitude: stationData.StationPosition.PositionLon,
                        latitude: stationData.StationPosition.PositionLat
                    )

                    let zhName = station.nameZH.trimmingCharacters(in: .whitespacesAndNewlines)
                    let enName = station.nameEN.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !zhName.isEmpty, !enName.isEmpty {
                        stationNameENByZH[zhName] = enName
                        stationNameZHByEN[Self.normalizedLookupKey(enName)] = zhName
                    }

                    return station
                }

                loadedLines.append(
                    LRTLine(
                        id: resource.id,
                        code: resource.code,
                        name: resource.name,
                        colorHex: resource.colorHex,
                        stations: stations
                    )
                )
            } catch {
                print("LRTStationData: failed to load \(resource.fileName).json - \(error)")
            }
        }

        self.lines = loadedLines
        self.stationNameENByZH = stationNameENByZH
        self.stationNameZHByEN = stationNameZHByEN
    }

    private static func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func normalizeStationNameToZH(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }

        if stationNameENByZH.keys.contains(trimmed) {
            return trimmed
        }

        let normalized = Self.normalizedLookupKey(trimmed)
        return stationNameZHByEN[normalized] ?? trimmed
    }

    func displayStationName(_ stationName: String, languageCode: String) -> String {
        let trimmed = stationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if languageCode.lowercased().hasPrefix("en") {
            if let englishName = stationNameENByZH[trimmed] {
                return englishName
            }

            let normalized = Self.normalizedLookupKey(trimmed)
            if let zhName = stationNameZHByEN[normalized] {
                return stationNameENByZH[zhName] ?? zhName
            }

            return trimmed
        }

        return normalizeStationNameToZH(trimmed)
    }

    func displayLineName(_ lineName: String, languageCode: String) -> String {
        guard languageCode.lowercased().hasPrefix("en") else { return lineName }

        if lineName.contains("高雄輕軌") {
            return "🟢 Kaohsiung Light Rail"
        }
        if lineName.contains("淡海輕軌") {
            return "🔴 Danhai Light Rail"
        }
        if lineName.contains("安坑輕軌") {
            return "🟤 Ankang Light Rail"
        }

        return lineName
    }

    func availableLines(for region: TPASSRegion) -> [LRTLine] {
        switch region {
        case .flexible:
            return lines
        case .south, .kaohsiung:
            return lines.filter { $0.code == "KLRT" }
        case .north, .beiYiMegaPASS, .beiYi:
            return lines.filter { $0.code == "NTDLRT" || $0.code == "NTALRT" }
        default:
            return []
        }
    }
}