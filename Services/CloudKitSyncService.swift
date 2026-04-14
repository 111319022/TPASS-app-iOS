import Foundation
import Combine
import CloudKit
import SwiftUI

// MARK: - 備份記錄結構
struct BackupRecord: Identifiable, Hashable {
    let id: String
    let timestamp: Date
    let tripCount: Int
    let favoriteCount: Int
    let cycleCount: Int
    let isLegacy: Bool
    
    var formattedDate: String {
        return Self.formatter.string(from: timestamp)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()
}

struct TripSnapshot: Codable, Hashable {
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

struct FavoriteRouteSnapshot: Codable, Hashable {
    let id: UUID
    let typeRaw: String
    let startStation: String
    let endStation: String
    let routeId: String
    let price: Int
    let isTransfer: Bool
    let isFree: Bool
}

struct CycleSnapshot: Codable, Hashable {
    let id: String
    let start: Date
    let end: Date
    let displayName: String?
    let regionRaw: String

    init(cycle: Cycle) {
        self.id = cycle.id
        self.start = cycle.start
        self.end = cycle.end
        self.displayName = cycle.displayName
        self.regionRaw = cycle.region.rawValue
    }
}

struct TPASSBackup: Codable, Hashable {
    let schemaVersion: Int
    let createdAt: Date
    let trips: [TripSnapshot]
    let favorites: [FavoriteRouteSnapshot]
    let cycles: [CycleSnapshot]
}

//  加上 @MainActor 確保整個 Service 都在主執行緒運行
@MainActor
class CloudKitSyncService: ObservableObject {
    static let shared = CloudKitSyncService()
    
    private enum RecordType {
        static let legacyMeta = "BackupMeta"
        static let v2Backup = "TPASSBackupV2"
    }
    
    private enum FieldKey {
        static let timestamp = "timestamp"
        static let tripCount = "tripCount"
        static let favoriteCount = "favoriteCount"
        static let cycleCount = "cycleCount"
        static let payloadAsset = "payloadAsset"
        static let schemaVersion = "schemaVersion"
    }
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var backupHistory: [BackupRecord] = []
    @Published var uploadProgress: String = ""
    
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
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        do {
            uploadProgress = "Checking iCloud availability..."
            let status = try await container.accountStatus()
            guard status == .available else {
                throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable_check_signin")])
            }

            uploadProgress = "Preparing backup payload..."
            let backup = TPASSBackup(
                schemaVersion: 2,
                createdAt: Date(),
                trips: trips,
                favorites: favorites,
                cycles: cycles.map { CycleSnapshot(cycle: $0) }
            )

            uploadProgress = "Encoding JSON..."
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let payloadData = try encoder.encode(backup)

            uploadProgress = "Creating backup file..."
            let backupId = String(Int64(Date().timeIntervalSince1970 * 1000))
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tpass-backup-\(backupId)")
                .appendingPathExtension("json")
            try payloadData.write(to: tempURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            uploadProgress = "Uploading to iCloud..."
            let recordID = CKRecord.ID(recordName: backupId)
            let v2Record = CKRecord(recordType: RecordType.v2Backup, recordID: recordID)
            v2Record[FieldKey.timestamp] = backup.createdAt as CKRecordValue
            v2Record[FieldKey.tripCount] = backup.trips.count as CKRecordValue
            v2Record[FieldKey.favoriteCount] = backup.favorites.count as CKRecordValue
            v2Record[FieldKey.cycleCount] = backup.cycles.count as CKRecordValue
            v2Record[FieldKey.schemaVersion] = backup.schemaVersion as CKRecordValue
            v2Record[FieldKey.payloadAsset] = CKAsset(fileURL: tempURL)

            _ = try await privateDatabase.modifyRecords(saving: [v2Record], deleting: [])

            let now = Date()
            lastSyncDate = now
            UserDefaults.standard.set(now, forKey: "last_cloudkit_sync_date")
            uploadProgress = "Upload completed."
            print("✅ V2 備份上傳完成，ID: \(backupId)")
        } catch {
            syncError = error.localizedDescription
            uploadProgress = "Upload failed."
            throw error
        }
    }
    
    // MARK: - 查詢備份歷史
    func fetchBackupHistory() async throws -> [BackupRecord] {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable")])
        }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? Date()

        let predicate = NSPredicate(format: "timestamp >= %@", startDate as CVarArg)
        let legacyRecords = try await fetchRecords(
            recordType: RecordType.legacyMeta,
            predicate: predicate,
            desiredKeys: [FieldKey.timestamp, FieldKey.tripCount, FieldKey.favoriteCount, FieldKey.cycleCount]
        )

        let v2Records: [CKRecord]
        do {
            v2Records = try await fetchRecords(
                recordType: RecordType.v2Backup,
                predicate: predicate,
                desiredKeys: [FieldKey.timestamp, FieldKey.tripCount, FieldKey.favoriteCount, FieldKey.cycleCount]
            )
        } catch {
            if isMissingRecordTypeError(error) {
                // 使用者尚未在 CloudKit Dashboard 部署 V2 schema 時，仍要顯示舊版備份。
                print("ℹ️ TPASSBackupV2 record type 尚未部署，僅載入 legacy 備份")
                v2Records = []
            } else {
                throw error
            }
        }

