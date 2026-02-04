import SwiftUI
import SwiftData

struct MigrationManager {
    // ⬇️ 定義「舊版」資料結構，專門用來讀取 UserDefaults 的 JSON
    private struct LegacyTrip: Codable {
        var id: String
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
    }
    
    private struct LegacyFavorite: Codable {
        var id: UUID
        var type: TransportType
        var startStation: String
        var endStation: String
        var routeId: String
        var price: Int
        var isTransfer: Bool
        var isFree: Bool
    }
    
    private struct LegacyCommuter: Codable {
        var id: UUID
        var name: String
        var trips: [CommuterTripTemplate]
    }

    @MainActor
    static func migrateIfNeeded(modelContext: ModelContext) {
        // 1. 檢查是否已經搬過家
        let hasMigrated = UserDefaults.standard.bool(forKey: "did_migrate_to_swiftdata_v3")
        if hasMigrated {
            print("✅ [Migration] 已完成遷移，跳過")
            return
        }

        print("🚀 [Migration] 開始執行 SwiftData 資料遷移...")
        
        var migratedTripsCount = 0
        var migratedFavoritesCount = 0
        var migratedCommuterCount = 0
        
        // 2. 讀取與轉換：行程 (Trips)
        if let data = UserDefaults.standard.data(forKey: "saved_trips_v1"),
           let oldTrips = try? JSONDecoder().decode([LegacyTrip].self, from: data) {
            
            for old in oldTrips {
                // 檢查是否已存在 (避免重複插入)
                let tripId = old.id
                let descriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.id == tripId })
                if let count = try? modelContext.fetchCount(descriptor), count > 0 { continue }

                let newTrip = Trip(
                    id: old.id,
                    userId: old.userId,
                    createdAt: old.createdAt,
                    type: old.type,
                    originalPrice: old.originalPrice,
                    paidPrice: old.paidPrice,
                    isTransfer: old.isTransfer,
                    isFree: old.isFree,
                    startStation: old.startStation,
                    endStation: old.endStation,
                    routeId: old.routeId,
                    note: old.note
                )
                modelContext.insert(newTrip)
                migratedTripsCount += 1
            }
            print("✅ [Migration] 成功遷移 \(migratedTripsCount) 筆行程")
        }
        
        // 3. 讀取與轉換：常用路線 (Favorites)
        if let data = UserDefaults.standard.data(forKey: "saved_favorites_v1"),
           let oldFavs = try? JSONDecoder().decode([LegacyFavorite].self, from: data) {
            
            for old in oldFavs {
                // 檢查是否已存在
                let favId = old.id
                let descriptor = FetchDescriptor<FavoriteRoute>(predicate: #Predicate { $0.id == favId })
                if let count = try? modelContext.fetchCount(descriptor), count > 0 { continue }
                
                let newFav = FavoriteRoute(
                    id: old.id,
                    type: old.type,
                    startStation: old.startStation,
                    endStation: old.endStation,
                    routeId: old.routeId,
                    price: old.price,
                    isTransfer: old.isTransfer,
                    isFree: old.isFree
                )
                modelContext.insert(newFav)
                migratedFavoritesCount += 1
            }
            print("✅ [Migration] 成功遷移 \(migratedFavoritesCount) 筆常用路線")
        }
        
        // 4. 讀取與轉換：通勤路線 (CommuterRoutes)
        if let data = UserDefaults.standard.data(forKey: "saved_commuter_routes_v1"),
           let oldRoutes = try? JSONDecoder().decode([LegacyCommuter].self, from: data) {
            
            for old in oldRoutes {
                // 檢查是否已存在
                let routeId = old.id
                let descriptor = FetchDescriptor<CommuterRoute>(predicate: #Predicate { $0.id == routeId })
                if let count = try? modelContext.fetchCount(descriptor), count > 0 { continue }
                
                let newRoute = CommuterRoute(id: old.id, name: old.name, trips: old.trips)
                modelContext.insert(newRoute)
                migratedCommuterCount += 1
            }
            print("✅ [Migration] 成功遷移 \(migratedCommuterCount) 筆通勤路線")
        }
        
        // 5. 儲存並標記完成
        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: "did_migrate_to_swiftdata_v3")
            print("🎉 [Migration] 資料遷移完成！共遷移 \(migratedTripsCount) 行程、\(migratedFavoritesCount) 常用路線、\(migratedCommuterCount) 通勤路線")
        } catch {
            print("❌ [Migration] 遷移儲存失敗: \(error)")
            // 🔧 不標記為完成，下次啟動時會重試
            // 但為了避免重複插入，已經有檢查邏輯
        }
    }
}
