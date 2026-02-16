import SwiftUI
import CloudKit

// MARK: - 備份管理頁面
struct BackupManagementView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var themeManager = ThemeManager.shared
    //@StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var cloudKitService = CloudKitSyncService.shared

    @State private var isLoadingBackups = false
    @State private var showUploadConfirm = false
    @State private var isExecuting = false
    @State private var selectedBackupId: String? = nil
    @State private var pendingAction: PendingAction? = nil
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var successMessage: LocalizedStringKey = "close"
    @State private var successTitle: LocalizedStringKey = "close"
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
            Section(header: Text("backup_upload_section_title")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("backup_upload_section_desc")
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
                            Text("backup_upload_now")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .disabled(cloudKitService.isSyncing || isExecuting)
                    
                    if let lastSync = cloudKitService.lastSyncDate {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("backup_last_upload \(formatDate(lastSync))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - 下載備份區塊
            Section(header: HStack {
                Text("backup_restore_section_title")
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
                                        Text("backup_restore")
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
                                        Text("delete")
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
            Section(footer:
                VStack(alignment: .leading, spacing: 0) {
                    Text("backup_footer")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer().frame(height: 15)
                }
            ) {
                EmptyView()
            }
        }
        .navigationTitle("backup_nav_title")
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.backgroundColor)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showUploadConfirm) {
            VStack(spacing: 16) {
                Capsule().frame(width: 40, height: 5).foregroundColor(.secondary.opacity(0.3))
                Text("backup_sheet_title")
                    .font(.title3.bold())
                    .foregroundColor(themeManager.primaryTextColor)
                HStack(spacing: 12) {
                    Label("\(tripCount) trips", systemImage: "figure.walk")
                    Label("\(favoriteCount) favorites", systemImage: "star.fill")
                    Label("\(cycleCount) cycles", systemImage: "calendar")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                
                Button {
                    showUploadConfirm = false
                    Task { await performUpload() }
                } label: {
                    Text("backup_upload")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.accentColor)
                        .cornerRadius(12)
                }
                .disabled(cloudKitService.isSyncing || isExecuting)
                Button("cancel", role: .cancel) {
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
                    title: Text("backup_confirm_restore_title"),
                    message: Text("backup_confirm_restore_message"),
                    primaryButton: .destructive(Text("backup_confirm_restore_action")) {
                        Task { await performRestore(backupId: backupId) }
                    },
                    secondaryButton: .cancel()
                )
                
            case .delete(let backupId):
                return Alert(
                    title: Text("backup_confirm_delete_title"),
                    message: Text("backup_confirm_delete_message"),
                    primaryButton: .destructive(Text("backup_confirm_delete_action")) {
                        Task { await performDelete(backupId: backupId) }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .alert(successTitle == "close" ? "backup_operation_success" : successTitle, isPresented: $showSuccessAlert) {
            Button("confirm") {}
        } message: {
            Text(successMessage)
        }
        .alert("backup_operation_failed", isPresented: $showErrorAlert) {
            Button("confirm") {}
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
        let canStart = await MainActor.run { !cloudKitService.isSyncing && !isExecuting }
        guard canStart else { return }

        do {
            let snapshot = await MainActor.run { () -> (trips: [TripSnapshot], favorites: [FavoriteRouteSnapshot], cycles: [Cycle]) in
                let trips = appViewModel.trips.map {
                    TripSnapshot(
                        id: $0.id,
                        userId: $0.userId,
                        createdAt: $0.createdAt,
                        typeRaw: $0.type.rawValue,
                        originalPrice: $0.originalPrice,
                        paidPrice: $0.paidPrice,
                        isTransfer: $0.isTransfer,
                        isFree: $0.isFree,
                        startStation: $0.startStation,
                        endStation: $0.endStation,
                        routeId: $0.routeId,
                        note: $0.note,
                        cycleId: $0.cycleId,
                        transferDiscountTypeRaw: $0.transferDiscountType?.rawValue
                    )
                }
                let favorites = appViewModel.favorites.map {
                    FavoriteRouteSnapshot(
                        id: $0.id,
                        typeRaw: $0.type.rawValue,
                        startStation: $0.startStation,
                        endStation: $0.endStation,
                        routeId: $0.routeId,
                        price: $0.price,
                        isTransfer: $0.isTransfer,
                        isFree: $0.isFree
                    )
                }
                let cycles = auth.currentUser?.cycles ?? []
                return (trips, favorites, cycles)
            }
            
            print("📤 準備上傳數據:")
            print("   Trips: \(snapshot.trips.count)")
            print("   Favorites: \(snapshot.favorites.count)")
            print("   Cycles: \(snapshot.cycles.count)")
            
            // 檢查第一筆 Trip 的內容
            if let firstTrip = snapshot.trips.first {
                print("   第一筆 Trip ID: \(firstTrip.id)")
                print("   第一筆 Trip UserID: \(firstTrip.userId)")
            }
            
            try await cloudKitService.uploadBackup(trips: snapshot.trips, favorites: snapshot.favorites, cycles: snapshot.cycles)

            // CloudKit 可能有同步延遲，延遲 1 秒再刷新列表
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await loadBackupHistory()

            await MainActor.run {
                self.successTitle = "backup_upload_success_title"
                self.successMessage = "backup_upload_success_message \(tripCount) \(favoriteCount) \(cycleCount)"
                self.showSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "\(error.localizedDescription)"
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
                    // 🔧 按照日期排序週期（最新的在最前面）
                    user.cycles = restored.cycles.sorted { $0.start > $1.start }
                    auth.currentUser = user
                    auth.saveLocalUser()
                }
                
                self.successTitle = "backup_restore_success_title"
                self.successMessage = "backup_restore_success_message \(restored.trips.count) \(restored.favorites.count) \(restored.cycles.count)"
                self.showSuccessAlert = true
            }
            print("✅ 備份恢復成功 - Trips: \(restored.trips.count), Favorites: \(restored.favorites.count), Cycles: \(restored.cycles.count)")
        } catch {
            await MainActor.run {
                errorMessage = "\(error.localizedDescription)"
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
                self.successTitle = "backup_delete_success_title"
                self.successMessage = "backup_delete_success_message"
                self.showSuccessAlert = true
            }
            
            print("✅ 備份刪除成功")
            
            // 重新加載備份列表
            await loadBackupHistory()
        } catch {
            await MainActor.run {
                errorMessage = "\(error.localizedDescription)"
                showErrorAlert = true
            }
            print("❌ 備份刪除失敗: \(error.localizedDescription)")
        }
    }
}
