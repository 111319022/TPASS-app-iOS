import Foundation
import Combine
import CloudKit
import SwiftUI

// MARK: - Array 擴展
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - 備份記錄結構
struct BackupRecord: Identifiable, Hashable {
    let id: String
    let timestamp: Date
    let tripCount: Int
    let favoriteCount: Int
    let cycleCount: Int
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

struct TripSnapshot: Hashable {
    let id: String
    let userId: String
    let createdAt: Date
    let typeRaw: String
    let originalPrice: Int
    let paidPrice: Int
    let isTransfer: Bool
    let isFree: Bool
    let startStation: String
    let endStation: String
    let routeId: String
    let note: String
    let cycleId: String?
    let transferDiscountTypeRaw: String?
}

struct FavoriteRouteSnapshot: Hashable {
    let id: UUID
    let typeRaw: String
    let startStation: String
    let endStation: String
    let routeId: String
    let price: Int
    let isTransfer: Bool
    let isFree: Bool
}

// 🔥 加上 @MainActor 確保整個 Service 都在主執行緒運行
@MainActor
class CloudKitSyncService: ObservableObject {
    static let shared = CloudKitSyncService()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var backupHistory: [BackupRecord] = []
    
    // CloudKit 物件本身是 Sendable 的，可以在不同執行緒安全使用
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.tpass-app.tpasscalc")
        privateDatabase = container.privateCloudDatabase
        loadLastSyncDate()
    }
    
    private func loadLastSyncDate() {
        if let date = UserDefaults.standard.object(forKey: "last_cloudkit_sync_date") as? Date {
            self.lastSyncDate = date
        }
    }
    
    // MARK: - 上傳備份到 CloudKit
    func uploadBackup(trips: [TripSnapshot], favorites: [FavoriteRouteSnapshot], cycles: [Cycle]) async throws {
        isSyncing = true
        syncError = nil
        
        defer { isSyncing = false }
        
        // 1) 確認 iCloud 可用
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable_check_signin")])
        }
        
        // 2) 使用時間戳作為備份 ID
        let backupId = String(Int64(Date().timeIntervalSince1970 * 1000))
        print("📤 開始上傳備份 ID: \(backupId)")
        
        // 3) 先上傳備份元數據記錄
        let metaRecord = CKRecord(recordType: "BackupMeta", recordID: CKRecord.ID(recordName: backupId))
        metaRecord["timestamp"] = Date() as CKRecordValue
        metaRecord["tripCount"] = trips.count as CKRecordValue
        metaRecord["favoriteCount"] = favorites.count as CKRecordValue
        metaRecord["cycleCount"] = cycles.count as CKRecordValue
        
        do {
            _ = try await privateDatabase.modifyRecords(saving: [metaRecord], deleting: [])
            print("   ✅ BackupMeta 上傳成功")
        } catch {
            print("   ❌ BackupMeta 上傳失敗: \(error.localizedDescription)")
            throw error
        }
        
        // 4) 建立 BackupMeta 的 Reference
        let metaReference = CKRecord.Reference(recordID: metaRecord.recordID, action: .deleteSelf)
        
        // 5) 準備 CKRecord
        let tripRecords = trips.map { tripToRecord($0, backupMetaRef: metaReference) }
        let favoriteRecords = favorites.map { favoriteToRecord($0, backupMetaRef: metaReference) }
        let cycleRecords = cycles.map { cycleToRecord($0, backupMetaRef: metaReference) }
        
        // 6) 分批上傳
        let batchSize = 400
        let allRecords = tripRecords + favoriteRecords + cycleRecords
        
        var successCount = 0
        var failCount = 0
        
        for (index, batch) in allRecords.chunked(into: batchSize).enumerated() {
            do {
                let result = try await privateDatabase.modifyRecords(saving: batch, deleting: [])
                // 這裡簡化處理，因為 modifyRecords 會直接回傳結果
                successCount += result.saveResults.count
                print("   ✅ 批次 \(index + 1) 完成")
            } catch {
                print("   ❌ 批次 \(index + 1) 失敗: \(error.localizedDescription)")
                failCount += batch.count
            }
        }
        
        if failCount > 0 {
            let errorMsg = String(localized: "cloudkit_partial_upload_failed_detail \(failCount)")
            throw NSError(domain: "CloudKit", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // 7) 更新最後同步時間
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now, forKey: "last_cloudkit_sync_date")
        
        print("✅ 上傳完成")
    }
    
    // MARK: - 查詢備份歷史
    func fetchBackupHistory() async throws -> [BackupRecord] {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable")])
        }
        
        // 這裡的邏輯必須完全改寫以符合 Swift 6 Concurrency
        // 我們直接使用 async/await 版本的 convenience API，不要用 Operation block
        
