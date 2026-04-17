import Foundation

final class TCMRTFareService {
    @MainActor static let shared = TCMRTFareService()

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

        guard let url = Bundle.main.url(forResource: "TCMRT_Fare", withExtension: "json") else {
            print("TCMRTFareService: could not find TCMRT_Fare.json in bundle")
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
            print("TCMRTFareService: failed to decode TCMRT_Fare.json - \(error)")
        }

        self.fareLookup = fares
    }

    /// 取得台中捷運票價
    @MainActor
    func getFare(from startStation: String, to endStation: String) -> Int? {
        let start = Self.canonicalStationName(TCMRTStationData.shared.normalizeStationNameToZH(startStation))
        let end = Self.canonicalStationName(TCMRTStationData.shared.normalizeStationNameToZH(endStation))

        if start.isEmpty || end.isEmpty { return nil }
        if start == end { return 0 }

        let key = Self.pairKey(start, end)
        return fareLookup[key]
    }

    private static func canonicalStationName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }

    private static func pairKey(_ lhs: String, _ rhs: String) -> String {
        lhs <= rhs ? "\(lhs)-\(rhs)" : "\(rhs)-\(lhs)"
    }
}