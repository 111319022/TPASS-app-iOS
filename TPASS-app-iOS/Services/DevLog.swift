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
    private(set) var isCapturingOutput: Bool = false

    private let maxEntries = 1000

    // stdout/stderr 攔截
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var originalStdout: Int32 = -1
    private var originalStderr: Int32 = -1

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

    // MARK: - stdout/stderr 攔截

    /// 開始攔截 stdout 和 stderr，將輸出導入 Console
        func startCapturing() {
            guard !isCapturingOutput else { return }
            isCapturingOutput = true

            setvbuf(stdout, nil, _IONBF, 0)
            setvbuf(stderr, nil, _IONBF, 0)

            // MARK: - 攔截 stdout
            let outPipe = Pipe()
            stdoutPipe = outPipe
            originalStdout = dup(STDOUT_FILENO)
            dup2(outPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }

                // 寫回原始 stdout（Xcode Console 仍可見）
                if let self, self.originalStdout >= 0 {
                    data.withUnsafeBytes { buf in
                        if let ptr = buf.baseAddress {
                            write(self.originalStdout, ptr, data.count)
                        }
                    }
                }

                let lines = text.components(separatedBy: .newlines)
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedLine.isEmpty else { continue }

                    // 過濾掉 DevLog 自身產生的格式
                    if trimmedLine.hasPrefix("[INFO]") || trimmedLine.hasPrefix("[WARN]") || trimmedLine.hasPrefix("[ERROR]") {
                        continue
                    }

                    let entry = DevLogEntry(
                        timestamp: Date(),
                        level: .info,
                        message: trimmedLine,
                        source: "stdout"
                    )
                    Task { @MainActor [weak self] in
                        self?.append(entry)
                    }
                }
            }

            // MARK: - 攔截 stderr
            let errPipe = Pipe()
            stderrPipe = errPipe
            originalStderr = dup(STDERR_FILENO)
            dup2(errPipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

            errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }

                // 寫回原始 stderr
                if let self, self.originalStderr >= 0 {
                    data.withUnsafeBytes { buf in
                        if let ptr = buf.baseAddress {
                            write(self.originalStderr, ptr, data.count)
                        }
                    }
                }

                let lines = text.components(separatedBy: .newlines)
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedLine.isEmpty else { continue }
                    
                    // stderr 同樣逐行過濾
                    if trimmedLine.hasPrefix("[INFO]") || trimmedLine.hasPrefix("[WARN]") || trimmedLine.hasPrefix("[ERROR]") {
                        continue
                    }

                    let entry = DevLogEntry(
                        timestamp: Date(),
                        level: .error,
                        message: trimmedLine,
                        source: "stderr"
                    )
                    Task { @MainActor [weak self] in
                        self?.append(entry)
                    }
                }
            }
        }

    /// 停止攔截，恢復原始 stdout/stderr
    func stopCapturing() {
        guard isCapturingOutput else { return }

        // 恢復 stdout
        if originalStdout >= 0 {
            dup2(originalStdout, STDOUT_FILENO)
            close(originalStdout)
            originalStdout = -1
        }
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil

        // 恢復 stderr
        if originalStderr >= 0 {
            dup2(originalStderr, STDERR_FILENO)
            close(originalStderr)
            originalStderr = -1
        }
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe = nil

        isCapturingOutput = false
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
