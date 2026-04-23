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
    enum ViewPhase {
        case ready          // 準備錄音
        case recording      // 錄音中
        case parsing        // 解析中
        case preview        // 草稿預覽
        case permissionDenied // 權限被拒
        case fallbackManual // 低信心，轉手動
    }
    
    @State private var phase: ViewPhase = .ready
    
    // V2：多段行程陣列
    @State private var drafts: [VoiceDraft] = []
    @State private var segments: [SegmentEditState] = []
    
    @State private var showSaveSuccess = false
    @State private var showTRAOutOfRangeAlert = false
    @State private var showCycleDateOutOfRangeAlert = false
    
    // 追蹤是否已成功儲存，用於 onDisappear 判斷「放棄」
    @State private var didSaveTrip: Bool = false
    
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

    private var activeCycleDateRange: ClosedRange<Date>? {
        guard let cycle = viewModel.activeCycle else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        return start...end
    }

    private var activeCycleStartDate: Date? {
        guard let cycle = viewModel.activeCycle else { return nil }
        return Calendar.current.startOfDay(for: cycle.start)
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
        .alert("台鐵站點超出月票範圍", isPresented: $showTRAOutOfRangeAlert) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("目前選擇的台鐵起訖站不在你當前月票方案可使用範圍，請改選可用站點。")
        }
        .alert("日期超出月票週期", isPresented: $showCycleDateOutOfRangeAlert) {
            Button("取消", role: .cancel) { }
            Button("仍要新增") {
                saveDraftsAsTrips(forceAdjustOutOfRangeDates: true)
            }
        } message: {
            Text("語音解析中有行程日期超出目前月票週期，若仍要新增，超出範圍的日期會自動改為月票起始日 00:00。")
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
            "「捷運北車到淡水，轉860公車到三芝」",
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
    
    // MARK: - 草稿預覽（V2 時間軸）
    
    private var previewPhaseContent: some View {
        VStack(spacing: 16) {
            // 原始轉寫
            VStack(alignment: .leading, spacing: 6) {
                Text("voice_original_transcript")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                Text(drafts.first?.originalTranscript ?? "")
                    .font(.body)
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.cardBackgroundColor)
                    .cornerRadius(10)
            }
            
            Divider()
            
            // 多段時間軸
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, _ in
                // 轉乘連接線（第二段以後）
                if index > 0 {
                    transferConnector
                }
                
                segmentCard(at: index)
            }
            
            // + 手動加入下一段轉乘
            Button(action: addEmptySegment) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("voice_add_segment")
                }
                .font(.subheadline)
                .foregroundColor(themeManager.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeManager.cardBackgroundColor)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                )
            }
            
            Spacer().frame(height: 10)
            
            // 操作按鈕
            VStack(spacing: 12) {
                // 確認儲存
                Button(action: saveDraftsAsTrips) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        if segments.count > 1 {
                            Text("確認並儲存 \(segments.count) 筆行程")
                                .fontWeight(.bold)
                        } else {
                            Text("voice_confirm_save")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSaveAll ? themeManager.accentColor : Color.gray.opacity(0.4))
                    .cornerRadius(12)
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
                Button(action: { dismiss() }) {
                    Text("voice_switch_manual")
                        .font(.subheadline)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
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
            seg.transportType != nil &&
            !seg.startStation.isEmpty &&
            !seg.endStation.isEmpty &&
            (Int(seg.price) != nil || seg.price.isEmpty)
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
            Task {
                await VoiceParseLogService.shared.logFailedParse(
                    originalTranscript: "",
                    drafts: [],
                    reason: .emptyTranscript
                )
            }
            return
        }
        
        withAnimation {
            phase = .parsing
        }
        
        // V2：解析可能回傳多段 ParsedTrip
        let parsedArray = TripVoiceParser.parse(text)
        
        guard !parsedArray.isEmpty else {
            withAnimation { phase = .fallbackManual }
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
        
        // 取首段判斷信心度
        let firstParsed = parsedArray[0]
        
        if firstParsed.isLowConfidence || !firstParsed.hasRequiredFields {
            withAnimation {
                phase = .fallbackManual
            }
            HapticManager.shared.notification(type: .warning)
            let reason: VoiceParseLogService.FailureReason = firstParsed.hasRequiredFields ? .lowConfidence : .missingFields
            Task {
                await VoiceParseLogService.shared.logFailedParse(
                    originalTranscript: text,
                    drafts: newDrafts,
                    reason: reason
                )
            }
        } else {
            withAnimation {
                phase = .preview
            }
            if firstParsed.isHighConfidence {
                HapticManager.shared.notification(type: .success)
            }
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
        saveDraftsAsTrips(forceAdjustOutOfRangeDates: false)
    }

    private func saveDraftsAsTrips(forceAdjustOutOfRangeDates: Bool) {
        guard let userId = auth.currentUser?.id else { return }

        var segmentsToSave = segments

        if let range = activeCycleDateRange {
            let hasOutOfRangeDate = segmentsToSave.contains { !range.contains($0.date) }

            if hasOutOfRangeDate && !forceAdjustOutOfRangeDates {
                showCycleDateOutOfRangeAlert = true
                HapticManager.shared.notification(type: .warning)
                return
            }

            if hasOutOfRangeDate,
               forceAdjustOutOfRangeDates,
               let cycleStart = activeCycleStartDate {
                for index in segmentsToSave.indices where !range.contains(segmentsToSave[index].date) {
                    segmentsToSave[index].date = cycleStart
                }
                segments = segmentsToSave
            }
        }
        
        var finalTripDataArray: [[String: Any]] = []
        
        for seg in segmentsToSave {
            guard let transportType = seg.transportType else { continue }
            
            // 台鐵站點範圍驗證
            if transportType == .tra {
                let outOfRange = !availableTRAStationIDs.contains(seg.startStation) ||
                                 !availableTRAStationIDs.contains(seg.endStation)
                if outOfRange && !seg.startStation.isEmpty && !seg.endStation.isEmpty {
                    showTRAOutOfRangeAlert = true
                    HapticManager.shared.notification(type: .warning)
                    return
                }
            }
            
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
                cycleId: currentCycleId
            )
            
            viewModel.addTrip(newTrip)
            
            finalTripDataArray.append([
                "transportType": transportType.rawValue,
                "startStation": seg.startStation,
                "endStation": seg.endStation,
                "price": originalPrice,
                "routeId": seg.routeId,
                "isTransfer": seg.isTransfer,
                "isFree": seg.isFree
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
        guard let type = seg.transportType,
              !seg.startStation.isEmpty,
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
        case .bus:
            if seg.price.isEmpty {
                seg.price = currentRegion.defaultBusPrice(identity: currentIdentity)
            }
            if !seg.routeId.isEmpty {
                if let match = viewModel.trips.first(where: { $0.type == .bus && $0.routeId == seg.routeId }) {
                    if seg.price.isEmpty {
                        seg.price = String(match.originalPrice)
                    }
                }
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
