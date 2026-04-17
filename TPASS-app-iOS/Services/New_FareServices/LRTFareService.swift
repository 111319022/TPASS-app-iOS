import Foundation

final class LRTFareService {
    @MainActor static let shared = LRTFareService()

    private let targetTicketType = 1
    private let targetFareClass = 1

    // lineCode -> (sorted stationID pair key -> fare)
    private let fareLookupByLine: [String: [String: Int]]

    private struct FareResource {
        let lineCode: String
        let fileName: String
    }

    private struct TDXLRTFareRecord: Codable {
        let OriginStationID: String
        let DestinationStationID: String
        let Fares: [TDXFare]
    }

    private struct TDXFare: Codable {
        let TicketType: Int
        let FareClass: Int
        let Price: Int
    }

    private init() {
        let targetTicketType = self.targetTicketType
        let targetFareClass = self.targetFareClass

        let resources: [FareResource] = [
            FareResource(lineCode: "KLRT", fileName: "KLRT_Fare"),
            FareResource(lineCode: "NTDLRT", fileName: "NTDLRT_Fare"),
            FareResource(lineCode: "NTALRT", fileName: "NTALRT_Fare")
        ]

        var lineLookups: [String: [String: Int]] = [:]
        let decoder = JSONDecoder()

        for resource in resources {
            guard let url = Bundle.main.url(forResource: resource.fileName, withExtension: "json") else {
                print("LRTFareService: could not find \(resource.fileName).json in bundle")
                continue
            }

            do {
                let data = try Data(contentsOf: url)
                let records = try decoder.decode([TDXLRTFareRecord].self, from: data)

                var fareLookup: [String: Int] = [:]
                for record in records {
                    if record.OriginStationID == record.DestinationStationID {
                        continue
                    }

                    guard let fare = record.Fares.first(where: {
                        $0.TicketType == targetTicketType && $0.FareClass == targetFareClass
                    }) else {
                        continue
                    }

                    let pairKey = Self.pairKey(record.OriginStationID, record.DestinationStationID)
                    fareLookup[pairKey] = fare.Price
                }

                lineLookups[resource.lineCode] = fareLookup
            } catch {
                print("LRTFareService: failed to decode \(resource.fileName).json - \(error)")
            }
        }

        self.fareLookupByLine = lineLookups
    }

    @MainActor
    func getFare(lineCode: String, from startStation: String, to endStation: String) -> Int? {
        let startZH = LRTStationData.shared.normalizeStationNameToZH(startStation)
        let endZH = LRTStationData.shared.normalizeStationNameToZH(endStation)

        if startZH.isEmpty || endZH.isEmpty {
            return nil
        }

        if startZH == endZH {
            return 0
        }

        guard let line = LRTStationData.shared.lines.first(where: { $0.code == lineCode }) else {
            return nil
        }

        guard let startID = line.stations.first(where: { $0.nameZH == startZH })?.stationID,
              let endID = line.stations.first(where: { $0.nameZH == endZH })?.stationID else {
            return nil
        }

        let key = Self.pairKey(startID, endID)
        return fareLookupByLine[lineCode]?[key]
    }

    private static func pairKey(_ lhs: String, _ rhs: String) -> String {
        lhs <= rhs ? "\(lhs)|\(rhs)" : "\(rhs)|\(lhs)"
    }
}
