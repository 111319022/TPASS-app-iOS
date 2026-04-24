import SwiftUI

// MARK: - 開發者後台（Apple 設定風格）
struct DeveloperDashboardView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var themeManager = ThemeManager.shared

    // 問題回報相關
    @State private var isSettingUpIssuePush = false
    @State private var isPushEnabled = false
    @AppStorage("issueReportLoopbackEnabled") private var isLoopbackEnabled = false
    @State private var isSendingLocalTest = false
    @State private var isRunningCloudKitCheck = false
    @State private var isClearingNotificationMarks = false

    // Alert
    @State private var showAlertTitle = ""
    @State private var showAlertMessage = ""
    @State private var showAlert = false

    // Intro 重置
    @State private var showResetIntroAlert = false

    // 通知導航
    @State private var openIssueReportsFromNotification = false

    // 資料分析匯出
    @State private var isExporting = false
    @State private var csvFileURL: URL?

    // SwiftData
    @State private var showSwiftDataAdmin = false

    var body: some View {
        Form {
            // MARK: - 1. 主控台
            Section(header: Text("主控台")) {
                NavigationLink(destination: DevConsoleView()) {
                    settingsRow(
                        icon: "terminal",
                        iconColor: .green,
                        title: "Console",
                        subtitle: "即時查看 App log（自動擷取所有 print 輸出）"
                    )
                }
            }

            // MARK: - 2. 問題回報
            Section(header: Text("問題回報")) {
                NavigationLink(destination: DeveloperIssueReportsView()) {
                    settingsRow(
                        icon: "doc.text.magnifyingglass",
                        iconColor: .orange,
                        title: "查看問題回報",
                        subtitle: "進入回報列表與狀態管理"
                    )
                }

                Toggle(isOn: Binding(
                    get: { isPushEnabled },
                    set: { newValue in
                        isPushEnabled = newValue
                        Task { await handlePushToggleChange(newValue) }
                    }
                )) {
                    settingsRow(
                        icon: "bell.badge",
                        iconColor: .blue,
                        title: "問題回報推播",
                        subtitle: "建立或移除 CloudKit 訂閱"
                    )
                }
                .disabled(isSettingUpIssuePush)

                Toggle(isOn: $isLoopbackEnabled) {
                    settingsRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .green,
                        title: "同機回報通知",
                        subtitle: "同一台裝置送出回報時立即顯示通知"
                    )
                }

                Button {
                    sendLocalNotificationTest()
                } label: {
                    settingsRow(
                        icon: "app.badge",
                        iconColor: .purple,
                        title: "測試通知（2 秒後）",
                        subtitle: "確認本機通知與權限"
                    )
                }
                .disabled(isSendingLocalTest)

                Button {
                    runCloudKitSelfCheck()
                } label: {
                    settingsRow(
                        icon: "icloud.and.arrow.up",
                        iconColor: .cyan,
                        title: "CloudKit 推播自我檢查",
                        subtitle: "檢查帳號、通知與訂閱狀態"
                    )
                }
                .disabled(isRunningCloudKitCheck)

                Button {
                    clearIssueNotificationMarks()
                } label: {
                    settingsRow(
                        icon: "checkmark.circle",
                        iconColor: .teal,
                        title: "清除所有標記",
                        subtitle: "清除回報通知與 App 角標"
                    )
                }
                .disabled(isClearingNotificationMarks)
            }

            // MARK: - 3. 資料管理
            Section(header: Text("資料管理")) {
                Button {
                    showSwiftDataAdmin = true
                } label: {
                    settingsRow(
                        icon: "folder.badge.gearshape",
                        iconColor: .blue,
                        title: "SwiftData 資料管理",
                        subtitle: "查看所有資料並支援逐筆刪除"
                    )
                }
            }

            // MARK: - 4. 資料分析
            Section(header: Text("資料分析")) {
                Button {
                    exportVoiceParseLogs()
                } label: {
                    HStack {
                        settingsRow(
                            icon: "square.and.arrow.down",
                            iconColor: .indigo,
                            title: isExporting ? "匯出中..." : "匯出 VoiceParseLog CSV",
                            subtitle: "匯出語音輸入解析紀錄"
                        )
                        if isExporting {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isExporting)

                if let url = csvFileURL {
                    ShareLink(item: url) {
                        settingsRow(
                            icon: "square.and.arrow.up",
                            iconColor: .mint,
                            title: "分享已匯出的 CSV",
                            subtitle: "透過系統分享面板傳送"
                        )
                    }
                }
            }

            // MARK: - 5. 開發者工具
            Section(header: Text("開發者工具")) {
                Button {
                    showResetIntroAlert = true
                } label: {
                    settingsRow(
                        icon: "arrow.counterclockwise",
                        iconColor: .red,
                        title: "重新觸發 Intro",
                        subtitle: "清除登入狀態並顯示 Intro"
                    )
                }
            }
        }
        .navigationTitle("開發者後台")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .task {
            await initializePushStatus()
            openIssueReportsIfNeeded()
        }
        .navigationDestination(isPresented: $openIssueReportsFromNotification) {
            DeveloperIssueReportsView()
        }
        .alert("重新觸發 Intro", isPresented: $showResetIntroAlert) {
            Button("取消", role: .cancel) {}
            Button("重置並回到 Intro", role: .destructive) {
                auth.currentUser = nil
            }
        } message: {
            Text("會清除目前登入狀態並立即顯示 Intro，不會刪除 local_user。")
        }
        .alert(showAlertTitle, isPresented: $showAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(showAlertMessage)
        }
        .sheet(isPresented: $showSwiftDataAdmin) {
            NavigationStack {
                SwiftDataManagementView()
            }
        }
    }

    // MARK: - 設定風格 Row

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(themeManager.primaryTextColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - 問題回報功能

    private func openIssueReportsIfNeeded() {
        let pendingRecordID = UserDefaults.standard.string(forKey: "issueReportNavigateRecordID") ?? ""
        let hasRouteFlag = UserDefaults.standard.bool(forKey: "issueReportNavigateToDetail")
        guard hasRouteFlag && !pendingRecordID.isEmpty else { return }
        openIssueReportsFromNotification = true
    }

    private func initializePushStatus() async {
        guard !isSettingUpIssuePush else { return }
        isSettingUpIssuePush = true
        do {
            let enabled = try await IssueReportService.shared.checkSubscriptionStatus()
            isPushEnabled = enabled
        } catch {
            showResult(title: "初始化失敗", message: error.localizedDescription)
        }
        isSettingUpIssuePush = false
    }

    private func handlePushToggleChange(_ isEnabled: Bool) async {
        guard !isSettingUpIssuePush else { return }
        isSettingUpIssuePush = true
        do {
            if isEnabled {
                try await IssueReportService.shared.setupDeveloperPushNotification()
                showResult(title: "設定成功", message: "已建立 IssueReport 的開發者推播訂閱。")
            } else {
                try await IssueReportService.shared.removeDeveloperPushNotification()
                showResult(title: "移除成功", message: "已移除 IssueReport 的開發者推播訂閱。")
            }
        } catch {
            isPushEnabled.toggle()
            showResult(title: "設定失敗", message: error.localizedDescription)
        }
        isSettingUpIssuePush = false
    }

    private func sendLocalNotificationTest() {
        guard !isSendingLocalTest else { return }
        isSendingLocalTest = true
        Task {
            do {
                try await IssueReportService.shared.sendDeveloperLocalTestNotification()
                showResult(title: "測試已送出", message: "請在 2 秒內確認是否收到本機通知。")
            } catch {
                showResult(title: "測試失敗", message: error.localizedDescription)
            }
            isSendingLocalTest = false
        }
    }

    private func runCloudKitSelfCheck() {
        guard !isRunningCloudKitCheck else { return }
        isRunningCloudKitCheck = true
        Task {
            let result = await IssueReportService.shared.runCloudKitPushSelfCheck()
            var lines: [String] = []
            lines.append("通知權限：\(result.notificationAuthorized ? "已允許" : "未允許")")
            lines.append("iCloud 帳號：\(result.iCloudAvailable ? "可用" : "不可用")")
            lines.append("iCloud 狀態：\(result.accountStatusDescription)")
            lines.append("CloudKit 使用者識別：\(result.userRecordAccessible ? "可取得" : "不可取得")")
            lines.append("IssueReport 訂閱：\(result.subscriptionExists ? "已建立" : "未建立")")
            if let desc = result.subscriptionDescription, !desc.isEmpty {
                lines.append("訂閱資訊：\(desc)")
            }
            if let error = result.subscriptionCheckError, !error.isEmpty {
                lines.append("診斷訊息：\(error)")
            }
            showResult(title: "自我檢查完成", message: lines.joined(separator: "\n"))
            isRunningCloudKitCheck = false
        }
    }

    private func clearIssueNotificationMarks() {
        guard !isClearingNotificationMarks else { return }
        isClearingNotificationMarks = true
        Task {
            do {
                try await IssueReportService.shared.clearIssueReportNotificationMarks()
                showResult(title: "清除完成", message: "已清除回報通知標記與 App 角標。")
            } catch {
                showResult(title: "清除失敗", message: error.localizedDescription)
            }
            isClearingNotificationMarks = false
        }
    }

    // MARK: - 資料分析

    private func exportVoiceParseLogs() {
        guard !isExporting else { return }
        isExporting = true
        csvFileURL = nil
        Task {
            do {
                let fileURL = try await VoiceLogExportService.shared.exportLogsToCSV()
                csvFileURL = fileURL
            } catch {
                showResult(title: "匯出失敗", message: error.localizedDescription)
            }
            isExporting = false
        }
    }

    // MARK: - Alert Helper

    private func showResult(title: String, message: String) {
        showAlertTitle = title
        showAlertMessage = message
        showAlert = true
    }
}

// MARK: - 相容舊名稱（SettingsView / AboutAppView 引用不需改動）
typealias DeveloperToolsPlaceholderView = DeveloperDashboardView

#Preview {
    NavigationView {
        DeveloperDashboardView()
            .environmentObject(AuthService.shared)
    }
}
