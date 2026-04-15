import Foundation
import CloudKit
import CryptoKit

enum DeveloperAccessCheckResult {
    case allowed
    case denied(String)
}

final class DeveloperAccessService {
    static let shared = DeveloperAccessService()

    private let container = CKContainer(identifier: "iCloud.com.tpass-app.tpasscalc")
    private var database: CKDatabase { container.publicCloudDatabase }

    private let policyRecordType = "DevAccessPolicy"
    private let policyRecordName = "main-dev-access-policy"

    private init() {}

    func verifyCurrentUserAccess() async -> DeveloperAccessCheckResult {
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                return .denied("iCloud 帳號不可用，無法驗證開發者權限。")
            }

            let userRecordID = try await container.userRecordID()
            let userHash = normalizedHash(hashUserRecordName(userRecordID.recordName))

            let recordID = CKRecord.ID(recordName: policyRecordName)

            let policyRecord: CKRecord
            do {
                policyRecord = try await database.record(for: recordID)
            } catch let ckError as CKError where ckError.code == .unknownItem {
                return .denied("CloudKit 尚未建立白名單設定（DevAccessPolicy/\(policyRecordName)）。")
            }

            guard policyRecord.recordType == policyRecordType else {
                return .denied("CloudKit 白名單設定格式錯誤（recordType 應為 DevAccessPolicy）。")
            }

            let enabled = boolValue(from: policyRecord["enabled"], defaultValue: true)
            guard enabled else {
                return .denied("開發者功能目前由遠端設定關閉。")
            }

            let allowedHashes = normalizedHashes(from: policyRecord["allowedUserHashes"] as? [String] ?? [])

            if allowedHashes.isEmpty {
                return .denied("白名單目前為空。需要在 CloudKit 的 DevAccessPolicy/main-dev-access-policy 填入 allowedUserHashes。\n目前使用者識別碼：\n\(userHash)")
            }

            guard allowedHashes.contains(userHash) else {
                return .denied("你目前不在白名單內。\n請提供以下識別碼給管理者加入白名單：\n\(userHash)\n\n目前白名單筆數：\(allowedHashes.count)")
            }

            return .allowed
        } catch {
            return .denied("驗證開發者權限失敗：\(error.localizedDescription)")
        }
    }

    func currentUserHashForAdmin() async -> String? {
        do {
            let status = try await container.accountStatus()
            guard status == .available else { return nil }

            let userRecordID = try await container.userRecordID()
            return hashUserRecordName(userRecordID.recordName)
        } catch {
            return nil
        }
    }

    private func hashUserRecordName(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func boolValue(from raw: CKRecordValueProtocol?, defaultValue: Bool) -> Bool {
        if let bool = raw as? Bool {
            return bool
        }
        if let number = raw as? NSNumber {
            return number.boolValue
        }
        return defaultValue
    }

    private func normalizedHashes(from rawValues: [String]) -> [String] {
        var results: [String] = []

        for value in rawValues {
            let parts = value
                .replacingOccurrences(of: "\r", with: "\n")
                .split(whereSeparator: { $0 == "\n" || $0 == "," })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

            for part in parts {
                let normalized = normalizedHash(part)
                if !normalized.isEmpty {
                    results.append(normalized)
                }
            }
        }

        return Array(Set(results))
    }

    private func normalizedHash(_ input: String) -> String {
        let lowered = input.lowercased()
        return lowered.filter { ch in
            (ch >= "0" && ch <= "9") || (ch >= "a" && ch <= "f")
        }
    }
}
