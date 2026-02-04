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
    let transferDiscountTypeRaw: String? // 🔥 新增：轉乘優惠類型
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

class CloudKitSyncService: ObservableObject {
    static let shared = CloudKitSyncService()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var backupHistory: [BackupRecord] = []
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.tpass-app.tpasscalc")
        privateDatabase = container.privateCloudDatabase
        loadLastSyncDate()
    }
    
    private func loadLastSyncDate() {
        if let date = UserDefaults.standard.object(forKey: "last_cloudkit_sync_date") as? Date {
            DispatchQueue.main.async {
                self.lastSyncDate = date
            }
        }
    }
    
    // MARK: - 上傳備份到 CloudKit
    func uploadBackup(trips: [TripSnapshot], favorites: [FavoriteRouteSnapshot], cycles: [Cycle]) async throws {
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { await MainActor.run { isSyncing = false } } }
        
        // 1) 確認 iCloud 可用
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable_check_signin")])
        }
        
        // 2) 使用時間戳作為備份 ID
        let backupId = String(Int64(Date().timeIntervalSince1970 * 1000))
        print("📤 開始上傳備份 ID: \(backupId)")
        print("   Trips: \(trips.count), Favorites: \(favorites.count), Cycles: \(cycles.count)")
        
        // 3) 先上傳備份元數據記錄（作為「資料夾」）
        let metaRecord = CKRecord(recordType: "BackupMeta", recordID: CKRecord.ID(recordName: backupId))
        metaRecord["timestamp"] = Date() as CKRecordValue
        metaRecord["tripCount"] = trips.count as CKRecordValue
        metaRecord["favoriteCount"] = favorites.count as CKRecordValue
        metaRecord["cycleCount"] = cycles.count as CKRecordValue
        
        print("   先上傳 BackupMeta")
        do {
            _ = try await privateDatabase.modifyRecords(saving: [metaRecord], deleting: [])
            print("   ✅ BackupMeta 上傳成功")
        } catch {
            print("   ❌ BackupMeta 上傳失敗: \(error.localizedDescription)")
            throw error
        }
        
        // 4) 建立 BackupMeta 的 Reference
        let metaReference = CKRecord.Reference(recordID: metaRecord.recordID, action: .deleteSelf)
        
        // 5) 準備 CKRecord，加入 backupMeta reference
        let tripRecords = trips.map { tripToRecord($0, backupMetaRef: metaReference) }
        let favoriteRecords = favorites.map { favoriteToRecord($0, backupMetaRef: metaReference) }
        let cycleRecords = cycles.map { cycleToRecord($0, backupMetaRef: metaReference) }
        
        print("   已建立 \(tripRecords.count) 筆 Trip 記錄 (含 reference)")
        print("   已建立 \(favoriteRecords.count) 筆 FavoriteRoute 記錄 (含 reference)")
        print("   已建立 \(cycleRecords.count) 筆 Cycle 記錄 (含 reference)")
        
        // 🔧 調試：打印所有 Cycle 記錄的內容（確保方案完整備份）
        print("   🔥 === Cycle 備份詳情 ===")
        for (index, cycleRecord) in cycleRecords.enumerated() {
            print("   Cycle[\(index)] ID: \(cycleRecord["id"] ?? "nil")")
            print("   Cycle[\(index)] region: \(cycleRecord["region"] ?? "nil")")
            print("   Cycle[\(index)] displayName: \(cycleRecord["displayName"] ?? "nil")")
            print("   Cycle[\(index)] start: \(cycleRecord["start"] ?? "nil")")
            print("   Cycle[\(index)] end: \(cycleRecord["end"] ?? "nil")")
            print("   Cycle[\(index)] 所有欄位: \(cycleRecord.allKeys())")
        }
        print("   🔥 ===============")
        
        // 🔧 調試：打印前 3 筆 Trip 記錄的欄位
        print("   🔥 === Trip 備份詳情（前3筆）===")
        for (index, tripRecord) in tripRecords.prefix(3).enumerated() {
            print("   Trip[\(index)] ID: \(tripRecord["id"] ?? "nil")")
            print("   Trip[\(index)] cycleId: \(tripRecord["cycleId"] ?? "nil")")
            print("   Trip[\(index)] transferDiscountTypeRaw: \(tripRecord["transferDiscountTypeRaw"] ?? "nil")")
            print("   Trip[\(index)] 所有欄位: \(tripRecord.allKeys())")
        }
        print("   🔥 ===============")
        
        // 6) 分批上傳資料記錄（CloudKit 限制每次最多 400 條記錄）
        let batchSize = 400
        let allRecords = tripRecords + favoriteRecords + cycleRecords
        
        print("   總共 \(allRecords.count) 筆記錄，準備分批上傳")
        
        var successCount = 0
        var failCount = 0
        
        for (index, batch) in allRecords.chunked(into: batchSize).enumerated() {
            print("   上傳批次 \(index + 1)，記錄數: \(batch.count)")
            do {
                let result = try await privateDatabase.modifyRecords(saving: batch, deleting: [])
                
                // 詳細檢查每條記錄的保存結果
                for (recordID, saveResult) in result.saveResults {
                    switch saveResult {
                    case .success(let record):
                        let recordType = record.recordType
                        print("      ✅ 保存成功: \(recordType) - \(recordID.recordName)")
                        successCount += 1
                    case .failure(let error):
                        let recordType = batch.first(where: { $0.recordID == recordID })?.recordType ?? "Unknown"
                        let sourceRecord = batch.first(where: { $0.recordID == recordID })
                        print("      ❌ 保存失敗: \(recordType) - \(recordID.recordName)")
                        print("         錯誤代碼: \((error as NSError).code)")
                        print("         錯誤信息: \(error.localizedDescription)")
                        
                        // 🔧 打印來源記錄的詳細信息用於除錯
                        if let source = sourceRecord {
                            print("         記錄欄位: \(source.allKeys().joined(separator: ", "))")
                            if recordType == "Trip" {
                                print("         isTransfer: \(source["isTransfer"] as? NSNumber ?? source["isTransfer"] ?? "nil")")
                                print("         isFree: \(source["isFree"] as? NSNumber ?? source["isFree"] ?? "nil")")
                                print("         startStation: \(source["startStation"] ?? "nil")")
                                print("         endStation: \(source["endStation"] ?? "nil")")
                                print("         cycleId: \(source["cycleId"] ?? "nil")")
                                print("         transferDiscountTypeRaw: \(source["transferDiscountTypeRaw"] ?? "nil")")
                            } else if recordType == "Cycle" {
                                print("         id: \(source["id"] ?? "nil")")
                                print("         region: \(source["region"] ?? "nil")")
                                print("         start: \(source["start"] ?? "nil")")
                                print("         end: \(source["end"] ?? "nil")")
                            }
                        }
                        failCount += 1
                    }
                }
                
                print("   ✅ 批次 \(index + 1) 完成")
            } catch {
                print("   ❌ 批次 \(index + 1) 整體失敗: \(error.localizedDescription)")
                failCount += batch.count
            }
        }
        
        print("📊 上傳完成 - 成功: \(successCount), 失敗: \(failCount)")
        
        if failCount > 0 {
            let errorMsg = String(localized: "cloudkit_partial_upload_failed_detail \(failCount)")
            throw NSError(domain: "CloudKit", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // 7) 更新最後同步時間
        await MainActor.run {
            let now = Date()
            lastSyncDate = now
            UserDefaults.standard.set(now, forKey: "last_cloudkit_sync_date")
        }


        print("✅ CloudKit 上傳備份完成 (Trips: \(trips.count), Favorites: \(favorites.count), Cycles: \(cycles.count), BackupID: \(backupId))")
    }
    
    // MARK: - 查詢備份歷史
    func fetchBackupHistory() async throws -> [BackupRecord] {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable")])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var allRecords: [CKRecord] = []
            
            // 查詢最近 180 天的備份（避免 schema 限制）
            let startDate = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date()
            let predicate = NSPredicate(format: "timestamp >= %@", startDate as CVarArg)
            
            let query = CKQuery(recordType: "BackupMeta", predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["timestamp", "tripCount", "favoriteCount", "cycleCount"]
            operation.resultsLimit = CKQueryOperation.maximumResults
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    print("⚠️ 讀取單筆記錄失敗: \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    var backups = allRecords.compactMap { record -> BackupRecord? in
                        let backupId = record.recordID.recordName
                        guard let timestamp = record["timestamp"] as? Date,
                              let tripCount = record["tripCount"] as? Int,
                              let favoriteCount = record["favoriteCount"] as? Int,
                              let cycleCount = record["cycleCount"] as? Int else {
                            print("⚠️ 跳過無效的備份記錄: \(record.recordID.recordName)")
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
                    
                    // 客戶端排序：按時間降序
                    backups.sort { $0.timestamp > $1.timestamp }
                    
                    Task { @MainActor in
                        self.backupHistory = backups
                    }
                    
                    print("✅ 成功讀取 \(backups.count) 筆備份歷史")
                    continuation.resume(returning: backups)
                    
                case .failure(let error):
                    print("❌ 查詢備份歷史失敗: \(error)")
                    continuation.resume(throwing: error)
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    // MARK: - 從 CloudKit 恢復特定備份
    func restoreFromBackup(backupId: String) async throws -> (trips: [Trip], favorites: [FavoriteRoute], cycles: [Cycle]) {
        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }

        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable")])
        }

        print("🔄 開始恢復備份 ID: \(backupId)")
        
        // 建立 BackupMeta 記錄的 Reference
        let metaRecordID = CKRecord.ID(recordName: backupId)
        let metaReference = CKRecord.Reference(recordID: metaRecordID, action: .deleteSelf)
        
        // 使用 reference 查詢，直接查詢某個備份資料夾裡的記錄
        let tripRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "Trip")
        print("📦 取得 \(tripRecords.count) 筆 Trip 記錄")
        
        let favRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "FavoriteRoute")
        print("📦 取得 \(favRecords.count) 筆 FavoriteRoute 記錄")
        
        let cycleRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "Cycle")
        print("📦 取得 \(cycleRecords.count) 筆 Cycle 記錄")
        
        // 🔧 調試：檢查 Cycle 記錄的 region 欄位
        print("   🔥 === Cycle 記錄詳情 ===")
        for (index, record) in cycleRecords.enumerated() {
            print("   Cycle[\(index)] ID: \(record["id"] ?? "nil")")
            print("   Cycle[\(index)] region: \(record["region"] ?? "nil")")
            print("   Cycle[\(index)] displayName: \(record["displayName"] ?? "nil")")
        }
        print("   🔥 ===============")

        let restoredTrips = tripRecords.compactMap(recordToTrip)
        print("✅ 成功轉換 \(restoredTrips.count)/\(tripRecords.count) 筆 Trip")
        
        let restoredFavorites = favRecords.compactMap(recordToFavorite)
        print("✅ 成功轉換 \(restoredFavorites.count)/\(favRecords.count) 筆 FavoriteRoute")
        
        let restoredCycles = cycleRecords.compactMap(recordToCycle)
        print("✅ 成功轉換 \(restoredCycles.count)/\(cycleRecords.count) 筆 Cycle")
        
        // 🔧 調試：檢查恢復後的 Cycle region
        print("   🔥 === 恢復後的 Cycle ===")
        for (index, cycle) in restoredCycles.enumerated() {
            print("   Cycle[\(index)] ID: \(cycle.id)")
            print("   Cycle[\(index)] region: \(cycle.region.rawValue)")
            print("   Cycle[\(index)] displayName: \(cycle.displayName ?? "nil")")
        }
        print("   🔥 ===============")

        print("✅ CloudKit 恢復備份完成 (BackupID: \(backupId), Trips: \(restoredTrips.count), Favorites: \(restoredFavorites.count), Cycles: \(restoredCycles.count))")
        return (restoredTrips, restoredFavorites, restoredCycles)
    }
    
    // 輔助方法：使用 backupMeta reference 查詢記錄
    private func fetchRecordsByBackupMeta(_ metaReference: CKRecord.Reference, recordType: String) async throws -> [CKRecord] {
        print("🔍 開始查詢 \(recordType) 記錄 (用 reference)")
        return try await withCheckedThrowingContinuation { continuation in
            var records: [CKRecord] = []
            
            let predicate = NSPredicate(format: "backupMeta == %@", metaReference)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            
            // 遞迴函數處理翻頁
            func executeQuery(cursor: CKQueryOperation.Cursor? = nil) {
                let operation: CKQueryOperation
                if let cursor = cursor {
                    operation = CKQueryOperation(cursor: cursor)
                } else {
                    operation = CKQueryOperation(query: query)
                }
                
                operation.resultsLimit = CKQueryOperation.maximumResults
                
                operation.recordMatchedBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        records.append(record)
                        print("   ✅ 找到記錄: \(recordID.recordName)")
                    case .failure(let error):
                        print("   ⚠️ 讀取失敗: \(error)")
                    }
                }
                
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        if let cursor = cursor {
                            print("   📄 查詢下一頁...")
                            executeQuery(cursor: cursor)
                        } else {
                            print("📊 查詢完成 - 類型: \(recordType), 總數: \(records.count)")
                            continuation.resume(returning: records)
                        }
                    case .failure(let error):
                        print("❌ 查詢失敗: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
                
                privateDatabase.add(operation)
            }
            
            executeQuery()
        }
    }
    
    // MARK: - 删除特定備份
    func deleteBackup(backupId: String) async throws {
        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }
        
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable")])
        }
        
        print("🗑️ 開始刪除備份 ID: \(backupId)")
        
        var recordIDsToDelete: [CKRecord.ID] = []
        
        // 查詢 Trip records
        recordIDsToDelete.append(contentsOf: try await fetchRecordsByBackupId(backupId, recordType: "Trip"))
        
        // 查詢 FavoriteRoute records
        recordIDsToDelete.append(contentsOf: try await fetchRecordsByBackupId(backupId, recordType: "FavoriteRoute"))
        
        // 查詢 Cycle records
        recordIDsToDelete.append(contentsOf: try await fetchRecordsByBackupId(backupId, recordType: "Cycle"))
        
        // 添加 BackupMeta record
        let metaRecordID = CKRecord.ID(recordName: backupId)
        recordIDsToDelete.append(metaRecordID)
        
        // 刪除所有 records (CloudKit 最多一次刪除 400 筆)
        var deletedCount = 0
        for i in stride(from: 0, to: recordIDsToDelete.count, by: 400) {
            let batch = Array(recordIDsToDelete[i..<min(i + 400, recordIDsToDelete.count)])
            _ = try await privateDatabase.modifyRecords(saving: [], deleting: batch)
            deletedCount += batch.count
        }
        
        // 更新本地歷史
        await MainActor.run {
            backupHistory.removeAll { $0.id == backupId }
        }
        
        print("✅ CloudKit 刪除備份成功 (BackupID: \(backupId), 刪除 \(deletedCount) 筆記錄)")
    }
    
    // 輔助方法：使用 CKQueryOperation 查詢指定 backupId 的 records
    private func fetchRecordsByBackupId(_ backupId: String, recordType: String) async throws -> [CKRecord.ID] {
        return try await withCheckedThrowingContinuation { continuation in
            var recordIDs: [CKRecord.ID] = []
            
            let metaReference = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: backupId),
                action: .deleteSelf
            )
            let predicate = NSPredicate(format: "backupMeta == %@", metaReference)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = []
            operation.resultsLimit = CKQueryOperation.maximumResults
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success:
                    recordIDs.append(recordID)
                case .failure(let error):
                    print("⚠️ 查詢失敗: \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: recordIDs)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    // MARK: - 檢查 iCloud 帳號狀態
    func checkiCloudStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            print("❌ iCloud 帳號檢查失敗: \(error)")
            return false
        }
    }
    
    // MARK: - CKRecord Builders
    private func tripToRecord(_ trip: TripSnapshot, backupMetaRef: CKRecord.Reference) -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "Trip", recordID: recordID)
        record["backupMeta"] = backupMetaRef
        
        // 🔧 必要欄位（非空）
        record["id"] = trip.id as CKRecordValue
        record["userId"] = trip.userId as CKRecordValue
        record["createdAt"] = trip.createdAt as CKRecordValue
        record["typeRaw"] = trip.typeRaw as CKRecordValue
        record["originalPrice"] = trip.originalPrice as CKRecordValue
        record["paidPrice"] = trip.paidPrice as CKRecordValue
        
        // 🔧 Bool 欄位（使用 NSNumber 確保正確序列化）
        record["isTransfer"] = NSNumber(value: trip.isTransfer) as CKRecordValue
        record["isFree"] = NSNumber(value: trip.isFree) as CKRecordValue
        
        // 🔧 站點資訊
        record["startStation"] = trip.startStation as CKRecordValue
        record["endStation"] = trip.endStation as CKRecordValue
        record["routeId"] = trip.routeId as CKRecordValue
        record["note"] = trip.note as CKRecordValue
        
        // 🔧 可選欄位
        if let cycleId = trip.cycleId {
            record["cycleId"] = cycleId as CKRecordValue
        }
        
        // 🔥 新增：轉乘優惠類型
        if let transferDiscountTypeRaw = trip.transferDiscountTypeRaw {
            record["transferDiscountTypeRaw"] = transferDiscountTypeRaw as CKRecordValue
        }
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
        
        // 🔧 Bool 欄位使用 NSNumber 序列化
        record["isTransfer"] = NSNumber(value: fav.isTransfer) as CKRecordValue
        record["isFree"] = NSNumber(value: fav.isFree) as CKRecordValue
        return record
    }

    private func cycleToRecord(_ cycle: Cycle, backupMetaRef: CKRecord.Reference) -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: "Cycle", recordID: recordID)
        record["backupMeta"] = backupMetaRef
        
        // 🔥 必要欄位
        record["id"] = cycle.id as CKRecordValue
        record["start"] = cycle.start as CKRecordValue
        record["end"] = cycle.end as CKRecordValue
        
        // 🔥 TPASS 方案（核心資訊，必須備份）
        record["region"] = cycle.region.rawValue as CKRecordValue
        
        // 🔧 可選欄位
        if let name = cycle.displayName {
            record["displayName"] = name as CKRecordValue
        }
        
        print("   📦 Cycle 記錄 [\(cycle.id)]: region=\(cycle.region.rawValue), displayName=\(cycle.displayName ?? "nil")")
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
              let routeId = record["routeId"] as? String else {
            print("⚠️ Trip 記錄缺少必要欄位: \(record.recordID.recordName)")
            print("   欄位內容: \(record.allKeys().joined(separator: ", "))")
            return nil
        }

        let note = record["note"] as? String ?? ""
        let cycleId = record["cycleId"] as? String
        
        // 🔥 新增：恢復轉乘優惠類型
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
              let isFree = record["isFree"] as? Bool else {
            print("⚠️ FavoriteRoute 記錄缺少必要欄位: \(record.recordID.recordName)")
            print("   欄位內容: \(record.allKeys().joined(separator: ", "))")
            return nil
        }

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
              let end = record["end"] as? Date else {
            print("⚠️ Cycle 記錄缺少必要欄位: \(record.recordID.recordName)")
            print("   欄位內容: \(record.allKeys().joined(separator: ", "))")
            return nil
        }

        let displayName = record["displayName"] as? String
        
        // 🔥 恢復 TPASS 方案（向後兼容：若無 region 則預設為基北北桃）
        let regionRawValue = record["region"] as? String ?? TPASSRegion.north.rawValue
        let region = TPASSRegion(rawValue: regionRawValue) ?? .north
        
        // 🔧 確保恢復的日期是午夜時間
        let calendar = Calendar.current
        let startAtMidnight = calendar.startOfDay(for: start)
        let endAtMidnight = calendar.startOfDay(for: end)
        
        print("   ✅ Cycle 恢復 [\(id)]: region=\(region.rawValue), displayName=\(displayName ?? "nil")")
        
        return Cycle(id: id, start: startAtMidnight, end: endAtMidnight, displayName: displayName, region: region)
    }
}