        let legacyBackups = legacyRecords.compactMap { record -> BackupRecord? in
            guard let timestamp = record[FieldKey.timestamp] as? Date else { return nil }
            return BackupRecord(
                id: record.recordID.recordName,
                timestamp: timestamp,
                tripCount: intValue(from: record[FieldKey.tripCount]),
                favoriteCount: intValue(from: record[FieldKey.favoriteCount]),
                cycleCount: intValue(from: record[FieldKey.cycleCount]),
                isLegacy: true
            )
        }

        let v2Backups = v2Records.compactMap { record -> BackupRecord? in
            guard let timestamp = record[FieldKey.timestamp] as? Date else { return nil }
            return BackupRecord(
                id: record.recordID.recordName,
                timestamp: timestamp,
                tripCount: intValue(from: record[FieldKey.tripCount]),
                favoriteCount: intValue(from: record[FieldKey.favoriteCount]),
                cycleCount: intValue(from: record[FieldKey.cycleCount]),
                isLegacy: false
            )
        }

        for backup in legacyBackups {
            print("[BackupHistory][LEGACY] id=\(backup.id), trips=\(backup.tripCount), favorites=\(backup.favoriteCount), cycles=\(backup.cycleCount), timestamp=\(backup.formattedDate)")
        }
        for backup in v2Backups {
            print("[BackupHistory][V2] id=\(backup.id), trips=\(backup.tripCount), favorites=\(backup.favoriteCount), cycles=\(backup.cycleCount), timestamp=\(backup.formattedDate)")
        }

        let merged = (legacyBackups + v2Backups)
            .sorted { $0.timestamp > $1.timestamp }
        print("📦 備份歷史載入完成：legacy=\(legacyBackups.count), v2=\(v2Backups.count), total=\(merged.count)")
        backupHistory = merged
        return merged
    }

    private func isMissingRecordTypeError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        if message.contains("did not find record type") || message.contains("record type") {
            return true
        }

        if let ckError = error as? CKError {
            switch ckError.code {
            case .unknownItem, .invalidArguments, .serverRejectedRequest:
                return true
            default:
                break
            }

            if let serverMessage = ckError.userInfo[NSLocalizedDescriptionKey] as? String,
               serverMessage.lowercased().contains("did not find record type") {
                return true
            }
        }

        return false
    }
    
    // MARK: - 從 CloudKit 恢復特定備份
    func restoreFromBackup(backupId: String) async throws -> (trips: [Trip], favorites: [FavoriteRoute], cycles: [Cycle]) {
        let isLegacy = backupHistory.first(where: { $0.id == backupId })?.isLegacy ?? true
        return try await restoreFromBackup(backupId: backupId, isLegacy: isLegacy)
    }

    func restoreFromBackup(backupId: String, isLegacy: Bool) async throws -> (trips: [Trip], favorites: [FavoriteRoute], cycles: [Cycle]) {
        isSyncing = true
        defer { isSyncing = false }

        do {
            uploadProgress = isLegacy ? "Downloading legacy backup records..." : "Downloading backup file..."
            let status = try await container.accountStatus()
            guard status == .available else {
                throw NSError(domain: "CloudKit", code: 503, userInfo: [NSLocalizedDescriptionKey: String(localized: "cloudkit_unavailable")])
            }

            if isLegacy {
                let restored = try await restoreFromLegacyBackup(backupId: backupId)
                uploadProgress = "Restore completed."
                return restored
            }

            let restored = try await restoreFromV2Backup(backupId: backupId)
            uploadProgress = "Restore completed."
            return restored
        } catch {
            syncError = error.localizedDescription
            uploadProgress = "Restore failed."
            throw error
        }
    }

