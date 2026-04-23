import Foundation
import Observation

// MARK: - Log 等級
enum DevLogLevel: String, CaseIterable, Identifiable {
    case info
    case warn
    case error

    var id: String { rawValue }

    var label: String {
        switch self {
        case .info:  return "INFO"
        case .warn:  return "WARN"
        case .error: return "ERROR"
        }
    }
}

// MARK: - Log 項目
struct DevLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: DevLogLevel
    let message: String
    let source: String // "FileName.swift:42"
}

// MARK: - Log 儲存庫
@Observable
final class DevLogStore {
    @MainActor static let shared = DevLogStore()

    private(set) var entries: [DevLogEntry] = []

    private let maxEntries = 1000

    private init() {}

    func append(_ entry: DevLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    /// 匯出目前所有 log 為純文字
    func exportText(filteredEntries: [DevLogEntry]? = nil) -> String {
        let target = filteredEntries ?? entries
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        return target.map { entry in
            let time = formatter.string(from: entry.timestamp)
            return "[\(time)] [\(entry.level.label)] \(entry.message)  (\(entry.source))"
        }.joined(separator: "\n")
    }
}

// MARK: - 全域 Log API
enum DevLog {
    static func info(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .info, message: message, file: file, line: line)
    }

    static func warn(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .warn, message: message, file: file, line: line)
    }

    static func error(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .error, message: message, file: file, line: line)
    }

    private static func log(level: DevLogLevel, message: String, file: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let source = "\(fileName):\(line)"

        let entry = DevLogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            source: source
        )

        // 同時輸出到 stdout（Xcode Console 仍可看到）
        print("[\(level.label)] \(message)  (\(source))")

        Task { @MainActor in
            DevLogStore.shared.append(entry)
        }
    }
}