        let startDate = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "timestamp >= %@", startDate as CVarArg)
        let query = CKQuery(recordType: "BackupMeta", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        // 使用 iOS 15+ 的 async API
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil
        
        repeat {
            let (matchResults, nextCursor) = try await privateDatabase.records(matching: query, inZoneWith: nil, desiredKeys: ["timestamp", "tripCount", "favoriteCount", "cycleCount"], resultsLimit: CKQueryOperation.maximumResults)
            
            cursor = nextCursor
            
            for result in matchResults {
                switch result.1 {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    print("⚠️ 單筆讀取失敗: \(error)")
                }
            }
        } while cursor != nil
        
        let backups = allRecords.compactMap { record -> BackupRecord? in
            let backupId = record.recordID.recordName
            guard let timestamp = record["timestamp"] as? Date,
                  let tripCount = record["tripCount"] as? Int,
                  let favoriteCount = record["favoriteCount"] as? Int,
                  let cycleCount = record["cycleCount"] as? Int else {
                return nil
            }
            return BackupRecord(
                id: backupId,
                timestamp: timestamp,
                tripCount: tripCount,
                favoriteCount: favoriteCount,
                cycleCount: cycleCount
            )
        }
        
        self.backupHistory = backups
        return backups
    }
    
    // MARK: - 從 CloudKit 恢復特定備份
    func restoreFromBackup(backupId: String) async throws -> (trips: [Trip], favorites: [FavoriteRoute], cycles: [Cycle]) {
        isSyncing = true
        defer { isSyncing = false }
        
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable")])
        }
        
        let metaRecordID = CKRecord.ID(recordName: backupId)
        let metaReference = CKRecord.Reference(recordID: metaRecordID, action: .deleteSelf)
        
        // 使用 async 輔助方法
        let tripRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "Trip")
        let favRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "FavoriteRoute")
        let cycleRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "Cycle")
        
        let restoredTrips = tripRecords.compactMap(recordToTrip)
        let restoredFavorites = favRecords.compactMap(recordToFavorite)
        let restoredCycles = cycleRecords.compactMap(recordToCycle)
        
        return (restoredTrips, restoredFavorites, restoredCycles)
    }
    
    // 輔助方法：使用 async API 查詢，避免 Block 造成的 Data Race
    private func fetchRecordsByBackupMeta(_ metaReference: CKRecord.Reference, recordType: String) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        let predicate = NSPredicate(format: "backupMeta == %@", metaReference)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        var cursor: CKQueryOperation.Cursor? = nil
        
        repeat {
            // 如果有 cursor，應該要用 cursor 查詢，但 CKDatabase.records(continuingMatchFrom:) 比較麻煩
            // 這裡為了簡單且安全，我們展示標準的迴圈查詢邏輯
            
            // 注意：CKDatabase 的 async API 目前在處理 Cursor 上比較複雜
            // 為了完全解決 Swift 6 問題，我們回歸最安全的做法：手動包裝 Operation 但不使用 self
            
            let batch = try await fetchBatch(query: query, cursor: cursor, recordType: recordType)
            records.append(contentsOf: batch.records)
            cursor = batch.cursor
            
        } while cursor != nil
        
        return records
    }
    
    // 用於 async 迴圈的 Helper
    private struct BatchResult {
        let records: [CKRecord]
        let cursor: CKQueryOperation.Cursor?
    }
    
    // 將 Operation 封裝在不會 capture self 的函數中
    private func fetchBatch(query: CKQuery, cursor: CKQueryOperation.Cursor?, recordType: String) async throws -> BatchResult {
        return try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor = cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
            }
            
            operation.resultsLimit = CKQueryOperation.maximumResults
            
            var fetchedRecords: [CKRecord] = []
            
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    fetchedRecords.append(record)
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    continuation.resume(returning: BatchResult(records: fetchedRecords, cursor: cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // 使用 privateDatabase 執行，這裡不涉及 self 的狀態修改
            self.privateDatabase.add(operation)
        }
    }
    
    // MARK: - 删除特定備份
    func deleteBackup(backupId: String) async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        let status = try await container.accountStatus()
        guard status == .available else { return }
        
        var recordIDsToDelete: [CKRecord.ID] = []
        
        // 為了避免複雜的 async 邏輯，這裡簡化：只刪除 meta，讓系統自動清理 reference (如果設定了 deleteSelf)
        // 或者使用上面定義的安全查詢方法
        
        // 簡單起見，我們只刪除 Meta (因為設定了 Reference Action: .deleteSelf，CloudKit 會自動刪除子記錄)
        let metaRecordID = CKRecord.ID(recordName: backupId)
        
        // 嘗試刪除 (如果需要明確刪除子項目，請參考 fetchRecordsByBackupMeta 的模式)
        // 這裡假設 Reference Action 生效，直接刪除 Meta
        _ = try await privateDatabase.modifyRecords(saving: [], deleting: [metaRecordID])
        
        // 更新本地
        backupHistory.removeAll { $0.id == backupId }
    }
    
    // MARK: - CKRecord Builders (無狀態純函數，不需要修改)
    private func tripToRecord(_ trip: TripSnapshot, backupMetaRef: CKRecord.Reference) -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "Trip", recordID: recordID)
        record["backupMeta"] = backupMetaRef
        record["id"] = trip.id as CKRecordValue
        record["userId"] = trip.userId as CKRecordValue
        record["createdAt"] = trip.createdAt as CKRecordValue
        record["typeRaw"] = trip.typeRaw as CKRecordValue
        record["originalPrice"] = trip.originalPrice as CKRecordValue
        record["paidPrice"] = trip.paidPrice as CKRecordValue
        record["isTransfer"] = NSNumber(value: trip.isTransfer) as CKRecordValue
        record["isFree"] = NSNumber(value: trip.isFree) as CKRecordValue
        record["startStation"] = trip.startStation as CKRecordValue
        record["endStation"] = trip.endStation as CKRecordValue
        record["routeId"] = trip.routeId as CKRecordValue
        record["note"] = trip.note as CKRecordValue
        if let cycleId = trip.cycleId { record["cycleId"] = cycleId as CKRecordValue }
        if let transferDiscountTypeRaw = trip.transferDiscountTypeRaw { record["transferDiscountTypeRaw"] = transferDiscountTypeRaw as CKRecordValue }
        return record
    }

    private func favoriteToRecord(_ fav: FavoriteRouteSnapshot, backupMetaRef: CKRecord.Reference) -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "FavoriteRoute", recordID: recordID)
        record["backupMeta"] = backupMetaRef
        record["id"] = fav.id.uuidString as CKRecordValue
        record["typeRaw"] = fav.typeRaw as CKRecordValue
        record["startStation"] = fav.startStation as CKRecordValue
        record["endStation"] = fav.endStation as CKRecordValue
        record["routeId"] = fav.routeId as CKRecordValue
        record["price"] = fav.price as CKRecordValue
        record["isTransfer"] = NSNumber(value: fav.isTransfer) as CKRecordValue
        record["isFree"] = NSNumber(value: fav.isFree) as CKRecordValue
        return record
    }

    private func cycleToRecord(_ cycle: Cycle, backupMetaRef: CKRecord.Reference) -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "Cycle", recordID: recordID)
        record["backupMeta"] = backupMetaRef
        record["id"] = cycle.id as CKRecordValue
        record["start"] = cycle.start as CKRecordValue
        record["end"] = cycle.end as CKRecordValue
        record["region"] = cycle.region.rawValue as CKRecordValue
        if let name = cycle.displayName { record["displayName"] = name as CKRecordValue }
        return record
    }
    
    // MARK: - Record to Model 轉換
    private func recordToTrip(_ record: CKRecord) -> Trip? {
        guard let id = record["id"] as? String,
              let userId = record["userId"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let typeRaw = record["typeRaw"] as? String,
              let type = TransportType(rawValue: typeRaw),
              let originalPrice = record["originalPrice"] as? Int,
              let paidPrice = record["paidPrice"] as? Int,
              let isTransferNum = record["isTransfer"] as? NSNumber,
              let isFreeNum = record["isFree"] as? NSNumber,
              let startStation = record["startStation"] as? String,
              let endStation = record["endStation"] as? String,
              let routeId = record["routeId"] as? String else { return nil }

        let note = record["note"] as? String ?? ""
        let cycleId = record["cycleId"] as? String
        let transferDiscountTypeRaw = record["transferDiscountTypeRaw"] as? String
        let transferDiscountType = transferDiscountTypeRaw.flatMap { TransferDiscountType(rawValue: $0) }

        return Trip(
            id: id,
            userId: userId,
            createdAt: createdAt,
            type: type,
            originalPrice: originalPrice,
            paidPrice: paidPrice,
            isTransfer: isTransferNum.boolValue,
            isFree: isFreeNum.boolValue,
            startStation: startStation,
            endStation: endStation,
            routeId: routeId,
            note: note,
            transferDiscountType: transferDiscountType,
            cycleId: cycleId
        )
    }

    private func recordToFavorite(_ record: CKRecord) -> FavoriteRoute? {
        guard let id = record["id"] as? String,
              let typeRaw = record["typeRaw"] as? String,
              let type = TransportType(rawValue: typeRaw),
              let startStation = record["startStation"] as? String,
              let endStation = record["endStation"] as? String,
              let routeId = record["routeId"] as? String,
              let price = record["price"] as? Int,
              let isTransfer = record["isTransfer"] as? Bool,
              let isFree = record["isFree"] as? Bool else { return nil }

        let uuid = UUID(uuidString: id) ?? UUID()
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

    private func recordToCycle(_ record: CKRecord) -> Cycle? {
        guard let id = record["id"] as? String,
              let start = record["start"] as? Date,
              let end = record["end"] as? Date else { return nil }

        let displayName = record["displayName"] as? String
        let regionRawValue = record["region"] as? String ?? TPASSRegion.north.rawValue
        let region = TPASSRegion(rawValue: regionRawValue) ?? .north
        
        let calendar = Calendar.current
        let startAtMidnight = calendar.startOfDay(for: start)
        let endAtMidnight = calendar.startOfDay(for: end)
        
        return Cycle(id: id, start: startAtMidnight, end: endAtMidnight, displayName: displayName, region: region)
    }
}