    private func restoreFromLegacyBackup(backupId: String) async throws -> (trips: [Trip], favorites: [FavoriteRoute], cycles: [Cycle]) {
        let metaRecordID = CKRecord.ID(recordName: backupId)
        let metaReference = CKRecord.Reference(recordID: metaRecordID, action: .deleteSelf)

        let tripRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "Trip")
        let favRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "FavoriteRoute")
        let cycleRecords = try await fetchRecordsByBackupMeta(metaReference, recordType: "Cycle")

        let restoredTrips = tripRecords.compactMap(recordToTrip)
        let restoredFavorites = favRecords.compactMap(recordToFavorite)
        let restoredCycles = cycleRecords.compactMap(recordToCycle)
        return (restoredTrips, restoredFavorites, restoredCycles)
    }

    private func restoreFromV2Backup(backupId: String) async throws -> (trips: [Trip], favorites: [FavoriteRoute], cycles: [Cycle]) {
        let recordID = CKRecord.ID(recordName: backupId)
        let record = try await privateDatabase.record(for: recordID)
        guard record.recordType == RecordType.v2Backup else {
            throw NSError(domain: "CloudKit", code: 404, userInfo: [NSLocalizedDescriptionKey: "Backup format mismatch"])
        }
        guard let asset = record[FieldKey.payloadAsset] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw NSError(domain: "CloudKit", code: 500, userInfo: [NSLocalizedDescriptionKey: "Backup asset is missing"])
        }

        uploadProgress = "Decoding backup data..."
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(TPASSBackup.self, from: data)

        let restoredTrips = try backup.trips.map { try snapshotToTrip($0) }
        let restoredFavorites = try backup.favorites.map { try snapshotToFavorite($0) }
        let restoredCycles = backup.cycles.map(snapshotToCycle)
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

    private func fetchRecords(recordType: String, predicate: NSPredicate, desiredKeys: [String]) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: FieldKey.timestamp, ascending: false)]

        var cursor: CKQueryOperation.Cursor?
        repeat {
            let matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
            let nextCursor: CKQueryOperation.Cursor?

            if let cursor {
                (matchResults, nextCursor) = try await privateDatabase.records(continuingMatchFrom: cursor)
            } else {
                (matchResults, nextCursor) = try await privateDatabase.records(
                    matching: query,
                    inZoneWith: nil,
                    desiredKeys: desiredKeys,
                    resultsLimit: CKQueryOperation.maximumResults
                )
            }

            cursor = nextCursor
            for result in matchResults {
                switch result.1 {
                case .success(let record):
                    allRecords.append(record)
                case .failure(let error):
                    print("⚠️ \(recordType) 單筆讀取失敗: \(error.localizedDescription)")
                }
            }
        } while cursor != nil

        return allRecords
    }

    private func intValue(from value: Any?) -> Int {
        switch value {
        case let intValue as Int:
            return intValue
        case let int64Value as Int64:
            return Int(int64Value)
        case let number as NSNumber:
            return number.intValue
        default:
            return 0
        }
    }
    
    // MARK: - 删除特定備份
    func deleteBackup(backupId: String) async throws {
        let isLegacy = backupHistory.first(where: { $0.id == backupId })?.isLegacy ?? true
        try await deleteBackup(backupId: backupId, isLegacy: isLegacy)
    }

    func deleteBackup(backupId: String, isLegacy: Bool) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let status = try await container.accountStatus()
        guard status == .available else { return }

        let recordID = CKRecord.ID(recordName: backupId)
        if isLegacy {
            _ = try await privateDatabase.modifyRecords(saving: [], deleting: [recordID])
        } else {
            _ = try await privateDatabase.modifyRecords(saving: [], deleting: [recordID])
        }

        // 更新本地
        backupHistory.removeAll { $0.id == backupId }
    }

    // MARK: - Snapshot to Model 轉換
    private func snapshotToTrip(_ snapshot: TripSnapshot) throws -> Trip {
        guard let type = TransportType(rawValue: snapshot.typeRaw) else {
            throw NSError(domain: "CloudKit", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid transport type in backup"])
        }
        let transferDiscountType = snapshot.transferDiscountTypeRaw.flatMap { TransferDiscountType(rawValue: $0) }
        return Trip(
            id: snapshot.id,
            userId: snapshot.userId,
            createdAt: snapshot.createdAt,
            type: type,
            originalPrice: snapshot.originalPrice,
            paidPrice: snapshot.paidPrice,
            isTransfer: snapshot.isTransfer,
            isFree: snapshot.isFree,
            startStation: snapshot.startStation,
            endStation: snapshot.endStation,
            routeId: snapshot.routeId,
            note: snapshot.note,
            transferDiscountType: transferDiscountType,
            cycleId: snapshot.cycleId
        )
    }

    private func snapshotToFavorite(_ snapshot: FavoriteRouteSnapshot) throws -> FavoriteRoute {
        guard let type = TransportType(rawValue: snapshot.typeRaw) else {
            throw NSError(domain: "CloudKit", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid favorite transport type in backup"])
        }
        return FavoriteRoute(
            id: snapshot.id,
            type: type,
            startStation: snapshot.startStation,
            endStation: snapshot.endStation,
            routeId: snapshot.routeId,
            price: snapshot.price,
            isTransfer: snapshot.isTransfer,
            isFree: snapshot.isFree
        )
    }

    private func snapshotToCycle(_ snapshot: CycleSnapshot) -> Cycle {
        let region = TPASSRegion(rawValue: snapshot.regionRaw) ?? .north
        let calendar = Calendar.current
        let startAtMidnight = calendar.startOfDay(for: snapshot.start)
        let endAtMidnight = calendar.startOfDay(for: snapshot.end)
        return Cycle(
            id: snapshot.id,
            start: startAtMidnight,
            end: endAtMidnight,
            displayName: snapshot.displayName,
            region: region
        )
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
              let isTransfer = boolValue(from: record["isTransfer"]),
              let isFree = boolValue(from: record["isFree"]) else { return nil }

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

    private func boolValue(from value: Any?) -> Bool? {
        switch value {
        case let boolValue as Bool:
            return boolValue
        case let number as NSNumber:
            return number.boolValue
        default:
            return nil
        }
    }
}
