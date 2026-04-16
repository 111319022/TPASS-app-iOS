import Foundation
import CloudKit
import UIKit
import UserNotifications

struct IssueReportItem: Identifiable {
    let id: String
    let content: String
    let email: String
    let appVersion: String
    let iOSVersion: String
    let createdAt: Date
}

final class IssueReportService {
    static let shared = IssueReportService()

    private let containerIdentifier = "iCloud.com.tpass-app.tpasscalc"
    private let recordType = "IssueReport"
    private let subscriptionID = "developer-issue-report-subscription"

    private init() {}

    func submitReport(content: String, email: String) async throws {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw IssueReportError.emptyContent
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let iOSVersion = UIDevice.current.systemVersion

        let record = CKRecord(recordType: recordType)
        record["content"] = trimmedContent as CKRecordValue
        record["contactEmail"] = trimmedEmail as CKRecordValue
        record["appVersion"] = appVersion as CKRecordValue
        record["iOSVersion"] = iOSVersion as CKRecordValue

        _ = try await publicDB.save(record)
    }

    @MainActor
    func setupDeveloperPushNotification() async throws {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase

        let isAuthorized = try await requestNotificationAuthorization()
        guard isAuthorized else {
            throw IssueReportError.notificationPermissionDenied
        }

        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "收到新的 TPASS 問題回報！"
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = true
        notificationInfo.soundName = "default"
        subscription.notificationInfo = notificationInfo

        _ = try await publicDB.save(subscription)
        UIApplication.shared.registerForRemoteNotifications()
    }

    func fetchReports(limit: Int = 100) async throws -> [IssueReportItem] {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let (results, _) = try await publicDB.records(matching: query, resultsLimit: limit)

        var items: [IssueReportItem] = []
        for (_, result) in results {
            switch result {
            case .success(let record):
                items.append(Self.mapRecordToItem(record))
            case .failure:
                continue
            }
        }

        return items.sorted { $0.createdAt > $1.createdAt }
    }

    @MainActor
    private func requestNotificationAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: granted)
            }
        }
    }

    private static func mapRecordToItem(_ record: CKRecord) -> IssueReportItem {
        let content = (record["content"] as? String) ?? ""
        let email = (record["contactEmail"] as? String) ?? (record["email"] as? String) ?? ""
        let appVersion = (record["appVersion"] as? String) ?? "-"
        let iOSVersion = (record["iOSVersion"] as? String) ?? "-"
        let createdAt =
            (record["createdAt"] as? Date) ??
            record.creationDate ??
            record.modificationDate ??
            Date.distantPast

        return IssueReportItem(
            id: record.recordID.recordName,
            content: content,
            email: email,
            appVersion: appVersion,
            iOSVersion: iOSVersion,
            createdAt: createdAt
        )
    }
}

enum IssueReportError: LocalizedError {
    case emptyContent
    case notificationPermissionDenied

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return String(localized: "issueReportEmptyContent")
        case .notificationPermissionDenied:
            return String(localized: "issueReportNotificationPermissionDenied")
        }
    }
}
