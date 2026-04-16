import SwiftUI
import UIKit

@MainActor
struct DeveloperIssueReportsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var reports: [IssueReportItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedReport: IssueReportItem?
    @State private var showCopiedAlert = false
    @State private var copiedMessage = ""

    var body: some View {
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
            } else {
                List(reports) { report in
                    Button {
                        selectedReport = report
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
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
                    LabeledContent("Record ID", value: report.id)
                        .textSelection(.enabled)
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
