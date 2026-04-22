import SwiftUI

/// 語音快速記錄行程 — 獨立入口頁面
/// V1：錄音 → 轉寫 → 解析 → 草稿預覽 → 確認建立 Trip
struct VoiceQuickTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    @StateObject private var voiceService = VoiceInputService()
    
    // MARK: - 狀態
    enum ViewPhase {
        case ready          // 準備錄音
        case recording      // 錄音中
        case parsing        // 解析中
        case preview        // 草稿預覽
        case permissionDenied // 權限被拒
        case fallbackManual // 低信心，轉手動
    }
    
    @State private var phase: ViewPhase = .ready
    @State private var draft: VoiceDraft?
    @State private var showMultiSegmentAlert = false
    @State private var showSaveSuccess = false
    
    // 使用者手動修正欄位
    @State private var editedTransportType: TransportType?
    @State private var editedStartStation: String = ""
    @State private var editedEndStation: String = ""
    @State private var editedStartLineCode: String = ""
    @State private var editedEndLineCode: String = ""
    @State private var editedPrice: String = ""
    @State private var editedRouteId: String = ""
    @State private var editedNote: String = ""
    @State private var editedDate: Date = Date()
    @State private var useCurrentTime: Bool = true
    @State private var isTransfer: Bool = false
    @State private var isFree: Bool = false
    @State private var transferDiscountType: TransferDiscountType? = nil
    @State private var showTransferTypePicker: Bool = false
    @State private var isHSRNonReserved: Bool = false
    
    // TRA 選擇狀態
    @State private var startTRARegion: TRARegion?
    @State private var endTRARegion: TRARegion?
    
    // 解析中旗標，避免 onChange 清空站名
    @State private var isPopulatingFromParse: Bool = false
    
    var onSuccess: (() -> Void)? = nil
    
    private var currentRegion: TPASSRegion {
        viewModel.activeCycle?.region ?? auth.currentRegion
    }
    
    private var currentCycleId: String? {
        viewModel.activeCycle?.id
    }
    
    private var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
    }
    
    private var currentSupportedModes: [TransportType] {
        viewModel.activeCycle?.effectiveSupportedModes ?? currentRegion.supportedModes
    }
    
    private var availableTRARegions: [TRARegion] {
        TRAStationData.shared.getRegions(for: currentRegion)
    }
    
    private var filteredTransferTypes: [TransferDiscountType] {
        let allTypes = currentRegion.supportedTransferTypes
        guard let userCity = auth.currentUser?.citizenCity else { return allTypes }
        return allTypes.filter { type in
            if let required = type.citizenRequirement { return required == userCity }
            return true
        }
    }
    
    // 輸入框背景色
    private var inputBackground: Color {
        let isDark: Bool = {
            switch themeManager.currentTheme {
            case .dark: return true
            case .light, .muji, .purple: return false
            case .system: return UITraitCollection.current.userInterfaceStyle == .dark
            }
        }()
        return isDark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .ready:
                            readyPhaseContent
                        case .recording:
                            recordingPhaseContent
                        case .parsing:
                            parsingPhaseContent
                        case .preview:
                            previewPhaseContent
                        case .permissionDenied:
                            permissionDeniedContent
                        case .fallbackManual:
                            fallbackManualContent
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("voice_quick_trip_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("voice_multi_segment_title", isPresented: $showMultiSegmentAlert) {
            Button("ok", role: .cancel) {
                phase = .fallbackManual
            }
        } message: {
            Text("voice_multi_segment_message")
        }
        .onAppear {
            checkPermissions()
        }
    }
    
    // MARK: - 準備錄音
    
    private var readyPhaseContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(themeManager.accentColor)
                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 10)
            
            Text("voice_ready_title")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("voice_ready_subtitle")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // 範例提示
            VStack(alignment: .leading, spacing: 8) {
                Text("voice_example_header")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                ForEach(examplePhrases, id: \.self) { phrase in
                    HStack(spacing: 6) {
                        Image(systemName: "text.quote")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor)
                        Text(phrase)
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
            .padding(16)
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.secondaryTextColor.opacity(0.1), lineWidth: 1)
            )
            
            Spacer().frame(height: 20)
            
            // 錄音按鈕
            Button(action: startRecording) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .bold))
                    Text("voice_start_recording")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 40)
                .background(themeManager.accentColor)
                .cornerRadius(30)
                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private var examplePhrases: [String] {
        [
            "「搭捷運從台北車站到市政府 25 元」",
            "「昨天坐公車 307 花了 15 元」",
            "「高鐵台北到台中」",
        ]
    }
    
    // MARK: - 錄音中
    
    private var recordingPhaseContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 30)
            
            // 錄音動畫指示
            ZStack {
                // 脈衝環
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(voiceService.state == .recording ? 1.3 : 1.0)
                    .opacity(voiceService.state == .recording ? 0.0 : 0.5)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: voiceService.state)
                
                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            // 計時器
            Text(timerDisplay)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(themeManager.primaryTextColor)
            
            // 進度條（55秒限制）
            ProgressView(value: Double(voiceService.elapsedSeconds), total: Double(VoiceInputService.maxDuration))
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .padding(.horizontal, 40)
            
            Text("voice_listening")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
            
            // 即時轉寫文字
            if !voiceService.transcript.isEmpty {
                Text(voiceService.transcript)
                    .font(.body)
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(12)
            }
            
            Spacer().frame(height: 20)
            
            // 停止按鈕
            Button(action: stopRecording) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("voice_stop_recording")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 40)
                .background(Color.red)
                .cornerRadius(30)
                .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .onChange(of: voiceService.state) { _, newState in
            // 當 voiceService 自動停止（55秒到達）時觸發解析
            if newState == .idle && phase == .recording {
                parseTranscript()
            }
        }
    }
    
    private var timerDisplay: String {
        let minutes = voiceService.elapsedSeconds / 60
        let seconds = voiceService.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var progressColor: Color {
        if voiceService.elapsedSeconds >= 50 { return .red }
        if voiceService.elapsedSeconds >= 40 { return .orange }
        return themeManager.accentColor
    }
    
    // MARK: - 解析中
    
    private var parsingPhaseContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.accentColor))
                .scaleEffect(1.5)
            
            Text("voice_parsing")
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            
            if !voiceService.transcript.isEmpty {
                Text(voiceService.transcript)
                    .font(.body)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 草稿預覽
    
    private var previewPhaseContent: some View {
        VStack(spacing: 16) {
            // 信心指示
            confidenceIndicator
            
            // 原始轉寫
            VStack(alignment: .leading, spacing: 6) {
                Text("voice_original_transcript")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                Text(draft?.originalTranscript ?? "")
                    .font(.body)
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(10)
            }
            
            Divider()
            
            // 可編輯欄位
            editableFieldsSection
            
            Spacer().frame(height: 10)
            
            // 操作按鈕
            VStack(spacing: 12) {
                // 確認儲存
                Button(action: saveDraftAsTrip) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("voice_confirm_save")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? themeManager.accentColor : Color.gray.opacity(0.4))
                    .cornerRadius(12)
                }
                .disabled(!canSave)
                
                // 重新錄音
                Button(action: retryRecording) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("voice_retry")
                    }
                    .foregroundColor(themeManager.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // 轉手動輸入
                Button(action: { dismiss() }) {
                    Text("voice_switch_manual")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
    }
    
    private var canSave: Bool {
        editedTransportType != nil &&
        !editedStartStation.isEmpty &&
        !editedEndStation.isEmpty &&
        (Int(editedPrice) != nil || editedPrice.isEmpty)
    }
    
    // MARK: - 信心指示器
    
    private var confidenceIcon: String {
        let score = draft?.overallScore ?? 0
        if score >= 0.85 { return "checkmark.circle.fill" }
        if score >= 0.65 { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }
    
    private var confidenceColor: Color {
        let score = draft?.overallScore ?? 0
        if score >= 0.85 { return .green }
        if score >= 0.65 { return .orange }
        return .red
    }
    
    private var confidenceText: LocalizedStringKey {
        let score = draft?.overallScore ?? 0
        if score >= 0.85 { return "voice_confidence_high" }
        if score >= 0.65 { return "voice_confidence_medium" }
        return "voice_confidence_low"
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: confidenceIcon)
                .foregroundColor(confidenceColor)
                .font(.title3)
            
            Text(confidenceText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.primaryTextColor)
            
            Spacer()
            
            Text(String(format: "%.0f%%", (draft?.overallScore ?? 0) * 100))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(confidenceColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor.opacity(0.15))
                .cornerRadius(6)
        }
        .padding(12)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - 可編輯欄位
    
    private var editableFieldsSection: some View {
        VStack(spacing: 12) {
            // 運具選擇（使用目前方案支援的運具）
            fieldRow(label: "voice_field_transport", warningLevel: draft?.transportScore) {
                Picker("", selection: $editedTransportType) {
                    Text("voice_select_transport").tag(TransportType?.none)
                    ForEach(currentSupportedModes) { type in
                        Text(type.displayName).tag(TransportType?.some(type))
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.primaryTextColor)
            }
            .onChange(of: editedTransportType) { _, newType in
                handleTransportTypeChange(newType)
            }
            
            // 路線 (公車/客運)
            if editedTransportType == .bus || editedTransportType == .coach {
                fieldRow(label: "voice_field_route") {
                    TextField("voice_route_placeholder", text: $editedRouteId)
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }
            
            // 起迄站選擇（使用既有站點選擇器元件）
            stationSelectionSection
            
            // 票價 + 轉乘/免費/高鐵自由座
            priceAndOptionsSection
            
            // 日期
            fieldRow(label: "voice_field_date", warningLevel: draft?.timeScore) {
                DatePicker("", selection: $editedDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(themeManager.accentColor)
            }
            
            // 備註
            fieldRow(label: "voice_field_note") {
                TextField("voice_note_placeholder", text: $editedNote)
                    .foregroundColor(themeManager.primaryTextColor)
            }
        }
        .onChange(of: editedStartStation) { _, _ in handleStationFieldsChanged() }
        .onChange(of: editedEndStation) { _, _ in handleStationFieldsChanged() }
        .onChange(of: editedRouteId) { _, _ in autoFillFare() }
    }
    
    // MARK: - 站點選擇區塊（重用既有 StationInputRow）
    
    @ViewBuilder
    private var stationSelectionSection: some View {
        if let type = editedTransportType {
            VStack(spacing: 0) {
                switch type {
                case .bus:
                    // 公車：手動輸入起迄站
                    VStack(spacing: 0) {
                        StationInputRow(
                            label: "start_point",
                            type: type,
                            lineCode: $editedStartLineCode,
                            stationName: $editedStartStation,
                            currentRegion: currentRegion
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        StationInputRow(
                            label: "end_point",
                            type: type,
                            lineCode: $editedEndLineCode,
                            stationName: $editedEndStation,
                            currentRegion: currentRegion
                        )
                    }
                    
                case .coach:
                    VStack(spacing: 0) {
                        StationInputRow(
                            label: "start_point",
                            type: type,
                            lineCode: $editedStartLineCode,
                            stationName: $editedStartStation,
                            currentRegion: currentRegion
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        StationInputRow(
                            label: "end_point",
                            type: type,
                            lineCode: $editedEndLineCode,
                            stationName: $editedEndStation,
                            currentRegion: currentRegion
                        )
                    }
                    
                case .tra:
                    VStack(spacing: 0) {
                        TRALineStationInputRow(
                            label: "start_point",
                            regions: availableTRARegions,
                            selectedRegion: $startTRARegion,
                            stationId: $editedStartStation
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        TRALineStationInputRow(
                            label: "end_point",
                            regions: availableTRARegions,
                            selectedRegion: $endTRARegion,
                            stationId: $editedEndStation
                        )
                    }
                    .onAppear {
                        if availableTRARegions.count == 1 {
                            if startTRARegion == nil { startTRARegion = availableTRARegions.first }
                            if endTRARegion == nil { endTRARegion = availableTRARegions.first }
                        }
                    }
                    
                case .lrt:
                    VStack(spacing: 0) {
                        StationInputRow(
                            label: "start_point",
                            type: .lrt,
                            lineCode: $editedStartLineCode,
                            stationName: $editedStartStation,
                            currentRegion: currentRegion,
                            lineSelectionEnabled: true
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        StationInputRow(
                            label: "end_point",
                            type: .lrt,
                            lineCode: Binding(get: { editedStartLineCode }, set: { _ in }),
                            stationName: $editedEndStation,
                            currentRegion: currentRegion,
                            lineSelectionEnabled: false
                        )
                    }
                    .onChange(of: editedStartLineCode) { _, newLineCode in
                        editedEndLineCode = newLineCode
                        let availableLines = LRTStationData.shared.availableLines(for: currentRegion)
                        guard let selectedLine = availableLines.first(where: { $0.code == newLineCode }) else {
                            editedEndStation = ""
                            return
                        }
                        if !editedEndStation.isEmpty, !selectedLine.stations.contains(where: { $0.nameZH == editedEndStation }) {
                            editedEndStation = ""
                        }
                    }
                    
                default:
                    // MRT, TYMRT, TCMRT, KMRT, HSR 等使用通用站點選擇
                    VStack(spacing: 0) {
                        StationInputRow(
                            label: "start_point",
                            type: type,
                            lineCode: $editedStartLineCode,
                            stationName: $editedStartStation,
                            currentRegion: currentRegion
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        StationInputRow(
                            label: "end_point",
                            type: type,
                            lineCode: $editedEndLineCode,
                            stationName: $editedEndStation,
                            currentRegion: currentRegion
                        )
                    }
                }
            }
            .background(inputBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        }
    }
    
    // MARK: - 票價與選項區塊
    
    private var priceAndOptionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // 票價輸入
                HStack {
                    Text("$")
                        .font(.headline)
                        .foregroundColor(themeManager.secondaryTextColor)
                    TextField("price_placeholder", text: $editedPrice)
                        .keyboardType(.numberPad)
                        .font(.title3.bold())
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .frame(height: 50)
                .padding(.horizontal, 12)
                .background(inputBackground)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                
                // 高鐵：自由座切換 / 其他：轉乘按鈕
                if editedTransportType == .hsr {
                    Button(action: {
                        isHSRNonReserved.toggle()
                        isFree = false
                        isTransfer = false
                        transferDiscountType = nil
                        autoFillFare()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isHSRNonReserved ? "checkmark.circle.fill" : "circle")
                            Text("non_reserved_seat")
                                .font(.subheadline).fontWeight(.bold)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 12)
                        .background(isHSRNonReserved ? Color(hex: "#27ae60") : inputBackground)
                        .foregroundColor(isHSRNonReserved ? .white : themeManager.secondaryTextColor)
                        .cornerRadius(10)
                    }
                    .frame(height: 50)
                } else {
                    voiceTransferButton
                        .frame(height: 50)
                        .confirmationDialog("transfer", isPresented: $showTransferTypePicker) {
                            ForEach(filteredTransferTypes) { type in
                                Button(action: {
                                    isTransfer = true
                                    transferDiscountType = type
                                }) {
                                    HStack {
                                        Text(type.displayNameKey(for: currentIdentity))
                                        if transferDiscountType == type {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            Button("cancel_transfer", role: .destructive) {
                                isTransfer = false
                                transferDiscountType = nil
                            }
                        }
                }
            }
            
            // 免費 + 備註
            HStack(spacing: 12) {
                Button(action: { isFree.toggle() }) {
                    HStack {
                        Image(systemName: isFree ? "gift.fill" : "gift")
                        Text("free_trip")
                            .font(.subheadline).fontWeight(.medium)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(isFree ? themeManager.accentColor : inputBackground)
                    .foregroundColor(isFree ? .white : themeManager.secondaryTextColor)
                    .cornerRadius(8)
                }
                
                // 自動查價狀態提示
                if !editedPrice.isEmpty, let price = Int(editedPrice), price > 0 {
                    Text("voice_auto_fare_hint")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .onChange(of: isFree) { _, val in
                if val {
                    isTransfer = false
                    transferDiscountType = nil
                    editedPrice = "0"
                }
            }
            .onChange(of: isTransfer) { _, val in
                if val {
                    isFree = false
                    if transferDiscountType == nil {
                        transferDiscountType = currentRegion.defaultTransferType
                    }
                } else {
                    transferDiscountType = nil
                }
            }
        }
    }
    
    // 轉乘按鈕
    private var voiceTransferButton: some View {
        Button(action: {
            if isTransfer {
                isTransfer = false
                transferDiscountType = nil
            } else {
                if filteredTransferTypes.count == 1, let only = filteredTransferTypes.first {
                    isTransfer = true
                    transferDiscountType = only
                } else {
                    showTransferTypePicker = true
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isTransfer ? "arrow.triangle.swap" : "arrow.triangle.swap")
                Text(isTransfer ? (transferDiscountType?.displayNameKey(for: currentIdentity) ?? "transfer") : "transfer")
                    .font(.subheadline).fontWeight(.bold)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 10)
            .background(isTransfer ? Color(hex: "#27ae60") : inputBackground)
            .foregroundColor(isTransfer ? .white : themeManager.secondaryTextColor)
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private func fieldRow<Content: View>(
        label: LocalizedStringKey,
        warningLevel: Double? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            // 信心警示點
            if let level = warningLevel, level < 0.7 {
                Circle()
                    .fill(level < 0.4 ? Color.red : Color.orange)
                    .frame(width: 8, height: 8)
            }
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(width: 50, alignment: .leading)
            
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(inputBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - 權限被拒
    
    private var permissionDeniedContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            
            Image(systemName: "mic.slash.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("voice_permission_denied_title")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("voice_permission_denied_message")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: openSettings) {
                Text("voice_open_settings")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(themeManager.accentColor)
                    .cornerRadius(10)
            }
            
            Button(action: { dismiss() }) {
                Text("voice_use_manual_instead")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 低信心 Fallback
    
    private var fallbackManualContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("voice_fallback_title")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryTextColor)
            
            Text("voice_fallback_message")
                .font(.subheadline)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if !voiceService.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("voice_original_transcript")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text(voiceService.transcript)
                        .font(.body)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.cardBackgroundColor)
                .cornerRadius(12)
            }
            
            Button(action: retryRecording) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("voice_retry")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 30)
                .background(themeManager.accentColor)
                .cornerRadius(10)
            }
            
            Button(action: { dismiss() }) {
                Text("voice_switch_manual")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 動作
    
    private func checkPermissions() {
        if !voiceService.isAuthorized {
            Task {
                let granted = await voiceService.requestPermissions()
                if !granted {
                    phase = .permissionDenied
                }
            }
        }
    }
    
    private func startRecording() {
        HapticManager.shared.impact(style: .light)
        voiceService.startRecording()
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .recording
        }
    }
    
    private func stopRecording() {
        voiceService.stopRecording()
        parseTranscript()
    }
    
    private func parseTranscript() {
        let text = voiceService.transcript
        guard !text.isEmpty else {
            withAnimation {
                phase = .fallbackManual
            }
            HapticManager.shared.notification(type: .warning)
            return
        }
        
        withAnimation {
            phase = .parsing
        }
        
        // 解析（在主執行緒上，因為需要存取 @MainActor 的站名資料）
        let parsed = TripVoiceParser.parse(text)
        let newDraft = VoiceDraft.from(parsed: parsed, transcript: text)
        
        draft = newDraft
        
        // 填入可編輯欄位（抑制 onChange 的 handleTransportTypeChange）
        isPopulatingFromParse = true
        
        editedRouteId = newDraft.routeId ?? ""
        editedNote = newDraft.note ?? ""
        editedDate = newDraft.tripDate ?? Date()
        
        // 設定運具
        editedTransportType = newDraft.transportType
        
        // 設定站名
        editedStartStation = newDraft.startStation ?? ""
        editedEndStation = newDraft.endStation ?? ""
        applyParsedSelectionMetadata()
        
        // 設定台中捷運預設線路
        if newDraft.transportType == .tcmrt {
            editedStartLineCode = "GREEN"
            editedEndLineCode = "GREEN"
        }
        
        // 票價：若語音有說出價格就用，否則嘗試自動查價
        if let voicePrice = newDraft.price {
            editedPrice = String(voicePrice)
        } else {
            autoFillFare()
        }
        
        isPopulatingFromParse = false
        
        // 判斷多段行程
        if parsed.stationScore == 0.0 && (text.contains("轉") || text.contains("再搭")) {
            showMultiSegmentAlert = true
            HapticManager.shared.notification(type: .warning)
            return
        }
        
        // 根據信心分數決定流程
        if parsed.isLowConfidence || !parsed.hasRequiredFields {
            withAnimation {
                phase = .fallbackManual
            }
            HapticManager.shared.notification(type: .warning)
        } else {
            withAnimation {
                phase = .preview
            }
            if parsed.isHighConfidence {
                HapticManager.shared.notification(type: .success)
            }
        }
    }

    /// 站點變更後，先推回線路再做查價
    private func handleStationFieldsChanged() {
        guard !isPopulatingFromParse else { return }
        applyParsedSelectionMetadata()
        autoFillFare()
    }

    /// 根據目前運具與站點回填線路/區域等輔助欄位
    private func applyParsedSelectionMetadata() {
        guard let type = editedTransportType else { return }

        switch type {
        case .mrt:
            if let startLine = StationData.shared.lines.first(where: { $0.stations.contains(editedStartStation) }) {
                editedStartLineCode = startLine.code
            }
            if let endLine = StationData.shared.lines.first(where: { $0.stations.contains(editedEndStation) }) {
                editedEndLineCode = endLine.code
            }

        case .kmrt:
            if let startLine = KMRTStationData.shared.lines.first(where: { $0.stations.contains(editedStartStation) }) {
                editedStartLineCode = startLine.code
            }
            if let endLine = KMRTStationData.shared.lines.first(where: { $0.stations.contains(editedEndStation) }) {
                editedEndLineCode = endLine.code
            }

        case .tcmrt:
            if let startLine = TCMRTStationData.shared.lines.first(where: { $0.stations.contains(editedStartStation) }) {
                editedStartLineCode = startLine.code
            } else if editedStartLineCode.isEmpty {
                editedStartLineCode = "GREEN"
            }

            if let endLine = TCMRTStationData.shared.lines.first(where: { $0.stations.contains(editedEndStation) }) {
                editedEndLineCode = endLine.code
            } else if editedEndLineCode.isEmpty {
                editedEndLineCode = editedStartLineCode.isEmpty ? "GREEN" : editedStartLineCode
            }

        case .lrt:
            let availableLines = LRTStationData.shared.availableLines(for: currentRegion)
            if let startLine = availableLines.first(where: { $0.stations.contains(where: { $0.nameZH == editedStartStation }) }) {
                editedStartLineCode = startLine.code
            } else if let endLine = availableLines.first(where: { $0.stations.contains(where: { $0.nameZH == editedEndStation }) }) {
                editedStartLineCode = endLine.code
            }

            if !editedStartLineCode.isEmpty {
                editedEndLineCode = editedStartLineCode
            }

        case .tra:
            if let startId = TRAStationData.shared.resolveStationID(editedStartStation) {
                editedStartStation = startId
            }
            if let endId = TRAStationData.shared.resolveStationID(editedEndStation) {
                editedEndStation = endId
            }

            let regions = availableTRARegions
            if let startRegion = regions.first(where: { region in
                region.stations.contains(where: { $0.id == editedStartStation })
            }) {
                startTRARegion = startRegion
            }
            if let endRegion = regions.first(where: { region in
                region.stations.contains(where: { $0.id == editedEndStation })
            }) {
                endTRARegion = endRegion
            }

        default:
            break
        }
    }
    
    private func saveDraftAsTrip() {
        guard let userId = auth.currentUser?.id,
              let transportType = editedTransportType else { return }
        
        let originalPrice = Int(editedPrice) ?? 0
        let paidPrice = calculatePaidPrice(originalPrice: originalPrice)
        
        let newTrip = Trip(
            id: UUID().uuidString,
            userId: userId,
            createdAt: editedDate,
            type: transportType,
            originalPrice: originalPrice,
            paidPrice: paidPrice,
            isTransfer: isTransfer,
            isFree: isFree,
            startStation: editedStartStation,
            endStation: editedEndStation,
            routeId: editedRouteId,
            note: editedNote,
            transferDiscountType: transferDiscountType,
            cycleId: currentCycleId
        )
        
        viewModel.addTrip(newTrip)
        HapticManager.shared.notification(type: .success)
        
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSuccess?()
        }
    }
    
    /// 計算實付金額（與 AddTripView 相同邏輯）
    private func calculatePaidPrice(originalPrice: Int) -> Int {
        if isFree { return 0 }
        let discount: Int
        if isTransfer, let type = transferDiscountType {
            discount = type.discount(for: currentIdentity)
        } else {
            discount = 0
        }
        return max(0, originalPrice - discount)
    }
    
    /// 運具切換時重設相關欄位
    private func handleTransportTypeChange(_ newType: TransportType?) {
        guard let newType else { return }
        // 解析填入中不重設，避免清空語音辨識出的站名
        guard !isPopulatingFromParse else { return }
        
        // 重設站點
        editedStartStation = ""
        editedEndStation = ""
        editedStartLineCode = ""
        editedEndLineCode = ""
        startTRARegion = nil
        endTRARegion = nil
        isHSRNonReserved = false
        
        // 台中捷運預設綠線
        if newType == .tcmrt {
            editedStartLineCode = "GREEN"
            editedEndLineCode = "GREEN"
        }
        
        // 高鐵不支援轉乘
        if newType == .hsr {
            isTransfer = false
            transferDiscountType = nil
        }
        
        // 公車預設票價
        if newType == .bus {
            editedPrice = currentRegion.defaultBusPrice(identity: currentIdentity)
        } else {
            editedPrice = ""
        }
        
        // 客運保留 routeId，其他清空
        if newType != .coach && newType != .bus {
            editedRouteId = ""
        }
    }
    
    /// 自動查價（重用既有 FareService）
    private func autoFillFare() {
        guard let type = editedTransportType,
              !editedStartStation.isEmpty,
              !editedEndStation.isEmpty else { return }
        
        switch type {
        case .mrt:
            if let fare = TPEMRTFareService.shared.getFare(from: editedStartStation, to: editedEndStation) {
                editedPrice = String(fare)
            }
        case .tymrt:
            // 桃園市民七折優先
            if auth.currentUser?.citizenCity == .taoyuan,
               let citizenFare = TYMRTFareService.shared.getCitizenFare(from: editedStartStation, to: editedEndStation) {
                editedPrice = String(citizenFare)
            } else if let fare = TYMRTFareService.shared.getFare(from: editedStartStation, to: editedEndStation) {
                editedPrice = String(fare)
            }
        case .tcmrt:
            if let fare = TCMRTFareService.shared.getFare(from: editedStartStation, to: editedEndStation) {
                editedPrice = String(fare)
            }
        case .kmrt:
            if let fare = KMRTFareService.shared.getFare(from: editedStartStation, to: editedEndStation) {
                editedPrice = String(fare)
            }
        case .lrt:
            let lineCode = editedStartLineCode.isEmpty ? editedEndLineCode : editedStartLineCode
            if !lineCode.isEmpty,
               let fare = LRTFareService.shared.getFare(lineCode: lineCode, from: editedStartStation, to: editedEndStation) {
                editedPrice = String(fare)
            }
        case .tra:
            let fare = TRAFareService.shared.getFare(from: editedStartStation, to: editedEndStation)
            if fare > 0 {
                editedPrice = String(fare)
            }
        case .hsr:
            if let fare = THSRFareService.shared.getFare(from: editedStartStation, to: editedEndStation, isNonReserved: isHSRNonReserved) {
                editedPrice = String(fare)
            }
        case .bus:
            // 公車以路線查歷史
            if !editedRouteId.isEmpty {
                if let match = viewModel.trips.first(where: { $0.type == .bus && $0.routeId == editedRouteId }) {
                    editedPrice = String(match.originalPrice)
                }
            }
        case .coach:
            if !editedRouteId.isEmpty {
                if let match = viewModel.trips.first(where: {
                    $0.type == .coach && $0.routeId == editedRouteId &&
                    $0.startStation == editedStartStation && $0.endStation == editedEndStation
                }) {
                    editedPrice = String(match.originalPrice)
                }
            }
        default:
            // 歷史紀錄查詢
            if let match = viewModel.trips.first(where: {
                $0.type == type && $0.startStation == editedStartStation && $0.endStation == editedEndStation
            }) {
                editedPrice = String(match.originalPrice)
            }
        }
    }
    
    private func retryRecording() {
        voiceService.reset()
        draft = nil
        withAnimation {
            phase = .ready
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
