import Foundation
import CloudKit
import UIKit
import UserNotifications

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
        notificationInfo.shouldBadge = true
        subscription.notificationInfo = notificationInfo

        _ = try await publicDB.save(subscription)
        UIApplication.shared.registerForRemoteNotifications()
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
