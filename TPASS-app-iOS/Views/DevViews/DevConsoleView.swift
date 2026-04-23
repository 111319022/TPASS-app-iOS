import SwiftUI

struct DevConsoleView: View {
    @State private var store = DevLogStore.shared
    @StateObject private var themeManager = ThemeManager.shared

    @State private var filterLevel: DevLogLevel? = nil  // nil = 全部
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true
    @State private var showExportSheet: Bool = false
    @State private var exportFileURL: URL? = nil
    @State private var showClearAlert: Bool = false

    private var filteredEntries: [DevLogEntry] {
        store.entries.filter { entry in
            if let level = filterLevel, entry.level != level {
                return false
            }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return entry.message.lowercased().contains(query)
                    || entry.source.lowercased().contains(query)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 頂部篩選與搜尋
            VStack(spacing: 10) {
                // 等級篩選
                Picker("等級", selection: $filterLevel) {
                    Text("全部").tag(nil as DevLogLevel?)
                    ForEach(DevLogLevel.allCases) { level in
                        Text(level.label).tag(level as DevLogLevel?)
                    }
                }
                .pickerStyle(.segmented)

                // 搜尋欄
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜尋 log...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider()

            // MARK: - Log 清單
            if filteredEntries.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(store.entries.isEmpty ? "尚無 log" : "無符合條件的 log")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredEntries) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: filteredEntries.count) {
                        if autoScroll, let last = filteredEntries.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()

            // MARK: - 底部工具列
            HStack {
                // 清除
                Button {
                    showClearAlert = true
                } label: {
                    Label("清除", systemImage: "trash")
                        .font(.subheadline)
                }
                .disabled(store.entries.isEmpty)

                Spacer()

                // 計數
                Text("\(filteredEntries.count) 筆")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // 自動捲動
                Button {
                    autoScroll.toggle()
                } label: {
                    Image(systemName: autoScroll ? "arrow.down.to.line.compact" : "arrow.down.to.line")
                        .font(.subheadline)
                        .foregroundColor(autoScroll ? themeManager.accentColor : .secondary)
                }

                // 匯出
                Button {
                    exportLogs()
                } label: {
                    Label("匯出", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                }
                .disabled(filteredEntries.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .navigationTitle("Console")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .alert("清除所有 Log", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                store.clear()
            }
        } message: {
            Text("確定要清除所有 log 紀錄嗎？此動作無法復原。")
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportFileURL {
                ShareSheetView(items: [url])
            }
        }
    }

    // MARK: - Log Row

    @ViewBuilder
    private func logRow(_ entry: DevLogEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // 時間
            Text(formatTime(entry.timestamp))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 72, alignment: .leading)

            // 等級標籤
            Text(entry.level.label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(levelColor(entry.level))
                .frame(width: 42, alignment: .leading)

            // 訊息
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)

                Text(entry.source)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(levelBackgroundColor(entry.level))
        )
    }

    // MARK: - Helpers

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func levelColor(_ level: DevLogLevel) -> Color {
        switch level {
        case .info:  return .blue
        case .warn:  return .orange
        case .error: return .red
        }
    }

    private func levelBackgroundColor(_ level: DevLogLevel) -> Color {
        switch level {
        case .info:  return .clear
        case .warn:  return .orange.opacity(0.06)
        case .error: return .red.opacity(0.08)
        }
    }

    private func exportLogs() {
        let text = store.exportText(filteredEntries: filteredEntries)
        let fileName = "DevLog_\(exportDateString()).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try text.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
            showExportSheet = true
        } catch {
            DevLog.error("匯出 log 失敗: \(error.localizedDescription)")
        }
    }

    private func exportDateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}

// MARK: - ShareSheet (UIKit bridge)
private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DevConsoleView()
    }
}
