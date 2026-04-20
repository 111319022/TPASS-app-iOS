import SwiftUI
import UIKit

@MainActor
struct DeveloperIssueReportsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var reports: [IssueReportItem] = []
    @State private var filterStatus: String = "pending"
    @State private var isLoading = false
    @State private var isUpdatingStatus = false
    @State private var errorMessage: String?
    @State private var selectedReport: IssueReportItem?
    @State private var showCopiedAlert = false
    @State private var copiedMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("狀態", selection: $filterStatus) {
                Text("待處理").tag("pending")
                Text("已修復").tag("fixed")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Group {
                if isLoading && reports.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if reports.isEmpty {
                    ContentUnavailableView(
                        "尚無問題回報",
                        systemImage: "tray",
                        description: Text("目前還沒有使用者送出回報。")
                    )
                } else if filteredReports.isEmpty {
                    ContentUnavailableView(
                        "目前沒有符合狀態的回報",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("請切換上方狀態查看其他紀錄。")
                    )
                } else {
                    List(filteredReports) { report in
                        Button {
                            selectedReport = report
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(formatDate(report.createdAt))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text(report.content)
                                            .font(.headline)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(themeManager.primaryTextColor)

                                        Text("App \(report.appVersion) · iOS \(report.iOSVersion)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer(minLength: 0)

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }

                                HStack(spacing: 8) {
                                    statusBadge(for: report.status)
                                    Text("⏳ 已等待 \(report.daysElapsed) 天")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(themeManager.cardBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(themeManager.primaryTextColor.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadReports(forceRefresh: true)
                    }
                }
            }
        }
        .navigationTitle("問題回報紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .task {
            await loadReports(forceRefresh: false)
        }
        .sheet(item: $selectedReport) { report in
            reportDetailView(report)
        }
        .alert("讀取失敗", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "發生未知錯誤")
        }
        .alert("已複製", isPresented: $showCopiedAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(copiedMessage)
        }
    }

    private var filteredReports: [IssueReportItem] {
        reports.filter { normalizedStatus($0.status) == filterStatus }
    }

    private func loadReports(forceRefresh: Bool) async {
        if !forceRefresh, !reports.isEmpty { return }

        isLoading = true
        defer { isLoading = false }

        do {
            reports = try await IssueReportService.shared.fetchReports(limit: 150)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func copyContent(_ report: IssueReportItem) {
        UIPasteboard.general.string = report.content
        copiedMessage = "已複製回報內容"
        showCopiedAlert = true
    }

    private func copyEmail(_ report: IssueReportItem) {
        guard !report.email.isEmpty else { return }
        UIPasteboard.general.string = report.email
        copiedMessage = "已複製 Email"
        showCopiedAlert = true
    }

    private func normalizedStatus(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func statusBadge(for status: String) -> some View {
        let normalized = normalizedStatus(status)
        let isFixed = normalized == "fixed"

        return HStack(spacing: 4) {
            Circle()
                .fill(isFixed ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isFixed ? "已修復" : "待處理")
                .font(.caption2.weight(.bold))
                .foregroundColor(isFixed ? Color.green : Color.red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isFixed ? Color.green : Color.red).opacity(0.12))
        .clipShape(Capsule())
    }

    private func markIssueAsFixed(_ report: IssueReportItem) async {
        guard !isUpdatingStatus else { return }
        isUpdatingStatus = true

        do {
            try await IssueReportService.shared.updateIssueStatus(recordID: report.id, newStatus: "fixed")
            await loadReports(forceRefresh: true)
            selectedReport = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isUpdatingStatus = false
    }

    @ViewBuilder
    private func reportDetailView(_ report: IssueReportItem) -> some View {
        NavigationView {
            List {
                Section("回報內容") {
                    Text(report.content)
                        .textSelection(.enabled)
                    Button {
                        copyContent(report)
                    } label: {
                        Label("複製回報內容", systemImage: "doc.on.doc")
                    }
                }

                Section("聯絡資訊") {
                    Text(report.email.isEmpty ? "未提供" : report.email)
                        .textSelection(.enabled)
                    if !report.email.isEmpty {
                        Button {
                            copyEmail(report)
                        } label: {
                            Label("複製 Email", systemImage: "envelope.badge")
                        }
                    }
                }

                Section("系統資訊") {
                    LabeledContent("App 版本", value: report.appVersion)
                    LabeledContent("iOS 版本", value: report.iOSVersion)
                    LabeledContent("建立時間", value: formatDate(report.createdAt))
                    LabeledContent("狀態", value: normalizedStatus(report.status) == "fixed" ? "已修復" : "待處理")
                    LabeledContent("等待天數", value: "\(report.daysElapsed) 天")
                    LabeledContent("Record ID", value: report.id)
                        .textSelection(.enabled)
                }

                if normalizedStatus(report.status) == "pending" {
                    Section {
                        Button {
                            Task {
                                await markIssueAsFixed(report)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isUpdatingStatus {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                }
                                Text("標記為已修復")
                                    .font(.headline)
                                Spacer()
                            }
                        }
                        .disabled(isUpdatingStatus)
                        .tint(.green)
                    }
                }
            }
            .navigationTitle("回報詳細資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        selectedReport = nil
                    }
                }
            }
        }
    }
}
