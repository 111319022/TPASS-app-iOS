import Foundation
import SwiftData

// SwiftData schema versions to support lightweight migration.
enum TPASSSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Trip.self, FavoriteRoute.self, CommuterRoute.self, UserSettingsModel.self]
    }

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
        var cycleId: String?

        init(id: String, userId: String, createdAt: Date, type: TransportType, originalPrice: Int, paidPrice: Int, isTransfer: Bool, isFree: Bool, startStation: String, endStation: String, routeId: String, note: String, cycleId: String? = nil) {
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
            self.cycleId = cycleId
        }
    }

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

        init(id: UUID, type: TransportType, startStation: String, endStation: String, routeId: String, price: Int, isTransfer: Bool, isFree: Bool) {
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

    @Model
    final class CommuterRoute {
        @Attribute(.unique) var id: UUID
        var name: String
        var trips: [CommuterTripTemplate]

        init(id: UUID, name: String, trips: [CommuterTripTemplate]) {
            self.id = id
            self.name = name
            self.trips = trips
        }
    }

    @Model
    final class UserSettingsModel {
        @Attribute(.unique) var userId: String
        var identity: String
        var isCloudSyncEnabled: Bool
        var hasMigratedFromFirebase: Bool
        var hasMigratedFromLocal: Bool

        init(userId: String, identity: String, isCloudSyncEnabled: Bool, hasMigratedFromFirebase: Bool, hasMigratedFromLocal: Bool) {
            self.userId = userId
            self.identity = identity
            self.isCloudSyncEnabled = isCloudSyncEnabled
            self.hasMigratedFromFirebase = hasMigratedFromFirebase
            self.hasMigratedFromLocal = hasMigratedFromLocal
        }
    }
}

enum TPASSSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Trip.self, FavoriteRoute.self, CommuterRoute.self, UserSettingsModel.self]
    }
}

enum TPASSMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] {
        [TPASSSchemaV1.self, TPASSSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: TPASSSchemaV1.self, toVersion: TPASSSchemaV2.self)
        ]
    }
}
