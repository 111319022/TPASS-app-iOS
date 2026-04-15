import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVManagementView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var auth: AuthService
    // 取得 SwiftData 的 Context，用於匯入寫入
    @Environment(\.modelContext) private var modelContext
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var csvFile: CSVDocument?
    @State private var isToastShowing = false
    @State private var toastMessage: String = ""
    
    var body: some View {
        ZStack {
            // 背景色
            Rectangle()
                .fill(themeManager.backgroundColor)
                .ignoresSafeArea()
            
            List {
                Section {
                    // 匯出按鈕
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("csv_export")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    // 匯入按鈕
                    Button {
                        isImporting = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.green)
                            Text("csv_import")
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                } header: {
                    Text("dataManagement")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("csv_export_footer_1")
                        Text("csv_export_footer_2")
                        Text("csv_export_footer_3")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
            }
            .scrollContentBackground(.hidden)
            
            // Toast 提示（與 TripListView 一致的風格）
            if isToastShowing {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(25)
                        .padding(.bottom, 90)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: isToastShowing)
            }
        }
        .navigationTitle("csv_export_import")
        .navigationBarTitleDisplayMode(.inline)
        // 處理匯出 (分享檔案)
        .sheet(item: $csvFile) { doc in
            ShareSheet(activityItems: [doc.url])
        }
        // 處理匯入 (選擇檔案)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile: URL = try result.get().first else { return }
                guard let userId = auth.currentUser?.id else {
                    showToast(message: String(localized: "user_not_found"))
                    return
                }
                
                // 取得當前用戶的週期列表
                let userCycles = auth.currentUser?.cycles ?? []
                
                // 安全存取權限
                if selectedFile.startAccessingSecurityScopedResource() {
                    defer { selectedFile.stopAccessingSecurityScopedResource() }
                    
                    let result = try CSVManager.shared.importCSV(url: selectedFile, context: modelContext, userId: userId, userCycles: userCycles)
                    
                    // 通知 ViewModel 重新抓取資料
                    Task { @MainActor in
                        viewModel.fetchAllData()
                    }
                    
                    // 🔧 構建包含週期警告的成功訊息
                    var message = String(localized: "csv_import_count \(result.imported)")
                    if result.invalidCycles > 0 {
                        message += "\n" + String(localized: "csv_invalid_cycles_warning \(result.invalidCycles)")
                    }
                    showToast(message: message)
                }
            } catch {
                showToast(message: String(localized: "csv_import_failed"))
            }
        }
    }
    
    func exportData() {
        // 1. 直接從資料庫抓取所有資料（不受 ViewModel 3 個月限制）
        let allTrips: [Trip]
        do {
            let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            allTrips = try modelContext.fetch(descriptor)
        } catch {
            print("❌ 無法抓取所有行程資料: \(error)")
            showToast(message: String(localized: "csv_fetch_failed"))
            return
        }
        
        if allTrips.isEmpty {
            showToast(message: String(localized: "csv_no_data"))
            return
        }
        
        // 2. 產生 CSV 字串
        let csvString = CSVManager.shared.generateCSV(from: allTrips)
        
        // 3. 寫入暫存檔
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "TPASS_Backup_\(dateString).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            csvFile = CSVDocument(url: path)
            showToast(message: String(localized: "csv_export_success"))
        } catch {
            print("建立 CSV 失敗: \(error)")
            showToast(message: String(localized: "csv_export_failed"))
        }
    }
    
    func showToast(message: String) {
        toastMessage = message
        withAnimation { isToastShowing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isToastShowing = false }
        }
    }
}

// 輔助結構：用於 Sheet 顯示分享
struct CSVDocument: Identifiable {
    let id = UUID()
    let url: URL
}

// 輔助 View：呼叫系統分享選單
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CSVManagementView()
        .environmentObject(AppViewModel())
        .environmentObject(ThemeManager())
}
