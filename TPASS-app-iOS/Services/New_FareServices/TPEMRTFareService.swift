import Foundation

final class TPEMRTFareService {
    @MainActor static let shared = TPEMRTFareService()

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
        let resources = ["TPEMRT_Fare", "NTPCMRT_Fare"]

        var fares: [String: Int] = [:]
        for resource in resources {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
                print("TPEMRTFareService: could not find \(resource).json in bundle")
                continue
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
                print("TPEMRTFareService: failed to decode \(resource).json - \(error)")
            }
        }

        self.fareLookup = fares
    }

    // 對應 Web 版的 getOfficialFare
    @MainActor
    func getFare(from start: String, to end: String) -> Int? {
        if start.isEmpty || end.isEmpty { return nil }

        let startZH = Self.canonicalStationName(StationData.shared.normalizeStationNameToZH(start))
        let endZH = Self.canonicalStationName(StationData.shared.normalizeStationNameToZH(end))
        if startZH.isEmpty || endZH.isEmpty { return nil }
        if startZH == endZH { return 0 }

        let key = Self.pairKey(startZH, endZH)
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