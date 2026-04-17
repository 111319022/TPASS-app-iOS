import Foundation

final class TYMRTFareService {
    @MainActor static let shared = TYMRTFareService()

    private let taoyuanCitizenDiscount: Double = 0.7
    private static let targetTicketType = 1
    private static let targetFareClass = 1

    // key: sorted canonical station-name pair, value: fare
    private let fareLookup: [String: Int]

    private struct MetroFareRecord: Codable {
        let OriginStationName: MetroFareStationName
        let DestinationStationName: MetroFareStationName
        let Fares: [MetroFare]
    }

    private struct MetroFareStationName: Codable {
        let Zh_tw: String
    }

    private struct MetroFare: Codable {
        let TicketType: Int
        let FareClass: Int
        let Price: Int
    }

    private init() {
        let decoder = JSONDecoder()
        var fares: [String: Int] = [:]

        guard let url = Bundle.main.url(forResource: "TYMRT_Fare", withExtension: "json") else {
            print("TYMRTFareService: could not find TYMRT_Fare.json in bundle")
            self.fareLookup = [:]
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let records = try decoder.decode([MetroFareRecord].self, from: data)

            for record in records {
                guard let fare = record.Fares.first(where: {
                    $0.TicketType == Self.targetTicketType && $0.FareClass == Self.targetFareClass
                }) else {
                    continue
                }

                let origin = Self.canonicalStationName(record.OriginStationName.Zh_tw)
                let destination = Self.canonicalStationName(record.DestinationStationName.Zh_tw)
                guard !origin.isEmpty, !destination.isEmpty else { continue }

                let key = Self.pairKey(origin, destination)
                fares[key] = fare.Price
            }
        } catch {
            print("TYMRTFareService: failed to decode TYMRT_Fare.json - \(error)")
        }

        self.fareLookup = fares
    }

    // 取得票價 (支援雙向查詢)
    @MainActor
    func getFare(from start: String, to end: String) -> Int? {
        if start.isEmpty || end.isEmpty { return nil }

        let startZH = Self.canonicalStationName(TYMRTStationData.shared.normalizeStationNameToZH(start))
        let endZH = Self.canonicalStationName(TYMRTStationData.shared.normalizeStationNameToZH(end))
        if startZH.isEmpty || endZH.isEmpty { return nil }
        if startZH == endZH { return 0 }

        let key = Self.pairKey(startZH, endZH)
        return fareLookup[key]
    }

    // 取得桃園市民七折票價
    @MainActor
    func getCitizenFare(from start: String, to end: String) -> Int? {
        guard let fare = getFare(from: start, to: end) else { return nil }
        return Int(round(Double(fare) * taoyuanCitizenDiscount))
    }

    private static func canonicalStationName(_ name: String) -> String {
        let compact = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")

        if compact == "桃園高鐵站" || compact == "高鐵桃園站" {
            return "高鐵桃園站"
        }
        if compact == "台北車站" {
            return compact
        }
        if compact.hasSuffix("站") {
            return String(compact.dropLast())
        }
        return compact
    }

    private static func pairKey(_ lhs: String, _ rhs: String) -> String {
        lhs <= rhs ? "\(lhs)-\(rhs)" : "\(rhs)-\(lhs)"
    }
}