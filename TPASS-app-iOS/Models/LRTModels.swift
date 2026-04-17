import Foundation

struct TDXStationData: Codable {
    let StationID: String
    let StationName: TDXStationName
    let StationPosition: TDXStationPosition
}

struct TDXStationName: Codable {
    let Zh_tw: String
    let En: String
}

struct TDXStationPosition: Codable {
    let PositionLon: Double
    let PositionLat: Double
}

struct LRTStation: Identifiable {
    let stationID: String
    let nameZH: String
    let nameEN: String
    let longitude: Double
    let latitude: Double

    var id: String { stationID }
}

struct LRTLine: Identifiable {
    let id: String
    let code: String
    let name: String
    let colorHex: String
    let stations: [LRTStation]
}