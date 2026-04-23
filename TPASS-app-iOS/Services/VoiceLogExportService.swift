import Foundation
import CloudKit

final class VoiceLogExportService {

    static let shared = VoiceLogExportService()

    private let database: CKDatabase

    private init() {
        database = CKContainer(identifier: "iCloud.com.tpass-app.tpasscalc").publicCloudDatabase
    }

    func exportLogsToCSV() async throws -> URL {
        let query = CKQuery(recordType: "VoiceParseLog", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let (results, _) = try await database.records(matching: query, resultsLimit: 500)

        var records: [CKRecord] = []
        for (_, result) in results {
            if case .success(let record) = result {
                records.append(record)
            }
        }

        records.sort {
            ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
        }

        let header = "Date,AppVersion,Status,FailureReason,IsCorrected,OriginalTranscript,ParsedResult,FinalResult"
        var lines: [String] = [header]

        for record in records {
            let dateString = isoDateString(from: record.creationDate)
            let appVersion = (record["appVersion"] as? String) ?? ""
            let status = (record["status"] as? String) ?? ""
            let failureReason = (record["failureReason"] as? String) ?? ""
            let isCorrected = stringifyCorrected(record["isCorrected"])

            let originalTranscript = sanitizeCSVField(record["originalTranscript"] as? String ?? "")
            let parsedResult = sanitizeCSVField(record["parsedResult"] as? String ?? "")
            let finalResult = sanitizeCSVField(record["finalResult"] as? String ?? "")

            let line = [
                dateString,
                sanitizeCSVField(appVersion),
                sanitizeCSVField(status),
                sanitizeCSVField(failureReason),
                isCorrected,
                originalTranscript,
                parsedResult,
                finalResult
            ].joined(separator: ",")

            lines.append(line)
        }

        let csvString = lines.joined(separator: "\n")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceParseLog_\(timestamp).csv")

        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func sanitizeCSVField(_ value: String) -> String {
        value
            .replacingOccurrences(of: ",", with: "，")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private func isoDateString(from date: Date?) -> String {
        guard let date else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func stringifyCorrected(_ raw: Any?) -> String {
        switch raw {
        case let value as Int:
            return String(value)
        case let value as Int64:
            return String(value)
        case let value as NSNumber:
            return value.stringValue
        case let value as String:
            return value
        case let value as Bool:
            return value ? "1" : "0"
        default:
            return ""
        }
    }
}