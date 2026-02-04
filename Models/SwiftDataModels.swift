import Foundation
import SwiftData
import SwiftUI

// MARK: - 1. Trip（行程）@Model
@Model
final class Trip {
    @Attribute(.unique) var id: String
    var userId: String
    var createdAt: Date
    var type: TransportType
    var originalPrice: Int
    var paidPrice: Int
    var isTransfer: Bool
    var isFree: Bool
    var startStation: String
    var endStation: String
    var routeId: String
    var note: String
    var transferDiscountType: TransferDiscountType? // 🔥 新增：轉乘優惠類型
    var cycleId: String? // 🔥 新增：所屬週期（避免重疊週期混算）
    
    // 🔧 效能優化：共享 DateFormatter 避免重複建立
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    // 計算屬性（保持與舊版相容，讓 UI 不用改）
    @Transient var dateStr: String {
        Self.dateFormatter.string(from: createdAt)
    }
    
    @Transient var timeStr: String {
        Self.timeFormatter.string(from: createdAt)
    }
    
    @Transient var listDetails: String {
        let components = [
            routeId.isEmpty ? nil : routeId,
            (startStation.isEmpty || endStation.isEmpty) ? nil : "\(startStation) → \(endStation)"
        ]
        return components.compactMap { $0 }.joined(separator: " ")
    }
    
    init(id: String = UUID().uuidString, userId: String, createdAt: Date = Date(), type: TransportType, originalPrice: Int, paidPrice: Int, isTransfer: Bool, isFree: Bool, startStation: String, endStation: String, routeId: String, note: String, transferDiscountType: TransferDiscountType? = nil, cycleId: String? = nil) {
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
        self.transferDiscountType = transferDiscountType
        self.cycleId = cycleId
    }
}

// MARK: - 2. FavoriteRoute（常用路線）@Model
@Model
final class FavoriteRoute {
    @Attribute(.unique) var id: UUID
    var type: TransportType
    var startStation: String
    var endStation: String
    var routeId: String
    var price: Int
    var isTransfer: Bool
    var isFree: Bool
    
    @Transient var title: String {
        if type == .bus || type == .coach {
            return String(localized: "route") + " \(routeId) (\(type.displayNameKey))"
        } else {
            return "\(startStation) → \(endStation)"
        }
    }
    
    @Transient var displayTitle: String { title }

    init(id: UUID = UUID(), type: TransportType, startStation: String, endStation: String, routeId: String, price: Int, isTransfer: Bool, isFree: Bool) {
        self.id = id
        self.type = type
        self.startStation = startStation
        self.endStation = endStation
        self.routeId = routeId
        self.price = price
        self.isTransfer = isTransfer
        self.isFree = isFree
    }
}

// MARK: - 3. CommuterRoute（通勤路線）@Model
@Model
final class CommuterRoute {
    @Attribute(.unique) var id: UUID
    var name: String
    var trips: [CommuterTripTemplate]

    init(id: UUID = UUID(), name: String, trips: [CommuterTripTemplate]) {
        self.id = id
        self.name = name
        self.trips = trips
    }
    
    @Transient var tripCount: Int { trips.count }
}

// MARK: - CommuterTripTemplate（通勤行程模板）Struct
// 維持 Struct，因為它只是「模板資料」，不需要獨立存在資料庫
struct CommuterTripTemplate: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: TransportType
    var startStation: String
    var endStation: String
    var routeId: String
    var price: Int
    var isTransfer: Bool
    var isFree: Bool
    var note: String
    var timeSeconds: Int
    
    var displayTitle: String {
        if type == .bus || type == .coach {
            return String(localized: "route") + " \(routeId) (\(type.displayNameKey))"
        } else {
            return "\(startStation) → \(endStation)"
        }
    }
    
    var timeString: String {
        let h = timeSeconds / 3600
        let m = (timeSeconds % 3600) / 60
        let s = timeSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    func isSameTemplate(as other: CommuterTripTemplate) -> Bool {
        return type == other.type &&
        startStation == other.startStation &&
        endStation == other.endStation &&
        routeId == other.routeId &&
        price == other.price &&
        isTransfer == other.isTransfer &&
        isFree == other.isFree &&
        note == other.note &&
        timeSeconds == other.timeSeconds
    }
}

// MARK: - User Settings Model (SwiftData)
@Model
final class UserSettingsModel {
    @Attribute(.unique) var userId: String
    var identity: String // Identity.rawValue
    var isCloudSyncEnabled: Bool
    var hasMigratedFromFirebase: Bool
    var hasMigratedFromLocal: Bool
    
    init(userId: String, identity: String, isCloudSyncEnabled: Bool = true, hasMigratedFromFirebase: Bool = false, hasMigratedFromLocal: Bool = false) {
        self.userId = userId
        self.identity = identity
        self.isCloudSyncEnabled = isCloudSyncEnabled
        self.hasMigratedFromFirebase = hasMigratedFromFirebase
        self.hasMigratedFromLocal = hasMigratedFromLocal
    }
}
