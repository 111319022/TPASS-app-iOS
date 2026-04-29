import SwiftUI

/// 每段行程的可編輯狀態
struct SegmentEditState: Identifiable {
    let id: UUID
    var transportType: TransportType?
    var startStation: String = ""
    var endStation: String = ""
    var startLineCode: String = ""
    var endLineCode: String = ""
    var price: String = ""
    var routeId: String = ""
    var note: String = ""
    var date: Date = Date()
    var isTransfer: Bool = false
    var isFree: Bool = false
    var transferDiscountType: TransferDiscountType? = nil
    var isHSRNonReserved: Bool = false
    var startTRARegion: TRARegion? = nil
    var endTRARegion: TRARegion? = nil
}

/// 語音快速記錄行程 — 獨立入口頁面
/// V2：錄音 → 轉寫 → 解析（多段行程） → 時間軸預覽 → 確認批次建立 Trip
struct VoiceQuickTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    @StateObject private var voiceService = VoiceInputService()
    
    // MARK: - 狀態
    enum ViewPhase: Hashable {
        case ready            // 準備錄音
        case recording        // 錄音中
        case parsing          // 解析中
        case simplePreview    // V3：完美命中 — 極簡票券卡片
        case advancedEditor   // V3：多段轉乘/低信心 — 完整編輯器（原 preview）
        case permissionDenied // 權限被拒
        case fallbackManual   // 低信心，轉手動
    }
    
    @State private var phase: ViewPhase = .ready
    
    // V2：多段行程陣列
    @State private var drafts: [VoiceDraft] = []
    @State private var segments: [SegmentEditState] = []
    
    @State private var showSaveSuccess = false
    @State private var showTRAOutOfRangeAlert = false
    @State private var showUnsupportedTransportAlert = false
    @State private var showCycleDateOutOfRangeAlert = false
    
    // 追蹤是否已成功儲存，用於 onDisappear 判斷「放棄」
    @State private var didSaveTrip: Bool = false
    
    // 時間軸：正在編輯的段落 index（nil 表示全部收合為摘要卡片）
    @State private var editingSegmentIndex: Int? = nil
    
    // 快速補填：展開迷你編輯面板的段落 index（與 editingSegmentIndex 互斥）
    @State private var quickFixSegmentIndex: Int? = nil

    // 快速補填：站名欄位是否維持展開，避免輸入時因條件變更而重建
    @State private var quickFixStationExpandedIndex: Int? = nil

    // 快速補填：金額欄位是否維持展開，避免輸入時因條件變更而重建
    @State private var quickFixPriceExpandedIndex: Int? = nil
    
    var onSuccess: (() -> Void)? = nil
    var onSwitchToManual: (() -> Void)? = nil
    
    private var currentRegion: TPASSRegion {
        viewModel.activeCycle?.region ?? auth.currentRegion
    }
    
    private var currentCycleId: String? {
        viewModel.activeCycle?.id
    }
    
    private var currentCardId: String? {
        viewModel.activeCycle?.cardId
    }
    
    private var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
    }

    private var activeCycleDateRange: ClosedRange<Date>? {
        guard let cycle = viewModel.activeCycle else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        return start...end
    }

    private var currentSupportedModes: [TransportType] {
        viewModel.activeCycle?.effectiveSupportedModes ?? currentRegion.supportedModes
    }
    
    private var availableTRARegions: [TRARegion] {
        TRAStationData.shared.getRegions(for: currentRegion)
    }

    private var availableTRAStationIDs: Set<String> {
        Set(availableTRARegions.flatMap { region in
            region.stations.map { $0.id }
        })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Group {
                            switch phase {
                            case .ready:
                                readyPhaseContent
                            case .recording:
                                recordingPhaseContent
                            case .parsing:
                                parsingPhaseContent
                            case .simplePreview:
                                simplePreviewContent
                            case .advancedEditor:
                                advancedEditorContent
                            case .permissionDenied:
                                permissionDeniedContent
                            case .fallbackManual:
                                fallbackManualContent
                            }
                        }
                        .id(phase)
                        .transition(.opacity)
                    }
                    .padding(20)
                    .animation(.easeInOut(duration: 0.25), value: phase)
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
        .alert(Text("voice_tra_out_of_range_title"), isPresented: $showTRAOutOfRangeAlert) {
            Button("voice_retry", role: .cancel) {
                retryRecording()
            }
        } message: {
            Text("voice_tra_out_of_range_message")
        }
        .alert(Text("voice_unsupported_transport_alert_title"), isPresented: $showUnsupportedTransportAlert) {
            Button("voice_retry", role: .cancel) {
                retryRecording()
            }
        } message: {
            Text("voice_unsupported_transport_alert_message")
        }
        .alert(Text("date_out_of_cycle_title"), isPresented: $showCycleDateOutOfRangeAlert) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("date_out_of_cycle_adjust_time_message")
        }
        .onAppear {
            checkPermissions()
        }
        .onDisappear {
            // 有成功解析出 drafts 但使用者未儲存就離開 → 上傳 abandoned 紀錄
            if !drafts.isEmpty, !didSaveTrip {
                let transcript = drafts.first?.originalTranscript ?? ""
                let abandonedDrafts = drafts
                Task {
                    await VoiceParseLogService.shared.logAbandonedParse(
                        originalTranscript: transcript,
                        drafts: abandonedDrafts
                    )
                }
            }
        }
    }
    
    // MARK: - 準備錄音
        
        private var readyPhaseContent: some View {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
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
                
                // 範例提示 (弱化視覺效果，移除底色與框線)
                VStack(alignment: .leading, spacing: 8) {
                    Text("voice_example_header")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.7))
                    
                    ForEach(examplePhrases, id: \.self) { phrase in
                        HStack(spacing: 6) {
                            Image(systemName: "text.quote")
                                .font(.caption2)
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                            Text(phrase)
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 10)
                
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
                
                // 語音辨識僅支援中文提示
                HStack(spacing: 4) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.caption2)
                    Text("voice_chinese_only_hint")
                        .font(.caption)
                }
                .foregroundColor(.orange.opacity(0.9))
                .padding(.top, 4)

                // Beta 與隱私提示
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("voice_beta_label")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundColor(themeManager.accentColor.opacity(0.8))
                    
                    Text("voice_beta_privacy_notice")
                        .font(.caption2)
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 30)
                .padding(.top, 8)
            }
        }
        
        private var examplePhrases: [String] {
            [
                String(localized: "voice_example_1"),
                String(localized: "voice_example_2"),
                String(localized: "voice_example_3"),
            ]
        }
    
    // MARK: - 錄音中
    
    /// 波形柱狀歷史紀錄
    @State private var waveformSamples: [Float] = Array(repeating: 0, count: 30)
    
    private var recordingPhaseContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            
            // 錄音計時
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text(timerDisplay)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            // 波形視覺化區域
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(themeManager.cardBackgroundColor)
                    .frame(height: 180)
                
                // 波形柱狀圖
                HStack(spacing: 3) {
                    ForEach(Array(waveformSamples.enumerated()), id: \.offset) { _, sample in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeManager.accentColor.opacity(0.7))
                            .frame(width: 4, height: max(4, CGFloat(sample) * 100))
                    }
                }
                .frame(height: 120)
                .animation(.easeOut(duration: 0.1), value: waveformSamples)
            }
            .padding(.horizontal, 4)
            
            // 即時轉寫文字
            if !voiceService.transcript.isEmpty {
                Text(voiceService.transcript)
                    .font(.body)
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(12)
            } else {
                Text("voice_listening")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            
            // 進度條（55秒限制）
            ProgressView(value: Double(voiceService.elapsedSeconds), total: Double(VoiceInputService.maxDuration))
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .padding(.horizontal, 20)
            
            Spacer()
            
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
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(14)
                .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .onChange(of: voiceService.state) { _, newState in
            // 當 voiceService 自動停止（55秒到達）時觸發解析
            if newState == .idle && phase == .recording {
                parseTranscript()
            }
        }
        .onChange(of: voiceService.audioLevel) { _, newLevel in
            // 滾動更新波形歷史
            waveformSamples.append(newLevel)
            if waveformSamples.count > 30 {
                waveformSamples.removeFirst()
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
    
    // MARK: - V3：極簡預覽 (Magic Card)
    
    /// 將站名 ID 轉換為顯示名稱（台鐵站名為代號，需要還原）
    private func displayStationName(_ stationId: String, transportType: TransportType?) -> String {
        guard let type = transportType else { return stationId }
        if type == .tra {
            return TRAStationData.shared.displayStationName(stationId)
        }
        return stationId
    }

    private func displayTransportName(_ transportType: TransportType?, routeId: String) -> String {
        guard let type = transportType else { return "" }
        if type == .lrt && !routeId.isEmpty {
            return routeId
        }
        return String(localized: String.LocalizationValue(type.displayNameKey))
    }

    private func displayDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "yyyy/MM/dd"
        let dateText = formatter.string(from: date)
        formatter.dateFormat = "HH:mm"
        let timeText = formatter.string(from: date)
        return "\(dateText) · \(timeText)"
    }
    
    private var simplePreviewContent: some View {
        let transportType = segments.first?.transportType
        let transportColor = transportType.map { themeManager.transportColor($0) } ?? themeManager.accentColor
        
        return VStack(spacing: 24) {
            Spacer().frame(height: 20)
            
            // 成功圖示（使用運具配色）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(transportColor)
            
            // 票券風格大卡片（運具專屬配色）
            VStack(spacing: 16) {
                // 運具標籤
                if let type = transportType {
                    HStack(spacing: 6) {
                        Image(systemName: type.systemIconName)
                            .font(.caption)
                        Text(displayTransportName(type, routeId: segments.first?.routeId ?? ""))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(transportColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(transportColor.opacity(0.12))
                    .cornerRadius(20)
                }
                
                // 起迄站大字（台鐵 ID 還原為中文站名）
                let startRaw = segments.first?.startStation ?? ""
                let endRaw = segments.first?.endStation ?? ""
                let hasRealStart = !startRaw.trimmingCharacters(in: .whitespaces).isEmpty
                let hasRealEnd = !endRaw.trimmingCharacters(in: .whitespaces).isEmpty
                
                if hasRealStart || hasRealEnd {
                    HStack(spacing: 12) {
                        if hasRealStart {
                            Text(displayStationName(startRaw, transportType: transportType))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        
                        if hasRealStart && hasRealEnd {
                            Image(systemName: "arrow.right")
                                .font(.title3)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        if hasRealEnd {
                            Text(displayStationName(endRaw, transportType: transportType))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.primaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                
                // 票價（使用運具配色）
                if let priceStr = segments.first?.price, !priceStr.isEmpty, let price = Int(priceStr), price > 0 {
                    Text("$\(price)")
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(transportColor)
                }
                
                // 日期 + 時間
                if let date = segments.first?.date {
                    Text(displayDateTime(date))
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(transportColor.opacity(0.25), lineWidth: 1.5)
            )
            .shadow(color: transportColor.opacity(0.10), radius: 12, x: 0, y: 4)
            
            Spacer().frame(height: 8)
            
            // 主按鈕：確認儲存（使用運具配色）
            Button(action: saveDraftsAsTrips) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("voice_confirm_save")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSaveAll ? transportColor : Color.gray.opacity(0.4))
                .cornerRadius(14)
                .shadow(color: transportColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(!canSaveAll)
            
            // 不支援運具提示
            if hasUnsupportedTransport {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("voice_unsupported_transport_hint")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
            
            // 次按鈕：修改詳細內容
            Button(action: {
                phase = .advancedEditor
            }) {
                Text("voice_edit_details")
                    .font(.subheadline)
                    .foregroundColor(transportColor)
            }
            
            // 重新錄音
            Button(action: retryRecording) {
                Text("voice_retry")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
    }
    
    // MARK: - V3：時間軸編輯器（票券時間軸 A→B→C）
    
    private var advancedEditorContent: some View {
        VStack(spacing: 0) {
            // 標題列：行程時間軸
            HStack {
                Text("voice_timeline_title")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
            }
            .padding(.bottom, 12)
            
            // 時間軸段落列表
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
                // 轉乘連接線（第二段以後）
                if index > 0 {
                    transferConnector
                }
                
                if editingSegmentIndex == index {
                    // 展開：完整編輯卡片
                    VStack(spacing: 0) {
                        // 編輯標題列
                        HStack {
                            Text("編輯第 \(index + 1) 段")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryTextColor)
                            Spacer()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    editingSegmentIndex = nil
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("voice_collapse_editor")
                                        .font(.caption)
                                    Image(systemName: "chevron.up")
                                        .font(.caption)
                                }
                                .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        
                        segmentCard(at: index)
                    }
                } else {
                    // 收合：摘要卡片
                    segmentSummaryCard(at: index, segment: seg)
                    
                    // 快速補填面板（警告按鈕展開時顯示）
                    if quickFixSegmentIndex == index {
                        segmentQuickFixPanel(at: index)
                            .padding(.top, 4)
                    }
                }
            }
            
            // + 手動加入下一段轉乘 (降級視覺層級)
            Button(action: addEmptySegment) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("voice_add_segment")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(themeManager.secondaryTextColor)
                .padding(.vertical, 16)
            }
            
            Spacer().frame(height: 16)
            
            // 操作按鈕
            VStack(spacing: 12) {
                // 確認儲存
                Button(action: saveDraftsAsTrips) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("voice_confirm_save_count \(segments.count)")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSaveAll ? themeManager.accentColor : Color.gray.opacity(0.4))
                    .cornerRadius(14)
                }
                .disabled(!canSaveAll)
                
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
                Button(action: {
                    let callback = onSwitchToManual
                    dismiss()
                    // 延遲呼叫，等 sheet dismiss 完成後再開啟 AddTripView
                    if let callback {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            callback()
                        }
                    }
                }) {
                    Text("voice_switch_manual")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
    }
    
    // MARK: - 快速補填面板（僅顯示缺漏欄位）
    
    /// 迷你編輯面板：只顯示該段落缺漏的欄位，點擊警告後向下展開
    @ViewBuilder
    private func segmentQuickFixPanel(at index: Int) -> some View {
        let seg = segments[index]
        let type = seg.transportType
        let isStationlessAllowed = type == .bus || type == .coach || type == .bike || type == .ferry
        let isQuickFixing = quickFixSegmentIndex == index
        let isStationExpanded = quickFixStationExpandedIndex == index
        let isPriceExpanded = quickFixPriceExpandedIndex == index
        let hasStart = !seg.startStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.startStation != " "
        let hasEnd = !seg.endStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.endStation != " "
        let priceWarning = type == .coach && (Int(seg.price) ?? 0) <= 0
        let showFareDisplay = type == .bus && !seg.price.isEmpty
        let stationWarning = stationMissingWarning(for: seg)
        
        VStack(spacing: 12) {
            // 缺運具：顯示運具選擇格
            if type == nil {
                quickFixTransportPicker(at: index)
            }
            
            // 缺金額（客運）
            if isPriceExpanded || priceWarning {
                quickFixPriceInput(at: index)
            }
            
            // 缺起訖站
            if type != nil {
                if isStationExpanded {
                    quickFixStationInput(at: index, needStart: true, needEnd: true, isExpanded: true)
                } else if stationWarning != nil {
                    quickFixStationInput(at: index, needStart: !hasStart, needEnd: !hasEnd, isExpanded: false)
                } else if isStationlessAllowed {
                    if hasStart != hasEnd {
                        quickFixStationInput(at: index, needStart: !hasStart, needEnd: !hasEnd, isExpanded: false)
                    }
                } else {
                    if !hasStart || !hasEnd {
                        quickFixStationInput(at: index, needStart: !hasStart, needEnd: !hasEnd, isExpanded: false)
                    }
                }
            }

            // 收合按鈕
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    quickFixSegmentIndex = nil
                    quickFixStationExpandedIndex = nil
                    quickFixPriceExpandedIndex = nil
                }
            }) {
                HStack(spacing: 4) {
                    Text("voice_collapse_editor")
                        .font(.caption)
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(12)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    /// 快速補填：運具選擇
    @ViewBuilder
    private func quickFixTransportPicker(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("voice_missing_transport_question")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.secondaryTextColor)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                ForEach(currentSupportedModes) { mode in
                    Button(action: {
                        segments[index].transportType = mode
                        applyParsedSelectionMetadata(for: &segments[index])
                        autoFillFareForSegment(&segments[index])
                        // 如果補完後沒有其他缺漏，自動收合
                        if segmentMissingWarning(for: segments[index]) == nil {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                quickFixSegmentIndex = nil
                                quickFixStationExpandedIndex = nil
                                quickFixPriceExpandedIndex = nil
                            }
                            HapticManager.shared.notification(type: .success)
                        }
                    }) {
                        VStack(spacing: 3) {
                            Image(systemName: mode.systemIconName)
                                .font(.subheadline)
                            Text(mode.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(themeManager.primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(themeManager.backgroundColor)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    /// 快速補填：金額輸入
    @ViewBuilder
    private func quickFixPriceInput(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("voice_missing_price_question")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.secondaryTextColor)
            
            HStack(spacing: 10) {
                Text("$")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                TextField("0", text: $segments[index].price)
                    .keyboardType(.numberPad)
                    .font(.title3.bold())
                    .foregroundColor(themeManager.primaryTextColor)

                let isValid = (Int(segments[index].price) ?? 0) > 0
                Button(action: {
                    if isValid {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            quickFixSegmentIndex = nil
                            quickFixStationExpandedIndex = nil
                            quickFixPriceExpandedIndex = nil
                        }
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }) {
                    Text("voice_quick_fix_confirm")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isValid ? .white : themeManager.secondaryTextColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isValid ? AnyShapeStyle(themeManager.accentColor) : themeManager.backgroundColor)
                        .cornerRadius(8)
                }
                .disabled(!isValid)
            }
            .padding(10)
            .background(themeManager.backgroundColor)
            .cornerRadius(8)
        }
    }
    
    /// 快速補填：起訖站輸入
    @ViewBuilder
    private func quickFixStationInput(at index: Int, needStart: Bool, needEnd: Bool, isExpanded: Bool) -> some View {
        if let type = segments[index].transportType {
            VStack(alignment: .leading, spacing: 8) {
                Text("voice_missing_station_question")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                VStack(spacing: 0) {
                    if isExpanded || needStart {
                        quickFixSingleStationRow(at: index, type: type, isStart: true)
                    }
                    if isExpanded || (needStart && needEnd) {
                        Divider().opacity(0.5).padding(.leading, 12)
                    }
                    if isExpanded || needEnd {
                        quickFixSingleStationRow(at: index, type: type, isStart: false)
                    }
                }
                .background(themeManager.backgroundColor)
                .cornerRadius(8)

                let warning = segmentMissingWarning(for: segments[index])
                Button(action: {
                    if warning == nil {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            quickFixSegmentIndex = nil
                            quickFixStationExpandedIndex = nil
                            quickFixPriceExpandedIndex = nil
                        }
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }) {
                    Text("voice_quick_fix_confirm")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(warning == nil ? .white : themeManager.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(warning == nil ? AnyShapeStyle(themeManager.accentColor) : themeManager.backgroundColor)
                        .cornerRadius(8)
                }
                .disabled(warning != nil)
            }
            .onSubmit {
                if segmentMissingWarning(for: segments[index]) == nil {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        quickFixSegmentIndex = nil
                        quickFixStationExpandedIndex = nil
                        quickFixPriceExpandedIndex = nil
                    }
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
    
    /// 快速補填：單一站點選擇列
    @ViewBuilder
    private func quickFixSingleStationRow(at index: Int, type: TransportType, isStart: Bool) -> some View {
        switch type {
        case .tra:
            TRALineStationInputRow(
                label: isStart ? "start_point" : "end_point",
                regions: availableTRARegions,
                selectedRegion: isStart ? $segments[index].startTRARegion : $segments[index].endTRARegion,
                stationId: isStart ? $segments[index].startStation : $segments[index].endStation
            )
        case .lrt:
            StationInputRow(
                label: isStart ? "start_point" : "end_point",
                type: .lrt,
                lineCode: $segments[index].startLineCode,
                stationName: isStart ? $segments[index].startStation : $segments[index].endStation,
                currentRegion: currentRegion,
                lineSelectionEnabled: isStart
            )
        default:
            StationInputRow(
                label: isStart ? "start_point" : "end_point",
                type: type,
                lineCode: isStart ? $segments[index].startLineCode : $segments[index].endLineCode,
                stationName: isStart ? $segments[index].startStation : $segments[index].endStation,
                currentRegion: currentRegion,
                manualPlaceholderKey: "enter_station_name_required"
            )
        }
    }

    /// 快速補填：票價顯示列（公車用，不可編輯）
    @ViewBuilder
    private func quickFixFareDisplay(at index: Int) -> some View {
        let seg = segments[index]
        if let originalPrice = Int(seg.price), originalPrice > 0 {
            let paidPrice = calculatePaidPrice(
                originalPrice: originalPrice,
                isFree: seg.isFree,
                isTransfer: seg.isTransfer,
                transferDiscountType: seg.transferDiscountType
            )

            HStack {
                if paidPrice != originalPrice {
                    Text("voice_fare_with_transfer")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                } else {
                    Text("voice_fare_label")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }

                Spacer()

                if paidPrice != originalPrice {
                    Text("$\(originalPrice)")
                        .font(.caption)
                        .strikethrough()
                        .foregroundColor(themeManager.secondaryTextColor)
                    Text("$\(paidPrice)")
                        .font(.title3)
                        .foregroundColor(themeManager.primaryTextColor)
                } else {
                    Text("$\(originalPrice)")
                        .font(.title3)
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(themeManager.backgroundColor)
            .cornerRadius(8)
        }
    }
    
    // MARK: - 摘要卡片（收合狀態）
    
    /// 段落摘要卡片：票券風格（左色條 + 運具大字 + 起迄站垂直 + 底部票價列）
    private func segmentSummaryCard(at index: Int, segment seg: SegmentEditState) -> some View {
        let transportColor = seg.transportType.map { themeManager.transportColor($0) } ?? themeManager.accentColor
        let isMissing = seg.transportType == nil || seg.startStation.isEmpty || seg.endStation.isEmpty
        
        return HStack(spacing: 0) {
            // 左側色條
            RoundedRectangle(cornerRadius: 2)
                .fill(isMissing ? Color.orange : transportColor)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            // 主內容
            VStack(alignment: .leading, spacing: 10) {
                // 第一區：運具標題 + 日期時間 + 編輯按鈕
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // 運具標籤（icon + 名稱）+ 日期時間
                        HStack(spacing: 6) {
                            if let type = seg.transportType {
                                Image(systemName: type.systemIconName)
                                    .font(.footnote)
                                    .foregroundColor(transportColor)
                                Text(displayTransportName(type, routeId: seg.routeId))
                                    .font(.footnote)
                                    .foregroundColor(transportColor)
                            }
                            Text(displayDateTime(seg.date))
                                .font(.caption)
                                .foregroundColor(Color.gray)
                        }
                        
                        // 公車/客運：顯示路線號大字
                        if (seg.transportType == .bus || seg.transportType == .coach) {
                            if !seg.routeId.isEmpty {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("No.")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                    Text(seg.routeId)
                                        .font(.title)
                                        .foregroundColor(themeManager.primaryTextColor)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 編輯按鈕（開啟完整編輯器）
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            quickFixSegmentIndex = nil
                            editingSegmentIndex = index
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("voice_edit_label")
                                .font(.caption)
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                    }
                }
                
                // 第二區：起迄站（垂直排列）
                if !seg.startStation.isEmpty || !seg.endStation.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        // 起站
                        HStack(spacing: 8) {
                            Circle()
                                .stroke(themeManager.primaryTextColor, lineWidth: 1.5)
                                .frame(width: 10, height: 10)
                            Text(displayStationName(seg.startStation.isEmpty ? "?" : seg.startStation, transportType: seg.transportType))
                                .font(.body)
                                .foregroundColor(seg.startStation.isEmpty ? .orange : themeManager.primaryTextColor)
                        }
                        
                        // 連結線
                        Rectangle()
                            .fill(themeManager.secondaryTextColor.opacity(0.3))
                            .frame(width: 1.5, height: 14)
                            .padding(.leading, 4)
                        
                        // 迄站
                        HStack(spacing: 8) {
                            Circle()
                                .fill(themeManager.primaryTextColor)
                                .frame(width: 10, height: 10)
                            Text(displayStationName(seg.endStation.isEmpty ? "?" : seg.endStation, transportType: seg.transportType))
                                .font(.body)
                                .foregroundColor(seg.endStation.isEmpty ? .orange : themeManager.primaryTextColor)
                        }
                    }
                } else if isMissing {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("voice_tap_to_fill")
                            .font(.subheadline)
                    }
                    .foregroundColor(.orange)
                }
                
                // 第三區：票價底欄 或 警告提示 (Warning Badge)
                let warning = segmentMissingWarning(for: seg)
                let isQuickFixing = (quickFixSegmentIndex == index)
                let showFareDisplay = seg.transportType == .bus && (Int(seg.price) ?? 0) > 0

                if warning != nil || isQuickFixing {
                    // 缺漏需要補齊時：票價在上、警示在下
                    if showFareDisplay {
                        quickFixFareDisplay(at: index)
                    }

                    // 點擊後向下展開迷你補填面板
                    Button(action: {
                        let shouldCollapse = quickFixSegmentIndex == index
                        let stationWarning = stationMissingWarning(for: seg)
                        let priceWarning = seg.transportType == .coach && (Int(seg.price) ?? 0) <= 0
                        withAnimation(.easeInOut(duration: 0.25)) {
                            editingSegmentIndex = nil
                            quickFixSegmentIndex = shouldCollapse ? nil : index
                            quickFixStationExpandedIndex = shouldCollapse ? nil : (stationWarning != nil ? index : nil)
                            quickFixPriceExpandedIndex = shouldCollapse ? nil : (priceWarning ? index : nil)
                        }
                        // 收合時降下鍵盤
                        if shouldCollapse {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }) {
                        HStack {
                            if let w = warning {
                                Text(w)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            } else {
                                Text("voice_quick_fix_complete_hint")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Image(systemName: isQuickFixing ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(warning != nil ? .red.opacity(0.7) : .green.opacity(0.7))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(warning != nil ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else if let originalPrice = Int(seg.price), originalPrice > 0 {
                    // 原本的票價顯示邏輯 (維持不變)
                    let paidPrice = calculatePaidPrice(
                        originalPrice: originalPrice,
                        isFree: seg.isFree,
                        isTransfer: seg.isTransfer,
                        transferDiscountType: seg.transferDiscountType
                    )
                    
                    HStack {
                        if paidPrice != originalPrice {
                            Text("voice_fare_with_transfer")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        } else {
                            Text("voice_fare_label")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        
                        Spacer()
                        
                        if paidPrice != originalPrice {
                            Text("$\(originalPrice)")
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("$\(paidPrice)")
                                .font(.title3)
                                .foregroundColor(themeManager.primaryTextColor)
                        } else {
                            Text("$\(originalPrice)")
                                .font(.title3)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(themeManager.backgroundColor)
                    .cornerRadius(8)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .padding(.vertical, 14)
        }
        .padding(.trailing, 8)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isMissing ? Color.orange.opacity(0.4) : themeManager.secondaryTextColor.opacity(0.1), lineWidth: isMissing ? 1.5 : 1)
        )
    }
    
    /// 判斷該段落缺乏什麼必要資訊，回傳警告文字（nil 表示無缺漏）
    private func segmentMissingWarning(for seg: SegmentEditState) -> String? {
        let type = seg.transportType
        let isStationlessAllowed = type == .bus || type == .coach || type == .bike || type == .ferry
        
        let hasStart = !seg.startStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.startStation != " "
        let hasEnd = !seg.endStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.endStation != " "
        
        if type == nil {
            return "⚠️ 點擊選擇交通工具"
        } else if type == .coach && (Int(seg.price) ?? 0) <= 0 {
            return "⚠️ 點擊輸入金額"
        } else if isStationlessAllowed {
            // 單邊站名缺漏，必須要求補齊
            if hasStart != hasEnd {
                return "⚠️ 點擊補齊起訖站"
            }
            return nil
        } else {
            if !hasStart || !hasEnd {
                return "⚠️ 點擊補齊起訖站"
            }
            return nil
        }
    }

    /// 只判斷是否還缺起訖站，用來控制站名補填面板的顯示
    private func stationMissingWarning(for seg: SegmentEditState) -> String? {
        let type = seg.transportType
        let isStationlessAllowed = type == .bus || type == .coach || type == .bike || type == .ferry

        let hasStart = !seg.startStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.startStation != " "
        let hasEnd = !seg.endStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.endStation != " "

        guard type != nil else { return nil }

        if isStationlessAllowed {
            return hasStart != hasEnd ? "⚠️ 點擊補齊起訖站" : nil
        }

        return (!hasStart || !hasEnd) ? "⚠️ 點擊補齊起訖站" : nil
    }
    
    /// 運具短代碼（用於摘要卡片大字前綴）
    private func transportTypeShortCode(_ type: TransportType) -> String {
        switch type {
        case .mrt, .kmrt, .tcmrt, .tymrt: return "M"
        case .tra: return "TRA"
        case .hsr: return "HSR"
        case .lrt: return "LRT"
        case .bus: return "N°"
        case .coach: return "N°"
        case .bike: return "🚲"
        case .ferry: return "⛴"
        }
    }
    
    /// 段落卡片（使用 VoiceSegmentEditorCard）
    private func segmentCard(at index: Int) -> some View {
        let draftForIndex = index < drafts.count ? drafts[index] : VoiceDraft.empty()
        
        return VoiceSegmentEditorCard(
            draft: draftForIndex,
            segmentIndex: index,
            totalSegments: segments.count,
            currentRegion: currentRegion,
            currentIdentity: currentIdentity,
            currentSupportedModes: currentSupportedModes,
            availableTRARegions: availableTRARegions,
            transportType: $segments[index].transportType,
            startStation: $segments[index].startStation,
            endStation: $segments[index].endStation,
            startLineCode: $segments[index].startLineCode,
            endLineCode: $segments[index].endLineCode,
            price: $segments[index].price,
            routeId: $segments[index].routeId,
            note: $segments[index].note,
            date: $segments[index].date,
            isTransfer: $segments[index].isTransfer,
            isFree: $segments[index].isFree,
            transferDiscountType: $segments[index].transferDiscountType,
            isHSRNonReserved: $segments[index].isHSRNonReserved,
            startTRARegion: $segments[index].startTRARegion,
            endTRARegion: $segments[index].endTRARegion,
            onDelete: segments.count > 1 ? { removeSegment(at: index) } : nil,
            onAutoFillFare: { autoFillFare(for: index) },
            onTransportTypeChanged: { handleTransportTypeChange(for: index) }
        )
    }
    
    /// 轉乘連接線
    private var transferConnector: some View {
        HStack(spacing: 8) {
            Spacer()
            VStack(spacing: 2) {
                Rectangle()
                    .fill(themeManager.accentColor.opacity(0.4))
                    .frame(width: 2, height: 12)
                Image(systemName: "arrow.triangle.swap")
                    .font(.caption)
                    .foregroundColor(themeManager.accentColor)
                Text("voice_transfer_connector")
                    .font(.caption2)
                    .foregroundColor(themeManager.secondaryTextColor)
                Rectangle()
                    .fill(themeManager.accentColor.opacity(0.4))
                    .frame(width: 2, height: 12)
            }
            Spacer()
        }
    }
    
    /// 所有段落是否都可儲存
    private var canSaveAll: Bool {
        guard !segments.isEmpty else { return false }
        return segments.allSatisfy { seg in
            guard let type = seg.transportType else { return false }
            
            // 運具必須在該週期支援的範圍內
            guard currentSupportedModes.contains(type) else { return false }
            
            let isStationlessAllowed = type == .bus || type == .bike || type == .ferry || type == .coach
            let hasStart = !seg.startStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.startStation != " "
            let hasEnd = !seg.endStation.trimmingCharacters(in: .whitespaces).isEmpty && seg.endStation != " "
            
            if type == .coach {
                guard let price = Int(seg.price), price > 0 else { return false }
            }
            
            if isStationlessAllowed {
                if !hasStart && !hasEnd {
                    // 雙空：有路線或有金額即可 (客運上面已檢查)
                    return !seg.routeId.isEmpty || Int(seg.price) != nil || type == .coach
                } else if hasStart && hasEnd {
                    return true
                } else {
                    // 單邊缺漏，不給存
                    return false
                }
            } else {
                return hasStart && hasEnd
            }
        }
    }
    
    /// 是否有段落使用了該週期不支援的運具
    private var hasUnsupportedTransport: Bool {
        segments.contains { seg in
            guard let type = seg.transportType else { return false }
            return !currentSupportedModes.contains(type)
        }
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
        phase = .recording
    }
    
    private func stopRecording() {
        voiceService.stopRecording()
        parseTranscript()
    }
    
    private func parseTranscript() {
        let text = voiceService.transcript
        guard !text.isEmpty else {
            phase = .fallbackManual
            HapticManager.shared.notification(type: .warning)
            Task {
                await VoiceParseLogService.shared.logFailedParse(
                    originalTranscript: "",
                    drafts: [],
                    reason: .emptyTranscript
                )
            }
            return
        }
        
        phase = .parsing
        
        // V2：解析可能回傳多段 ParsedTrip
        let parsedArray = TripVoiceParser.parse(text)
        
        guard !parsedArray.isEmpty else {
            phase = .fallbackManual
            HapticManager.shared.notification(type: .warning)
            Task {
                await VoiceParseLogService.shared.logFailedParse(
                    originalTranscript: text,
                    drafts: [],
                    reason: .missingFields
                )
            }
            return
        }
        
        // 將每段 ParsedTrip 轉為 VoiceDraft
        let newDrafts = parsedArray.map { VoiceDraft.from(parsed: $0, transcript: text) }
        drafts = newDrafts
        
        // 建立對應的 SegmentEditState
        segments = newDrafts.enumerated().map { index, d in
            var seg = SegmentEditState(id: d.id)
            seg.transportType = d.transportType
            seg.startStation = d.startStation ?? ""
            seg.endStation = d.endStation ?? ""
            seg.routeId = d.routeId ?? ""
            seg.note = d.note ?? ""
            seg.isTransfer = d.isTransfer
            
            // 合併日期與時間
            var dateTime = d.tripDate ?? Date()
            if let parsedTime = d.tripTime {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: dateTime)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                if let mergedDate = calendar.date(from: dateComponents) {
                    dateTime = mergedDate
                }
            }
            seg.date = dateTime
            
            // 台中捷運預設綠線
            if d.transportType == .tcmrt {
                seg.startLineCode = "GREEN"
                seg.endLineCode = "GREEN"
            }
            
            // 回填線路/區域等輔助欄位
            applyParsedSelectionMetadata(for: &seg)
            
            // 票價：語音有說出價格就用，否則嘗試自動查價
            if let voicePrice = d.price {
                seg.price = String(voicePrice)
            } else {
                autoFillFareForSegment(&seg)
            }
            
            // 轉乘段自動套用區域預設轉乘優惠
            if seg.isTransfer && index > 0 {
                seg.transferDiscountType = currentRegion.defaultTransferType
            }
            
            return seg
        }
        
        // V4：根據解析結果分流 — 統一使用時間軸視圖
        let firstParsed = parsedArray[0]
        
        if firstParsed.isLowConfidence {
            // 低信心 → fallback
            phase = .fallbackManual
            HapticManager.shared.notification(type: .warning)
            Task {
                await VoiceParseLogService.shared.logFailedParse(
                    originalTranscript: text,
                    drafts: newDrafts,
                    reason: .lowConfidence
                )
            }
        } else {
            // 🔒 辨識後驗證：運具是否在方案支援範圍內
            let unsupportedSegment = segments.first { seg in
                guard let type = seg.transportType else { return false }
                return !currentSupportedModes.contains(type)
            }
            if unsupportedSegment != nil {
                phase = .ready
                showUnsupportedTransportAlert = true
                HapticManager.shared.notification(type: .warning)
                return
            }
            
            // 🔒 辨識後驗證：台鐵站點是否在方案範圍內
            let traOutOfRange = segments.contains { seg in
                guard seg.transportType == .tra else { return false }
                let hasStart = !seg.startStation.trimmingCharacters(in: .whitespaces).isEmpty
                let hasEnd = !seg.endStation.trimmingCharacters(in: .whitespaces).isEmpty
                if !hasStart && !hasEnd { return false }
                let startOK = !hasStart || availableTRAStationIDs.contains(seg.startStation)
                let endOK = !hasEnd || availableTRAStationIDs.contains(seg.endStation)
                return !startOK || !endOK
            }
            if traOutOfRange {
                phase = .ready
                showTRAOutOfRangeAlert = true
                HapticManager.shared.notification(type: .warning)
                return
            }
            
            // 所有成功解析（不論單段/多段、欄位是否齊全）→ 時間軸視圖
            editingSegmentIndex = nil
            phase = .advancedEditor
            HapticManager.shared.notification(type: .success)
        }
    }

    /// 根據目前運具與站點回填線路/區域等輔助欄位（作用於 SegmentEditState）
    private func applyParsedSelectionMetadata(for seg: inout SegmentEditState) {
        guard let type = seg.transportType else { return }

        switch type {
        case .mrt:
            if let startLine = StationData.shared.lines.first(where: { $0.stations.contains(seg.startStation) }) {
                seg.startLineCode = startLine.code
            }
            if let endLine = StationData.shared.lines.first(where: { $0.stations.contains(seg.endStation) }) {
                seg.endLineCode = endLine.code
            }

        case .kmrt:
            if let startLine = KMRTStationData.shared.lines.first(where: { $0.stations.contains(seg.startStation) }) {
                seg.startLineCode = startLine.code
            }
            if let endLine = KMRTStationData.shared.lines.first(where: { $0.stations.contains(seg.endStation) }) {
                seg.endLineCode = endLine.code
            }

        case .tcmrt:
            if let startLine = TCMRTStationData.shared.lines.first(where: { $0.stations.contains(seg.startStation) }) {
                seg.startLineCode = startLine.code
            } else if seg.startLineCode.isEmpty {
                seg.startLineCode = "GREEN"
            }
            if let endLine = TCMRTStationData.shared.lines.first(where: { $0.stations.contains(seg.endStation) }) {
                seg.endLineCode = endLine.code
            } else if seg.endLineCode.isEmpty {
                seg.endLineCode = seg.startLineCode.isEmpty ? "GREEN" : seg.startLineCode
            }

        case .lrt:
            let availableLines = LRTStationData.shared.availableLines(for: currentRegion)
            if let startLine = availableLines.first(where: { $0.stations.contains(where: { $0.nameZH == seg.startStation }) }) {
                seg.startLineCode = startLine.code
            } else if let endLine = availableLines.first(where: { $0.stations.contains(where: { $0.nameZH == seg.endStation }) }) {
                seg.startLineCode = endLine.code
            }
            if !seg.startLineCode.isEmpty {
                seg.endLineCode = seg.startLineCode
            }

        case .tra:
            if let startId = TRAStationData.shared.resolveStationID(seg.startStation) {
                seg.startStation = startId
            }
            if let endId = TRAStationData.shared.resolveStationID(seg.endStation) {
                seg.endStation = endId
            }
            let regions = availableTRARegions
            if let startRegion = regions.first(where: { region in
                region.stations.contains(where: { $0.id == seg.startStation })
            }) {
                seg.startTRARegion = startRegion
            }
            if let endRegion = regions.first(where: { region in
                region.stations.contains(where: { $0.id == seg.endStation })
            }) {
                seg.endTRARegion = endRegion
            }

        default:
            break
        }
    }
    
    // MARK: - 批次儲存
    
    private func saveDraftsAsTrips() {
        guard let userId = auth.currentUser?.id else { return }

        // 鎖定當下 activeCycle 狀態，避免儲存期間切換週期造成 cardId/cycleId 不一致
        let activeCycleSnapshot = viewModel.activeCycle
        let cycleIdForSave = activeCycleSnapshot?.id
        let cardIdForSave = activeCycleSnapshot?.cardId

        let segmentsToSave = segments

        if let range = activeCycleDateRange {
            let hasOutOfRangeDate = segmentsToSave.contains { !range.contains($0.date) }

            if hasOutOfRangeDate {
                showCycleDateOutOfRangeAlert = true
                HapticManager.shared.notification(type: .warning)
                return
            }
        }
        
        var finalTripDataArray: [[String: Any]] = []
        
        for seg in segmentsToSave {
            guard let transportType = seg.transportType else { continue }
            
            let originalPrice = Int(seg.price) ?? 0
            let paidPrice = calculatePaidPrice(
                originalPrice: originalPrice,
                isFree: seg.isFree,
                isTransfer: seg.isTransfer,
                transferDiscountType: seg.transferDiscountType
            )
            
            let newTrip = Trip(
                id: UUID().uuidString,
                userId: userId,
                createdAt: seg.date,
                type: transportType,
                originalPrice: originalPrice,
                paidPrice: paidPrice,
                isTransfer: seg.isTransfer,
                isFree: seg.isFree,
                startStation: seg.startStation,
                endStation: seg.endStation,
                routeId: seg.routeId,
                note: seg.note,
                transferDiscountType: seg.transferDiscountType,
                cycleId: cycleIdForSave,
                cardId: cardIdForSave
            )
            
            viewModel.addTrip(newTrip)
            
            let dtFormatter = DateFormatter()
            dtFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            dtFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            finalTripDataArray.append([
                "transportType": transportType.rawValue,
                "startStation": seg.startStation,
                "endStation": seg.endStation,
                "price": originalPrice,
                "routeId": seg.routeId,
                "isTransfer": seg.isTransfer,
                "isFree": seg.isFree,
                "finalDateTime": dtFormatter.string(from: seg.date)
            ])
        }

        HapticManager.shared.notification(type: .success)
        didSaveTrip = true
        
        // 背景上傳語音解析修正紀錄
        let currentDrafts = drafts
        let transcript = currentDrafts.first?.originalTranscript ?? ""
        Task {
            await VoiceParseLogService.shared.logParseResult(
                originalTranscript: transcript,
                drafts: currentDrafts,
                finalTripDataArray: finalTripDataArray
            )
        }
        
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSuccess?()
        }
    }
    
    /// 計算實付金額
    private func calculatePaidPrice(
        originalPrice: Int,
        isFree: Bool,
        isTransfer: Bool,
        transferDiscountType: TransferDiscountType?
    ) -> Int {
        if isFree { return 0 }
        let discount: Int
        if isTransfer, let type = transferDiscountType {
            discount = type.discount(for: currentIdentity)
        } else {
            discount = 0
        }
        return max(0, originalPrice - discount)
    }
    
    /// 運具切換時重設相關欄位（V2：作用於特定段落）
    private func handleTransportTypeChange(for index: Int) {
        guard index < segments.count,
              let newType = segments[index].transportType else { return }
        
        segments[index].startStation = ""
        segments[index].endStation = ""
        segments[index].startLineCode = ""
        segments[index].endLineCode = ""
        segments[index].startTRARegion = nil
        segments[index].endTRARegion = nil
        segments[index].isHSRNonReserved = false
        
        if newType == .tcmrt {
            segments[index].startLineCode = "GREEN"
            segments[index].endLineCode = "GREEN"
        }
        
        if newType == .hsr {
            segments[index].isTransfer = false
            segments[index].transferDiscountType = nil
        }
        
        if newType == .bus {
            segments[index].price = currentRegion.defaultBusPrice(identity: currentIdentity)
        } else {
            segments[index].price = ""
        }
        
        if newType != .coach && newType != .bus {
            segments[index].routeId = ""
        }
    }
    
    /// 自動查價（V2：作用於特定段落 index）
    private func autoFillFare(for index: Int) {
        guard index < segments.count else { return }
        autoFillFareForSegment(&segments[index])
    }
    
    /// 自動查價（內部共用，作用於 SegmentEditState）
    private func autoFillFareForSegment(_ seg: inout SegmentEditState) {
        guard let type = seg.transportType else { return }

        // 公車：只要語音沒說票價，就一律先帶入方案預設票價
        // 不依賴起訖站是否完整，避免「缺迄站」時無法自動帶入。
        if type == .bus {
            if seg.price.isEmpty {
                seg.price = currentRegion.defaultBusPrice(identity: currentIdentity)
            }
            return
        }

        // 其餘運具維持原邏輯：需有完整起訖站才進行自動查價。
        guard !seg.startStation.isEmpty,
              !seg.endStation.isEmpty else { return }
        
        switch type {
        case .mrt:
            if let fare = TPEMRTFareService.shared.getFare(from: seg.startStation, to: seg.endStation) {
                seg.price = String(fare)
            }
        case .tymrt:
            if auth.currentUser?.citizenCity == .taoyuan,
               let citizenFare = TYMRTFareService.shared.getCitizenFare(from: seg.startStation, to: seg.endStation) {
                seg.price = String(citizenFare)
            } else if let fare = TYMRTFareService.shared.getFare(from: seg.startStation, to: seg.endStation) {
                seg.price = String(fare)
            }
        case .tcmrt:
            if let fare = TCMRTFareService.shared.getFare(from: seg.startStation, to: seg.endStation) {
                seg.price = String(fare)
            }
        case .kmrt:
            if let fare = KMRTFareService.shared.getFare(from: seg.startStation, to: seg.endStation) {
                seg.price = String(fare)
            }
        case .lrt:
            let lineCode = seg.startLineCode.isEmpty ? seg.endLineCode : seg.startLineCode
            if !lineCode.isEmpty,
               let fare = LRTFareService.shared.getFare(lineCode: lineCode, from: seg.startStation, to: seg.endStation) {
                seg.price = String(fare)
            }
        case .tra:
            let fare = TRAFareService.shared.getFare(from: seg.startStation, to: seg.endStation)
            if fare > 0 {
                seg.price = String(fare)
            }
        case .hsr:
            if let fare = THSRFareService.shared.getFare(from: seg.startStation, to: seg.endStation, isNonReserved: seg.isHSRNonReserved) {
                seg.price = String(fare)
            }
        case .coach:
            if !seg.routeId.isEmpty {
                if let match = viewModel.trips.first(where: {
                    $0.type == .coach && $0.routeId == seg.routeId &&
                    $0.startStation == seg.startStation && $0.endStation == seg.endStation
                }) {
                    seg.price = String(match.originalPrice)
                }
            }
        default:
            if let match = viewModel.trips.first(where: {
                $0.type == type && $0.startStation == seg.startStation && $0.endStation == seg.endStation
            }) {
                seg.price = String(match.originalPrice)
            }
        }
    }
    
    // MARK: - 段落操作
    
    /// 新增空白段落
    private func addEmptySegment() {
        let newId = UUID()
        var newSeg = SegmentEditState(id: newId)
        newSeg.isTransfer = true
        newSeg.transferDiscountType = currentRegion.defaultTransferType
        newSeg.date = segments.last?.date ?? Date()
        
        // 帶入上一段終點作為起點
        if let lastSeg = segments.last {
            newSeg.startStation = lastSeg.endStation
        }
        
        segments.append(newSeg)
        
        // 也在 drafts 中追加空白 draft
        drafts.append(VoiceDraft.empty())
    }
    
    /// 移除指定段落
    private func removeSegment(at index: Int) {
        guard segments.count > 1, index < segments.count else { return }
        segments.remove(at: index)
        if index < drafts.count {
            drafts.remove(at: index)
        }
    }
    
    private func retryRecording() {
        voiceService.reset()
        drafts = []
        segments = []
        editingSegmentIndex = nil
        quickFixSegmentIndex = nil
        quickFixStationExpandedIndex = nil
        quickFixPriceExpandedIndex = nil
        waveformSamples = Array(repeating: 0, count: 30)
        phase = .ready
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
