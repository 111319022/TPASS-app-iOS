import Foundation
import SwiftData

// MARK: - Trip Model (SwiftData)
@Model
final class TripModel {
    var id: String
    var userId: String
    var createdAt: Date
    var typeRaw: String // TransportType.rawValue
    var originalPrice: Int
    var paidPrice: Int
    var isTransfer: Bool
    var isFree: Bool
    var startStation: String
    var endStation: String
    var routeId: String
    var note: String
    
    init(id: String, userId: String, createdAt: Date, typeRaw: String, originalPrice: Int, paidPrice: Int, isTransfer: Bool, isFree: Bool, startStation: String, endStation: String, routeId: String, note: String) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.typeRaw = typeRaw
        self.originalPrice = originalPrice
        self.paidPrice = paidPrice
        self.isTransfer = isTransfer
        self.isFree = isFree
        self.startStation = startStation
        self.endStation = endStation
        self.routeId = routeId
        self.note = note
    }
    
    // 轉換為 Trip (方便顯示)
    func toTrip() -> Trip? {
        guard let type = TransportType(rawValue: typeRaw) else { return nil }
        return Trip(
            id: id,
            userId: userId,
            createdAt: createdAt,
            type: type,
            originalPrice: originalPrice,
            paidPrice: paidPrice,
            isTransfer: isTransfer,
            isFree: isFree,
            startStation: startStation,
            endStation: endStation,
            routeId: routeId,
            note: note
        )
    }
    
    // 從 Trip 創建
    static func from(_ trip: Trip) -> TripModel {
        return TripModel(
            id: trip.id,
            userId: trip.userId,
            createdAt: trip.createdAt,
            typeRaw: trip.type.rawValue,
            originalPrice: trip.originalPrice,
            paidPrice: trip.paidPrice,
            isTransfer: trip.isTransfer,
            isFree: trip.isFree,
            startStation: trip.startStation,
            endStation: trip.endStation,
            routeId: trip.routeId,
            note: trip.note
        )
    }
}

// MARK: - FavoriteRoute Model (SwiftData)
@Model
final class FavoriteRouteModel {
    var id: String
    var typeRaw: String
    var startStation: String
    var endStation: String
    var routeId: String
    var price: Int
    var isTransfer: Bool
    var isFree: Bool
    
    init(id: String, typeRaw: String, startStation: String, endStation: String, routeId: String, price: Int, isTransfer: Bool, isFree: Bool) {
        self.id = id
        self.typeRaw = typeRaw
        self.startStation = startStation
        self.endStation = endStation
        self.routeId = routeId
        self.price = price
        self.isTransfer = isTransfer
        self.isFree = isFree
    }
    
    // 轉換為 FavoriteRoute
    func toFavoriteRoute() -> FavoriteRoute? {
        guard let type = TransportType(rawValue: typeRaw),
              let uuid = UUID(uuidString: id) else { return nil }
        return FavoriteRoute(
            id: uuid,
            type: type,
            startStation: startStation,
            endStation: endStation,
            routeId: routeId,
            price: price,
            isTransfer: isTransfer,
            isFree: isFree
        )
    }
    
    // 從 FavoriteRoute 創建
    static func from(_ fav: FavoriteRoute) -> FavoriteRouteModel {
        return FavoriteRouteModel(
            id: fav.id.uuidString,
            typeRaw: fav.type.rawValue,
            startStation: fav.startStation,
            endStation: fav.endStation,
            routeId: fav.routeId,
            price: fav.price,
            isTransfer: fav.isTransfer,
            isFree: fav.isFree
        )
    }
}

// MARK: - User Settings Model (SwiftData)
@Model
final class UserSettingsModel {
    var userId: String
    var identity: String // Identity.rawValue
    var isCloudSyncEnabled: Bool // 🔥 用戶是否開啟 iCloud 同步
    var hasMigratedFromFirebase: Bool // 是否已從 Firebase 遷移
    var hasMigratedFromLocal: Bool // 是否已從本地遷移
    
    init(userId: String, identity: String, isCloudSyncEnabled: Bool = true, hasMigratedFromFirebase: Bool = false, hasMigratedFromLocal: Bool = false) {
        self.userId = userId
        self.identity = identity
        self.isCloudSyncEnabled = isCloudSyncEnabled
        self.hasMigratedFromFirebase = hasMigratedFromFirebase
        self.hasMigratedFromLocal = hasMigratedFromLocal
    }
}
