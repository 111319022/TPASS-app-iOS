import SwiftUI
import CloudKit
import SwiftData

// MARK: - 備份管理頁面
struct BackupManagementView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    //@StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var cloudKitService = CloudKitSyncService.shared

    @State private var isLoadingBackups = false
    @State private var showUploadConfirm = false
    @State private var isExecuting = false
    @State private var pendingAction: PendingAction? = nil
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var successMessage: LocalizedStringKey = "close"
    @State private var successTitle: LocalizedStringKey = "close"
    @State private var showSuccessAlert = false
    
    enum PendingAction: Identifiable {
        case restore(backupId: String, isLegacy: Bool)
        case delete(backupId: String, isLegacy: Bool)
        
        var id: String {
            switch self {
            case .restore(let id, let isLegacy): return "restore-\(id)-\(isLegacy)"
            case .delete(let id, let isLegacy): return "delete-\(id)-\(isLegacy)"
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

                    if cloudKitService.isSyncing, !cloudKitService.uploadProgress.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.75)
                            Text(cloudKitService.uploadProgress)
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
                                    
                                    HStack(spacing: 8) {
                                        compactMetricCell(icon: "figure.walk", count: backup.tripCount)
                                        compactMetricCell(icon: "star.fill", count: backup.favoriteCount)
                                        compactMetricCell(icon: "calendar", count: backup.cycleCount)
                                        compactMetricCell(icon: "figure.walk.motion", count: backup.commuterRouteCount)
                                        compactMetricCell(icon: "house.fill", count: backup.homeStationCount)
                                        compactMetricCell(icon: "arrowshape.turn.up.right.fill", count: backup.outboundStationCount)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Spacer()
                            }
                            
                            HStack(spacing: 8) {
                                Button {
                                    pendingAction = .restore(backupId: backup.id, isLegacy: backup.isLegacy)
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
                                    pendingAction = .delete(backupId: backup.id, isLegacy: backup.isLegacy)
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
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        fullMetricCell(icon: "figure.walk", text: "\(tripCount) trips")
                        fullMetricCell(icon: "star.fill", text: "\(favoriteCount) favorites")
                        fullMetricCell(icon: "calendar", text: "\(cycleCount) cycles")
                    }
                    HStack(spacing: 8) {
                        fullMetricCell(icon: "figure.walk.motion", text: "\(commuterRouteCount) commuter")
                        fullMetricCell(icon: "house.fill", text: "\(homeStationCount) home")
                        fullMetricCell(icon: "arrowshape.turn.up.right.fill", text: "\(outboundStationCount) outbound")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            case .restore(let backupId, let isLegacy):
                return Alert(
                    title: Text("backup_confirm_restore_title"),
                    message: Text("backup_confirm_restore_message"),
                    primaryButton: .destructive(Text("backup_confirm_restore_action")) {
                        Task { await performRestore(backupId: backupId, isLegacy: isLegacy) }
                    },
                    secondaryButton: .cancel()
                )
                
            case .delete(let backupId, let isLegacy):
                return Alert(
                    title: Text("backup_confirm_delete_title"),
                    message: Text("backup_confirm_delete_message"),
                    primaryButton: .destructive(Text("backup_confirm_delete_action")) {
                        Task { await performDelete(backupId: backupId, isLegacy: isLegacy) }
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
            print("📱 BackupManagementView appeared - 全量 Trips: \(tripCount), 近三個月 Trips: \(appViewModel.trips.count), Favorites: \(favoriteCount), Cycles: \(cycleCount)")
            Task {
                await loadBackupHistory()
            }
        }
    }
    
    // MARK: - 輔助函數
    
    private var tripCount: Int {
        do {
            return try modelContext.fetchCount(FetchDescriptor<Trip>())
        } catch {
            print("⚠️ 無法取得全量行程數量：\(error)")
            return appViewModel.trips.count
        }
    }
    private var favoriteCount: Int { appViewModel.favorites.count }
    private var cycleCount: Int { auth.currentUser?.cycles.count ?? 0 }
    private var commuterRouteCount: Int { appViewModel.commuterRoutes.count }
    private var homeStationCount: Int { auth.currentUser?.homeStations.count ?? 0 }
    private var outboundStationCount: Int { auth.currentUser?.outboundStations.count ?? 0 }

    @ViewBuilder
    private func compactMetricCell(icon: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 14)
            Text("\(count)")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func fullMetricCell(icon: String, text: LocalizedStringKey) -> some View {
        Label(text, systemImage: icon)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
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
            let snapshot = await MainActor.run {
                () -> (
                    trips: [TripSnapshot],
                    favorites: [FavoriteRouteSnapshot],
                    cycles: [Cycle],
                    commuterRoutes: [CommuterRoute],
                    homeStations: [HomeStation],
                    outboundStations: [OutboundStation],
                    identity: Identity?,
                    citizenCity: TaiwanCity?,
                    uploadedTripCount: Int
                ) in
                // 🔧 修正：直接從資料庫載入所有歷史行程（不限制時間）
                var allHistoricalTrips: [Trip] = []
                do {
                    let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                    allHistoricalTrips = try self.modelContext.fetch(descriptor)
                    print("✅ 成功從資料庫載入全量歷史行程 \(allHistoricalTrips.count) 筆")
                } catch {
                    print("❌ 無法從資料庫載入行程: \(error)")
                }
                let trips = allHistoricalTrips.map {
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
                        transferDiscountTypeRaw: $0.transferDiscountType?.rawValue,
                        cardId: $0.cardId
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
                let commuterRoutes = appViewModel.commuterRoutes
                let homeStations = auth.currentUser?.homeStations ?? []
                let outboundStations = auth.currentUser?.outboundStations ?? []
                let identity = auth.currentUser?.identity
                let citizenCity = auth.currentUser?.citizenCity
                return (
                    trips,
                    favorites,
                    cycles,
                    commuterRoutes,
                    homeStations,
                    outboundStations,
                    identity,
                    citizenCity,
                    allHistoricalTrips.count
                )
            }
            
            print("📤 準備上傳數據（全量歷史記錄）:")
            print("   全量 Trips: \(snapshot.trips.count)")
            print("   Favorites: \(snapshot.favorites.count)")
            print("   Cycles: \(snapshot.cycles.count)")
            print("   CommuterRoutes: \(snapshot.commuterRoutes.count)")
            print("   HomeStations: \(snapshot.homeStations.count)")
            print("   OutboundStations: \(snapshot.outboundStations.count)")
            
            // 檢查第一筆 Trip 的內容
            if let firstTrip = snapshot.trips.first {
                print("   第一筆 Trip ID: \(firstTrip.id)")
                print("   第一筆 Trip UserID: \(firstTrip.userId)")
            }
            
            try await cloudKitService.uploadBackup(
                trips: snapshot.trips,
                favorites: snapshot.favorites,
                cycles: snapshot.cycles,
                commuterRoutes: snapshot.commuterRoutes,
                homeStations: snapshot.homeStations,
                outboundStations: snapshot.outboundStations,
                identity: snapshot.identity,
                citizenCity: snapshot.citizenCity
            )

            // CloudKit 可能有同步延遲，延遲 1 秒再刷新列表
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await loadBackupHistory()

            await MainActor.run {
                self.successTitle = "backup_upload_success_title"
                self.successMessage = "backup_upload_success_message_v2 \(snapshot.uploadedTripCount) \(favoriteCount) \(cycleCount) \(snapshot.commuterRoutes.count) \(snapshot.homeStations.count) \(snapshot.outboundStations.count)"
                self.showSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "\(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func performRestore(backupId: String, isLegacy: Bool) async {
        await MainActor.run { isExecuting = true }
        defer { Task { await MainActor.run { isExecuting = false } } }
        
        print("🔄 開始恢復備份 ID: \(backupId), legacy: \(isLegacy)")
        
        do {
            let restored = try await cloudKitService.restoreFromBackup(backupId: backupId, isLegacy: isLegacy)
            
            await MainActor.run {
                appViewModel.replaceTripsWith(restored.trips)
                appViewModel.replaceFavoritesWith(restored.favorites)
                if !isLegacy {
                    appViewModel.replaceCommuterRoutesWith(restored.commuterRoutes ?? [])
                }
                
                if var user = auth.currentUser {
                    // 🔧 按照日期排序週期（最新的在最前面）
                    user.cycles = restored.cycles.sorted { $0.start > $1.start }
                    if !isLegacy {
                        user.homeStations = restored.homeStations ?? []
                        user.outboundStations = restored.outboundStations ?? []
                        if let restoredIdentity = restored.identity {
                            user.identity = restoredIdentity
                        }
                        user.citizenCity = restored.citizenCity
                    }
                    auth.currentUser = user
                    auth.saveLocalUser()
                }

                let restoredCommuterCount = isLegacy
                    ? appViewModel.commuterRoutes.count
                    : (restored.commuterRoutes?.count ?? appViewModel.commuterRoutes.count)
                let restoredHomeCount = auth.currentUser?.homeStations.count ?? 0
                let restoredOutboundCount = auth.currentUser?.outboundStations.count ?? 0
                
                self.successTitle = "backup_restore_success_title"
                self.successMessage = "backup_restore_success_message_v2 \(restored.trips.count) \(restored.favorites.count) \(restored.cycles.count) \(restoredCommuterCount) \(restoredHomeCount) \(restoredOutboundCount)"
                self.showSuccessAlert = true
            }
            let restoredCommuterCount = restored.commuterRoutes?.count ?? appViewModel.commuterRoutes.count
            let restoredHomeCount = restored.homeStations?.count ?? auth.currentUser?.homeStations.count ?? 0
            let restoredOutboundCount = restored.outboundStations?.count ?? auth.currentUser?.outboundStations.count ?? 0
            let restoredIdentity = restored.identity?.rawValue ?? auth.currentUser?.identity.rawValue ?? "(unchanged)"
            let restoredCitizen = restored.citizenCity?.rawValue ?? auth.currentUser?.citizenCity?.rawValue ?? "(unchanged)"
            print(
                "✅ 備份恢復成功 [\(isLegacy ? "LEGACY" : "V2")] - Trips: \(restored.trips.count), Favorites: \(restored.favorites.count), Cycles: \(restored.cycles.count), CommuterRoutes: \(restoredCommuterCount), HomeStations: \(restoredHomeCount), OutboundStations: \(restoredOutboundCount), Identity: \(restoredIdentity), CitizenCity: \(restoredCitizen)"
            )
        } catch {
            await MainActor.run {
                errorMessage = "\(error.localizedDescription)"
                showErrorAlert = true
            }
            print("❌ 備份恢復失敗: \(error.localizedDescription)")
        }
    }
    
    private func performDelete(backupId: String, isLegacy: Bool) async {
        await MainActor.run { isExecuting = true }
        defer { Task { await MainActor.run { isExecuting = false } } }
        
        print("🗑️ 開始刪除備份 ID: \(backupId), legacy: \(isLegacy)")
        
        do {
            try await cloudKitService.deleteBackup(backupId: backupId, isLegacy: isLegacy)
            
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
