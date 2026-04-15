import SwiftUI

struct DeveloperToolsPlaceholderView: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showResetIntroAlert = false

    var body: some View {
        Form {
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
        .alert("重新觸發 Intro", isPresented: $showResetIntroAlert) {
            Button("取消", role: .cancel) {}
            Button("重置並回到 Intro", role: .destructive) {
                resetIntro()
            }
        } message: {
            Text("會清除目前登入狀態並立即顯示 Intro，不會刪除 local_user。")
        }
    }

    private func resetIntro() {
        auth.currentUser = nil
    }
}

#Preview {
    NavigationView {
        DeveloperToolsPlaceholderView()
            .environmentObject(AuthService.shared)
    }
}
