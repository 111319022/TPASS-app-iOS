import SwiftUI

struct DeveloperToolsPlaceholderView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showResetIntroAlert = false
    @State private var isSettingUpIssuePush = false
    @State private var isPushEnabled = false
    @State private var isUpdatingPushToggleProgrammatically = false
    @State private var showSetupResultAlert = false
    @State private var setupResultTitle = ""
    @State private var setupResultMessage = ""

    var body: some View {
        Form {
            Section(header: Text("開發者工具")) {
                NavigationLink(destination: DeveloperIssueReportsView()) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.orange)
                        Text("查看問題回報")
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                }

                Toggle(isOn: $isPushEnabled) {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.blue)
                        Text("問題回報推播")
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                }
                .disabled(isSettingUpIssuePush)

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
        .onChange(of: isPushEnabled) { _, newValue in
            Task {
                await handlePushToggleChange(newValue)
            }
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
            isUpdatingPushToggleProgrammatically = true
            isPushEnabled = enabled
            isUpdatingPushToggleProgrammatically = false
            isSettingUpIssuePush = false
        } catch {
            isSettingUpIssuePush = false
            setupResultTitle = "初始化失敗"
            setupResultMessage = error.localizedDescription
            showSetupResultAlert = true
        }
    }

    private func handlePushToggleChange(_ isEnabled: Bool) async {
        guard !isUpdatingPushToggleProgrammatically else { return }
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
            isUpdatingPushToggleProgrammatically = true
            isPushEnabled.toggle()
            isUpdatingPushToggleProgrammatically = false
            isSettingUpIssuePush = false
            setupResultTitle = "設定失敗"
            setupResultMessage = error.localizedDescription
            showSetupResultAlert = true
        }
    }
}

#Preview {
    NavigationView {
        DeveloperToolsPlaceholderView()
            .environmentObject(AuthService.shared)
    }
}
