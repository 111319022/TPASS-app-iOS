import SwiftUI

struct DeveloperToolsPlaceholderView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showResetIntroAlert = false
    @State private var isSettingUpIssuePush = false
    @State private var isSendingLocalTest = false
    @State private var isRunningCloudKitCheck = false
    @State private var isPushEnabled = false
    @AppStorage("issueReportLoopbackEnabled") private var isLoopbackEnabled = false
    @State private var showSetupResultAlert = false
    @State private var setupResultTitle = ""
    @State private var setupResultMessage = ""

    var body: some View {
        Form {
            Section(header: Text("問題回報")) {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.purple.opacity(0.16))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.purple)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("問題回報控制台")
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Text("集中管理回報、回報通知與功能診斷")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        Divider()
                            .opacity(0.6)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("問題回報管理")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(themeManager.primaryTextColor)

                            NavigationLink(destination: DeveloperIssueReportsView()) {
                                issueActionRow(
                                    icon: "doc.text.magnifyingglass",
                                    title: "查看問題回報",
                                    subtitle: "進入回報列表與狀態管理"
                                )
                            }

                            Toggle(isOn: Binding(
                                get: { isPushEnabled },
                                set: { newValue in
                                    isPushEnabled = newValue
                                    Task {
                                        await handlePushToggleChange(newValue)
                                    }
                                }
                            )) {
                                issueToggleLabel(
                                    icon: "bell.badge",
                                    title: "問題回報推播",
                                    subtitle: "建立或移除 CloudKit 訂閱"
                                )
                            }
                            .disabled(isSettingUpIssuePush)

                            Divider()
                                .opacity(0.5)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("通知測試")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(themeManager.primaryTextColor)

                                Toggle(isOn: $isLoopbackEnabled) {
                                    issueToggleLabel(
                                        icon: "arrow.triangle.2.circlepath",
                                        title: "同機回報通知",
                                        subtitle: "同一台裝置送出回報時立即顯示通知"
                                    )
                                }

                                Button {
                                    sendLocalNotificationTest()
                                } label: {
                                    issueActionRow(
                                        icon: "app.badge",
                                        title: "測試通知（2 秒後）",
                                        subtitle: "確認本機通知與權限"
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isSendingLocalTest)

                                Button {
                                    runCloudKitSelfCheck()
                                } label: {
                                    issueActionRow(
                                        icon: "icloud.and.arrow.up",
                                        title: "CloudKit 推播自我檢查",
                                        subtitle: "檢查帳號、通知與訂閱狀態"
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isRunningCloudKitCheck)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(themeManager.cardBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(themeManager.primaryTextColor.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            }

            Section(header: Text("開發者工具")) {
                Button {
                    showResetIntroAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(themeManager.accentColor)
                        Text("重新觸發 Intro")
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("開發者")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .task {
            await initializePushStatus()
        }
        .alert("重新觸發 Intro", isPresented: $showResetIntroAlert) {
            Button("取消", role: .cancel) {}
            Button("重置並回到 Intro", role: .destructive) {
                resetIntro()
            }
        } message: {
            Text("會清除目前登入狀態並立即顯示 Intro，不會刪除 local_user。")
        }
        .alert(setupResultTitle, isPresented: $showSetupResultAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(setupResultMessage)
        }
    }

    private func resetIntro() {
        auth.currentUser = nil
    }

    private func initializePushStatus() async {
        guard !isSettingUpIssuePush else { return }
        isSettingUpIssuePush = true

        do {
            let enabled = try await IssueReportService.shared.checkSubscriptionStatus()
            isPushEnabled = enabled
            isSettingUpIssuePush = false
        } catch {
            isSettingUpIssuePush = false
            setupResultTitle = "初始化失敗"
            setupResultMessage = error.localizedDescription
            showSetupResultAlert = true
        }
    }

    private func handlePushToggleChange(_ isEnabled: Bool) async {
        guard !isSettingUpIssuePush else { return }
        isSettingUpIssuePush = true

        do {
            if isEnabled {
                try await IssueReportService.shared.setupDeveloperPushNotification()
                setupResultTitle = "設定成功"
                setupResultMessage = "已建立 IssueReport 的開發者推播訂閱。"
            } else {
                try await IssueReportService.shared.removeDeveloperPushNotification()
                setupResultTitle = "移除成功"
                setupResultMessage = "已移除 IssueReport 的開發者推播訂閱。"
            }

            isSettingUpIssuePush = false
            showSetupResultAlert = true
        } catch {
            isPushEnabled.toggle()
            isSettingUpIssuePush = false
            setupResultTitle = "設定失敗"
            setupResultMessage = error.localizedDescription
            showSetupResultAlert = true
        }
    }

    private func sendLocalNotificationTest() {
        guard !isSendingLocalTest else { return }
        isSendingLocalTest = true

        Task {
            do {
                try await IssueReportService.shared.sendDeveloperLocalTestNotification()
                isSendingLocalTest = false
                setupResultTitle = "測試已送出"
                setupResultMessage = "請在 2 秒內確認是否收到本機通知。"
                showSetupResultAlert = true
            } catch {
                isSendingLocalTest = false
                setupResultTitle = "測試失敗"
                setupResultMessage = error.localizedDescription
                showSetupResultAlert = true
            }
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

            if let subscriptionDescription = result.subscriptionDescription, !subscriptionDescription.isEmpty {
                lines.append("訂閱資訊：\(subscriptionDescription)")
            }

            if let error = result.subscriptionCheckError, !error.isEmpty {
                lines.append("診斷訊息：\(error)")
            }

            isRunningCloudKitCheck = false
            setupResultTitle = "自我檢查完成"
            setupResultMessage = lines.joined(separator: "\n")
            showSetupResultAlert = true
        }
    }

    private func issueActionRow(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            issueIconBadge(icon: icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(themeManager.accentColor.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func issueToggleLabel(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            issueIconBadge(icon: icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.primaryTextColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func issueIconBadge(icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(themeManager.accentColor.opacity(0.12))
                .frame(width: 30, height: 30)

            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.accentColor)
        }
        .frame(width: 34, height: 34)
    }
}

#Preview {
    NavigationView {
        DeveloperToolsPlaceholderView()
            .environmentObject(AuthService.shared)
    }
}
