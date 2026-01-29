import Foundation

struct Trip: Identifiable, Hashable, Codable {
    let id: String
    let userId: String
    let createdAt: Date
    let type: TransportType
    let originalPrice: Int
    let paidPrice: Int
    let isTransfer: Bool
    let isFree: Bool
    let startStation: String
    let endStation: String
    let routeId: String
    let note: String
    
    // MARK: - 初始化
    init(id: String, userId: String, createdAt: Date, type: TransportType, originalPrice: Int, paidPrice: Int, isTransfer: Bool, isFree: Bool, startStation: String, endStation: String, routeId: String, note: String) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.type = type
        self.originalPrice = originalPrice
        self.paidPrice = paidPrice
        self.isTransfer = isTransfer
        self.isFree = isFree
        self.startStation = startStation
        self.endStation = endStation
        self.routeId = routeId
        self.note = note
    }
    
    // 輔助顯示
    var dateStr: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: createdAt)
    }
    
    var timeStr: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: createdAt)
    }
    
    var listDetails: String {
        let components = [
            routeId.isEmpty ? nil : routeId,
            (startStation.isEmpty || endStation.isEmpty) ? nil : "\(startStation) → \(endStation)"
        ]
        return components.compactMap { $0 }.joined(separator: " ")
    }
}
