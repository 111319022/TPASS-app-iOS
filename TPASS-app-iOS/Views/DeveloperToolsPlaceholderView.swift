import SwiftUI

struct DeveloperToolsPlaceholderView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showResetIntroAlert = false
    @State private var isSettingUpIssuePush = false
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

                Button {
                    setupIssueReportPush()
                } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.blue)
                        Text("啟用問題回報推播")
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        if isSettingUpIssuePush {
                            ProgressView()
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
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

    private func setupIssueReportPush() {
        guard !isSettingUpIssuePush else { return }
        isSettingUpIssuePush = true

        Task {
            do {
                try await IssueReportService.shared.setupDeveloperPushNotification()
                await MainActor.run {
                    isSettingUpIssuePush = false
                    setupResultTitle = "設定完成"
                    setupResultMessage = "已建立 IssueReport 的開發者推播訂閱。"
                    showSetupResultAlert = true
                }
            } catch {
                await MainActor.run {
                    isSettingUpIssuePush = false
                    setupResultTitle = "設定失敗"
                    setupResultMessage = error.localizedDescription
                    showSetupResultAlert = true
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        DeveloperToolsPlaceholderView()
            .environmentObject(AuthService.shared)
    }
}
