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
    let status: String

    var daysElapsed: Int {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: createdAt)
        let endDate = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0, 0)
    }
}

struct PushSelfCheckResult {
    let notificationAuthorized: Bool
    let iCloudAvailable: Bool
    let accountStatusDescription: String
    let userRecordAccessible: Bool
    let subscriptionExists: Bool
    let subscriptionDescription: String?
    let subscriptionCheckError: String?
}

final class IssueReportService {
    static let shared = IssueReportService()

    private let containerIdentifier = "iCloud.com.tpass-app.tpasscalc"
    private let recordType = "IssueReport"
    private let subscriptionID = "developer-issue-report-subscription"
    private let loopbackEnabledKey = "issueReportLoopbackEnabled"

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
        record["status"] = "pending" as CKRecordValue

        _ = try await publicDB.save(record)

        if UserDefaults.standard.bool(forKey: loopbackEnabledKey) {
            do {
                try await sendIssueReportLoopbackNotification(content: trimmedContent)
            } catch {
                print("IssueReport loopback notification failed: \(error.localizedDescription)")
            }
        }
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
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        subscription.notificationInfo = notificationInfo

        _ = try await publicDB.save(subscription)
        UIApplication.shared.registerForRemoteNotifications()
    }

    func checkSubscriptionStatus() async throws -> Bool {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase

        do {
            _ = try await publicDB.subscription(for: subscriptionID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        }
    }

    func removeDeveloperPushNotification() async throws {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        _ = try await publicDB.deleteSubscription(withID: subscriptionID)
    }

    @MainActor
    func sendDeveloperLocalTestNotification() async throws {
        let isAuthorized = try await requestNotificationAuthorization()
        guard isAuthorized else {
            throw IssueReportError.notificationPermissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = "TPASS 開發者測試通知"
        content.body = "如果你看到這則通知，代表裝置通知通道正常。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "developer-local-test-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    @MainActor
    func sendIssueReportLoopbackNotification(content: String) async throws {
        let isAuthorized = try await requestNotificationAuthorization()
        guard isAuthorized else {
            throw IssueReportError.notificationPermissionDenied
        }

        let preview = String(content.prefix(60))

        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "收到新的APP問題回報（本機）！"
        notificationContent.body = preview.isEmpty ? "已送出一則新的問題回報。" : preview
        notificationContent.sound = .default

        let request = UNNotificationRequest(
            identifier: "issue-report-loopback-\(UUID().uuidString)",
            content: notificationContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    @MainActor
    func clearIssueReportNotificationMarks() async throws {
        let center = UNUserNotificationCenter.current()

        let delivered = await withCheckedContinuation { (continuation: CheckedContinuation<[UNNotification], Never>) in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }

        let issueNotificationIDs = delivered
            .map(\ .request.identifier)
            .filter {
                $0.hasPrefix("issue-report-received-") ||
                $0.hasPrefix("issue-report-loopback-") ||
                $0.hasPrefix("developer-local-test-")
            }

        if !issueNotificationIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: issueNotificationIDs)
        }

        if #available(iOS 16.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                center.setBadgeCount(0) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }

        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func runCloudKitPushSelfCheck() async -> PushSelfCheckResult {
        let notificationAuthorized = await currentNotificationAuthorizationStatus()

        let container = CKContainer(identifier: containerIdentifier)
        let publicDB = container.publicCloudDatabase

        var iCloudAvailable = false
        var accountStatusDescription = "unknown"
        var userRecordAccessible = false
        var subscriptionExists = false
        var subscriptionDescription: String?
        var subscriptionCheckError: String?

        do {
            let status = try await container.accountStatus()
            accountStatusDescription = String(describing: status)
            iCloudAvailable = status == .available
        } catch {
            subscriptionCheckError = "iCloud 狀態檢查失敗：\(error.localizedDescription)"
        }

        if iCloudAvailable {
            do {
                _ = try await container.userRecordID()
                userRecordAccessible = true
            } catch {
                subscriptionCheckError = "使用者識別檢查失敗：\(error.localizedDescription)"
            }

            do {
                let subscription = try await publicDB.subscription(for: subscriptionID)
                subscriptionExists = true
                subscriptionDescription = "\(type(of: subscription)) / id=\(subscription.subscriptionID)"
            } catch let error as CKError where error.code == .unknownItem {
                subscriptionExists = false
            } catch {
                subscriptionCheckError = "訂閱檢查失敗：\(error.localizedDescription)"
            }
        }

        return PushSelfCheckResult(
            notificationAuthorized: notificationAuthorized,
            iCloudAvailable: iCloudAvailable,
            accountStatusDescription: accountStatusDescription,
            userRecordAccessible: userRecordAccessible,
            subscriptionExists: subscriptionExists,
            subscriptionDescription: subscriptionDescription,
            subscriptionCheckError: subscriptionCheckError
        )
    }

    func updateIssueStatus(recordID: String, newStatus: String) async throws {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        let ckRecordID = CKRecord.ID(recordName: recordID)
        let record = try await publicDB.record(for: ckRecordID)
        record["status"] = newStatus as CKRecordValue
        _ = try await publicDB.save(record)
    }

    func deleteIssueReport(recordID: String) async throws {
        let publicDB = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        let ckRecordID = CKRecord.ID(recordName: recordID)
        _ = try await publicDB.deleteRecord(withID: ckRecordID)
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

    private func currentNotificationAuthorizationStatus() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let isAllowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                continuation.resume(returning: isAllowed)
            }
        }
    }

    private static func mapRecordToItem(_ record: CKRecord) -> IssueReportItem {
        let content = (record["content"] as? String) ?? ""
        let email = (record["contactEmail"] as? String) ?? (record["email"] as? String) ?? ""
        let appVersion = (record["appVersion"] as? String) ?? "-"
        let iOSVersion = (record["iOSVersion"] as? String) ?? "-"
        let status = (record["status"] as? String) ?? "pending"
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
            createdAt: createdAt,
            status: status
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
