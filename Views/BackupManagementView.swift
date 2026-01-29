import SwiftUI
import CloudKit

// MARK: - 備份管理頁面
struct BackupManagementView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var cloudKitService = CloudKitSyncService.shared

    @State private var isLoadingBackups = false
    @State private var showUploadConfirm = false
    @State private var isExecuting = false
    @State private var selectedBackupId: String? = nil
    @State private var pendingAction: PendingAction? = nil
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var successMessage = ""
    @State private var successTitle = ""
    @State private var showSuccessAlert = false
    
    enum PendingAction: Identifiable {
        case restore(backupId: String)
        case delete(backupId: String)
        
        var id: String {
            switch self {
            case .restore(let id): return "restore-\(id)"
            case .delete(let id): return "delete-\(id)"
            }
        }
    }
    
    var body: some View {
        Form {
            // MARK: - 上傳備份區塊
            Section(header: Text("上傳本地數據到 iCloud")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("將目前的行程、常用路線與週期備份到 iCloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showUploadConfirm = true
                    } label: {
                        HStack {
                            if cloudKitService.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            Text("立即上傳備份")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .disabled(cloudKitService.isSyncing)
                    }
                    
                    if let lastSync = cloudKitService.lastSyncDate {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("最後上傳：\(formatDate(lastSync))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - 下載備份區塊
            Section(header: HStack {
                Text("從 iCloud 恢復備份")
                Spacer()
                if isLoadingBackups {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task { await loadBackupHistory() }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            }) {
                if cloudKitService.backupHistory.isEmpty {
                    // 無備份時不顯示任何列表
                    EmptyView()
                } else {
                    ForEach(cloudKitService.backupHistory) { backup in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(backup.formattedDate)
                                        .font(.headline)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    
                                    HStack(spacing: 12) {
                                        Label("\(backup.tripCount)", systemImage: "figure.walk")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Label("\(backup.favoriteCount)", systemImage: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Label("\(backup.cycleCount)", systemImage: "calendar")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            
                            HStack(spacing: 8) {
                                Button {
                                    pendingAction = .restore(backupId: backup.id)
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.green)
                                        Text("恢復")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                Button {
                                    pendingAction = .delete(backupId: backup.id)
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                        Text("刪除")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // MARK: - 備份說明
            Section(footer: Text("• 上傳：將本地數據備份到 iCloud\n• 恢復：選擇 iCloud 上的備份版本還原本地數據\n• 所有操作均為手動執行，不會自動同步")) {
                EmptyView()
            }
        }
        .navigationTitle("備份管理")
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.backgroundColor)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showUploadConfirm) {
            VStack(spacing: 16) {
                Capsule().frame(width: 40, height: 5).foregroundColor(.secondary.opacity(0.3))
                Text("上傳備份到 iCloud")
                    .font(.title3.bold())
                    .foregroundColor(themeManager.primaryTextColor)
                Text("將上傳 \(getCurrentDataSummary())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Label("\(tripCount) 行程", systemImage: "figure.walk")
                    Label("\(favoriteCount) 常用路線", systemImage: "star.fill")
                    Label("\(cycleCount) 週期", systemImage: "calendar")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                
                Button {
                    showUploadConfirm = false
                    Task { await performUpload() }
                } label: {
                    Text("上傳")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.accentColor)
                        .cornerRadius(12)
                }
                Button("取消", role: .cancel) {
                    showUploadConfirm = false
                }
                .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .presentationDetents([.fraction(0.35)])
            .interactiveDismissDisabled(cloudKitService.isSyncing)
        }
        .alert(item: $pendingAction) { action in
            switch action {
            case .restore(let backupId):
                return Alert(
                    title: Text("確認恢復"),
                    message: Text("恢復後會清除目前裝置上的資料並以此備份覆蓋，請先確認本機最新資料已備份"),
                    primaryButton: .destructive(Text("確認恢復")) {
                        Task { await performRestore(backupId: backupId) }
                    },
                    secondaryButton: .cancel()
                )
                
            case .delete(let backupId):
                return Alert(
                    title: Text("確認刪除"),
                    message: Text("此操作將永久刪除 iCloud 上的備份，無法恢復"),
                    primaryButton: .destructive(Text("確認刪除")) {
                        Task { await performDelete(backupId: backupId) }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .alert(successTitle.isEmpty ? "操作成功" : successTitle, isPresented: $showSuccessAlert) {
            Button("確定") {}
        } message: {
            Text(successMessage)
        }
        .alert("操作失敗", isPresented: $showErrorAlert) {
            Button("確定") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("📱 BackupManagementView appeared - Trips: \(tripCount), Favorites: \(favoriteCount), Cycles: \(cycleCount)")
            Task {
                await loadBackupHistory()
            }
        }
    }
    
    // MARK: - 輔助函數
    
    private var tripCount: Int { appViewModel.trips.count }
    private var favoriteCount: Int { appViewModel.favorites.count }
    private var cycleCount: Int { auth.currentUser?.cycles.count ?? 0 }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func getCurrentDataSummary() -> String {
        "\(tripCount) 筆行程、\(favoriteCount) 個常用路線、\(cycleCount) 個週期"
    }
    
    private func loadBackupHistory() async {
        await MainActor.run { isLoadingBackups = true }
        defer { Task { await MainActor.run { isLoadingBackups = false } } }
        
        do {
            _ = try await cloudKitService.fetchBackupHistory()
        } catch {
            await MainActor.run {
                cloudKitService.backupHistory = []
            }
            print("⚠️ 無法讀取備份歷史：\(error.localizedDescription)")
        }
    }
    
    private func performUpload() async {
        do {
            let cycles = auth.currentUser?.cycles ?? []
            
            print("📤 準備上傳數據:")
            print("   Trips: \(appViewModel.trips.count)")
            print("   Favorites: \(appViewModel.favorites.count)")
            print("   Cycles: \(cycles.count)")
            
            // 檢查第一筆 Trip 的內容
            if let firstTrip = appViewModel.trips.first {
                print("   第一筆 Trip ID: \(firstTrip.id)")
                print("   第一筆 Trip UserID: \(firstTrip.userId)")
            }
            
            try await cloudKitService.uploadBackup(trips: appViewModel.trips, favorites: appViewModel.favorites, cycles: cycles)
            
            // 重新加載備份列表
            await loadBackupHistory()
            
            await MainActor.run {
                self.successTitle = "上傳成功"
                self.successMessage = "備份已上傳到 iCloud\n\(getCurrentDataSummary())"
                self.showSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "上傳失敗：\(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func performRestore(backupId: String) async {
        await MainActor.run { isExecuting = true }
        defer { Task { await MainActor.run { isExecuting = false } } }
        
        print("🔄 開始恢復備份 ID: \(backupId)")
        
        do {
            let restored = try await cloudKitService.restoreFromBackup(backupId: backupId)
            
            await MainActor.run {
                appViewModel.replaceTripsWith(restored.trips)
                appViewModel.replaceFavoritesWith(restored.favorites)
                
                if var user = auth.currentUser {
                    user.cycles = restored.cycles
                    auth.currentUser = user
                    auth.saveLocalUser()
                }
                
                self.successTitle = "恢復成功"
                self.successMessage = "備份已恢復\n行程: \(restored.trips.count)\n常用路線: \(restored.favorites.count)\n週期: \(restored.cycles.count)"
                self.showSuccessAlert = true
            }
            print("✅ 備份恢復成功 - Trips: \(restored.trips.count), Favorites: \(restored.favorites.count), Cycles: \(restored.cycles.count)")
        } catch {
            await MainActor.run {
                errorMessage = "❌ 恢復失敗\n\(error.localizedDescription)"
                showErrorAlert = true
            }
            print("❌ 備份恢復失敗: \(error.localizedDescription)")
        }
    }
    
    private func performDelete(backupId: String) async {
        await MainActor.run { isExecuting = true }
        defer { Task { await MainActor.run { isExecuting = false } } }
        
        print("🗑️ 開始刪除備份 ID: \(backupId)")
        
        do {
            try await cloudKitService.deleteBackup(backupId: backupId)
            
            await MainActor.run {
                self.successTitle = "刪除成功"
                self.successMessage = "備份已成功刪除"
                self.showSuccessAlert = true
            }
            
            print("✅ 備份刪除成功")
            
            // 重新加載備份列表
            await loadBackupHistory()
        } catch {
            await MainActor.run {
                errorMessage = "❌ 刪除失敗\n\(error.localizedDescription)"
                showErrorAlert = true
            }
            print("❌ 備份刪除失敗: \(error.localizedDescription)")
        }
    }
}
