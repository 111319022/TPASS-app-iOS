import Foundation

struct TripDTO: Codable {
    var id: String?
    var userId: String?
    var createdAt: Int64?      // Web 版存的是數字 (毫秒)
    var type: String?          // Web 版存的是字串 "bus", "mrt"
    var originalPrice: Int?
    var paidPrice: Int?
    var isTransfer: Bool?
    var isFree: Bool?
    var startStation: String?
    var endStation: String?
    var routeId: String?
    var note: String?
    
    // 對應資料庫欄位名稱
    enum CodingKeys: String, CodingKey {
        case userId
        case createdAt = "createdAt" // 對應 Web 的欄位名
        case type
        case originalPrice
        case paidPrice
        case isTransfer
        case isFree
        case startStation
        case endStation
        case routeId
        case note
    }
    
    // 🔥 核心轉換邏輯：把 DTO 轉成 UI 用的 Trip
    func toDomain(defaultUserId: String) -> Trip {
        // 1. 處理 ID
        let safeId = self.id ?? UUID().uuidString
        
        // 2. 處理時間 (毫秒 -> Date)
        let safeDate: Date
        if let ms = self.createdAt {
            safeDate = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        } else {
            safeDate = Date()
        }
        
        // 3. 處理交通類型 (字串 -> Enum)
        let safeType = TransportType(rawValue: self.type ?? "bus") ?? .bus
        
        // 4. 處理價格與優惠邏輯
        let safeOriginalPrice = self.originalPrice ?? 0
        let computedPaidPrice: Int
        
        if let p = self.paidPrice {
            computedPaidPrice = p
        } else {
            // 如果資料庫沒存 paidPrice，我們幫他算
            let isTrans = self.isTransfer ?? false
            let discount = isTrans ? (Identity.adult.transferDiscount) : 0
            computedPaidPrice = max(0, safeOriginalPrice - discount)
        }
        
        return Trip(
            id: safeId,
            userId: self.userId ?? defaultUserId, // 這裡補上 userId
            createdAt: safeDate,
            type: safeType,
            originalPrice: safeOriginalPrice,
            paidPrice: computedPaidPrice,
            isTransfer: self.isTransfer ?? false,
            isFree: self.isFree ?? false,
            startStation: self.startStation ?? "",
            endStation: self.endStation ?? "",
            routeId: self.routeId ?? "",
            note: self.note ?? "" // 缺 note 就給空字串，不會崩潰
        )
    }
}
