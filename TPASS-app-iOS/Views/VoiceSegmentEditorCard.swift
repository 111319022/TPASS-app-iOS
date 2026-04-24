import SwiftUI

/// 每段行程的編輯卡片（V2 多段行程用）
/// 從 VoiceQuickTripView 抽離的獨立元件
struct VoiceSegmentEditorCard: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: AppViewModel
    
    // MARK: - 段落資料
    
    let draft: VoiceDraft
    let segmentIndex: Int
    let totalSegments: Int
    let currentRegion: TPASSRegion
    let currentIdentity: Identity
    let currentSupportedModes: [TransportType]
    let availableTRARegions: [TRARegion]
    
    // MARK: - 可編輯欄位 Bindings
    
    @Binding var transportType: TransportType?
    @Binding var startStation: String
    @Binding var endStation: String
    @Binding var startLineCode: String
    @Binding var endLineCode: String
    @Binding var price: String
    @Binding var routeId: String
    @Binding var note: String
    @Binding var date: Date
    @Binding var isTransfer: Bool
    @Binding var isFree: Bool
    @Binding var transferDiscountType: TransferDiscountType?
    @Binding var isHSRNonReserved: Bool
    @Binding var startTRARegion: TRARegion?
    @Binding var endTRARegion: TRARegion?
    
    // MARK: - 回呼
    
    var onDelete: (() -> Void)?
    var onAutoFillFare: () -> Void
    var onTransportTypeChanged: () -> Void
    
    // MARK: - 內部狀態
    
    @State private var showTransferTypePicker: Bool = false
    
    // MARK: - 計算屬性
    
    private var filteredTransferTypes: [TransferDiscountType] {
        let allTypes = currentRegion.supportedTransferTypes
        guard let userCity = auth.currentUser?.citizenCity else { return allTypes }
        return allTypes.filter { type in
            if let required = type.citizenRequirement { return required == userCity }
            return true
        }
    }
    
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
    
    private var availableTRAStationIDs: Set<String> {
        Set(availableTRARegions.flatMap { region in
            region.stations.map { $0.id }
        })
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            // 段落標題列
            segmentHeader
            
            // 運具選擇
            fieldRow(label: "voice_field_transport") {
                Picker("", selection: $transportType) {
                    Text("voice_select_transport").tag(TransportType?.none)
                    ForEach(currentSupportedModes) { type in
                        Text(type.displayName).tag(TransportType?.some(type))
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.primaryTextColor)
            }
            .onChange(of: transportType) { _, _ in
                onTransportTypeChanged()
            }
            
            // 路線 (公車/客運)
            if transportType == .bus || transportType == .coach {
                fieldRow(label: "voice_field_route") {
                    TextField("voice_route_placeholder", text: $routeId)
                        .foregroundColor(themeManager.primaryTextColor)
                }
            }
            
            // 起迄站選擇
            stationSelectionSection
            
            // 票價 + 轉乘/免費/高鐵自由座
            priceAndOptionsSection
            
            // 日期
            fieldRow(label: "voice_field_date") {
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(themeManager.accentColor)
            }
            
            // 備註
            fieldRow(label: "voice_field_note") {
                TextField("voice_note_placeholder", text: $note)
                    .foregroundColor(themeManager.primaryTextColor)
            }
        }
        .padding(12)
        .background(themeManager.cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.secondaryTextColor.opacity(0.15), lineWidth: 1)
        )
        .onChange(of: startStation) { _, _ in onAutoFillFare() }
        .onChange(of: endStation) { _, _ in onAutoFillFare() }
        .onChange(of: routeId) { _, _ in onAutoFillFare() }
    }
    
    // MARK: - 段落標題
    
    private var segmentHeader: some View {
        HStack {
            // 段落編號
            HStack(spacing: 6) {
                Image(systemName: segmentIndex == 0 ? "1.circle.fill" : "\(min(segmentIndex + 1, 9)).circle.fill")
                    .font(.title3)
                    .foregroundColor(themeManager.accentColor)
                
                Text("第 \(segmentIndex + 1) 段行程")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
            }
            
            Spacer()
            
            // 轉乘標記
            if isTransfer {
                Text("voice_auto_transfer_hint")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // 刪除按鈕
            if let onDelete, totalSegments > 1 {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                        .font(.title3)
                }
            }
        }
    }
    
    // MARK: - 站點選擇區塊
    
    @ViewBuilder
    private var stationSelectionSection: some View {
        if let type = transportType {
            VStack(spacing: 0) {
                switch type {
                case .bus, .coach:
                    VStack(spacing: 0) {
                        StationInputRow(
                            label: "start_point",
                            type: type,
                            lineCode: $startLineCode,
                            stationName: $startStation,
                            currentRegion: currentRegion
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        StationInputRow(
                            label: "end_point",
                            type: type,
                            lineCode: $endLineCode,
                            stationName: $endStation,
                            currentRegion: currentRegion
                        )
                    }
                    
                case .tra:
                    VStack(spacing: 0) {
                        TRALineStationInputRow(
                            label: "start_point",
                            regions: availableTRARegions,
                            selectedRegion: $startTRARegion,
                            stationId: $startStation
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        TRALineStationInputRow(
                            label: "end_point",
                            regions: availableTRARegions,
                            selectedRegion: $endTRARegion,
                            stationId: $endStation
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
                            lineCode: $startLineCode,
                            stationName: $startStation,
                            currentRegion: currentRegion,
                            lineSelectionEnabled: true
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        StationInputRow(
                            label: "end_point",
                            type: .lrt,
                            lineCode: Binding(get: { startLineCode }, set: { _ in }),
                            stationName: $endStation,
                            currentRegion: currentRegion,
                            lineSelectionEnabled: false
                        )
                    }
                    .onChange(of: startLineCode) { _, newLineCode in
                        endLineCode = newLineCode
                        let availableLines = LRTStationData.shared.availableLines(for: currentRegion)
                        guard let selectedLine = availableLines.first(where: { $0.code == newLineCode }) else {
                            endStation = ""
                            return
                        }
                        if !endStation.isEmpty, !selectedLine.stations.contains(where: { $0.nameZH == endStation }) {
                            endStation = ""
                        }
                    }
                    
                default:
                    VStack(spacing: 0) {
                        StationInputRow(
                            label: "start_point",
                            type: type,
                            lineCode: $startLineCode,
                            stationName: $startStation,
                            currentRegion: currentRegion
                        )
                        Divider().opacity(0.5).padding(.leading, 12)
                        StationInputRow(
                            label: "end_point",
                            type: type,
                            lineCode: $endLineCode,
                            stationName: $endStation,
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
                    TextField("price_placeholder", text: $price)
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
                if transportType == .hsr {
                    Button(action: {
                        isHSRNonReserved.toggle()
                        isFree = false
                        isTransfer = false
                        transferDiscountType = nil
                        onAutoFillFare()
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
                    transferButton
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
            
            // 免費 + 自動查價提示
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
                
                if !price.isEmpty, let p = Int(price), p > 0 {
                    Text("voice_auto_fare_hint")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .onChange(of: isFree) { _, val in
                if val {
                    isTransfer = false
                    transferDiscountType = nil
                    price = "0"
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
    
    // MARK: - 轉乘按鈕
    
    private var transferButton: some View {
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
                Image(systemName: "arrow.triangle.swap")
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
    
    // MARK: - 通用欄位列
    
    @ViewBuilder
    private func fieldRow<Content: View>(
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
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
}
