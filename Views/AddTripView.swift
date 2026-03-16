import SwiftUI

struct AddTripView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager

    
    var onSuccess: (() -> Void)? = nil
    
    // 新增：取得目前選中周期的方案，若無則用日期自動解析
    private var resolvedCycleForDate: Cycle? {
        viewModel.cycleForTrip(date: date)
    }
    
    private var currentRegion: TPASSRegion {
        resolvedCycleForDate?.region ?? auth.currentRegion
    }
    
    private var currentCycleId: String? {
        resolvedCycleForDate?.id
    }
    
    // === 表單狀態 ===
    @State private var date = Date()
    @State private var time = Date()
    @State private var selectedType: TransportType = .mrt
    @State private var showDateOutOfRangeAlert = false
    
    // 路線與站點
    @State private var routeId: String = ""
    @State private var startStation: String = ""
    @State private var endStation: String = ""
    @State private var startLineCode: String = ""
    @State private var endLineCode: String = ""
    
    //     TRA 雙欄選擇狀態
    @State private var startTRARegion: TRARegion?
    @State private var endTRARegion: TRARegion?
    
    // 取得目前方案可用的區域列表
    private var availableTRARegions: [TRARegion] {
        TRAStationData.shared.getRegions(for: currentRegion)
    }
    
    // 運具選擇的 Grid columns
    private var transportGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }
    
    // 金額與選項
    @State private var price: String = ""
    @State private var note: String = ""
    @State private var isTransfer: Bool = false
    @State private var isFree: Bool = false
    @State private var transferDiscountType: TransferDiscountType? = nil  // 新增：轉乘優惠類型
    @State private var showTransferTypePicker = false  // 新增：顯示轉乘類型選擇器
    
    var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
    }

    // 根據市民縣市篩選可用的轉乘類型
    private var filteredTransferTypes: [TransferDiscountType] {
        let allTypes = currentRegion.supportedTransferTypes
        guard let userCity = auth.currentUser?.citizenCity else {
            return allTypes
        }
        return allTypes.filter { type in
            if let required = type.citizenRequirement {
                return required == userCity
            }
            return true
        }
    }

    var isFormValid: Bool {
        (!price.isEmpty && Int(price) != nil) || isFree
    }

    // 輸入框背景色
    var inputBackgroundColor: Color {
        let isDark: Bool = {
            switch themeManager.currentTheme {
            case .dark:
                return true
            case .light, .muji:
                return false
            case .system:
                return UITraitCollection.current.userInterfaceStyle == .dark
            }
        }()
        return isDark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground)
    }

    private var allowedCycle: Cycle? {
        viewModel.activeCycle
    }

    private var allowedDateRange: ClosedRange<Date>? {
        guard let cycle = allowedCycle else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        return start...end
    }

    @ViewBuilder
    private var dateTimeSection: some View {
        HStack(spacing: 12) {
            compactDatePicker(icon: "calendar", selection: $date, components: .date)
                .frame(maxWidth: .infinity, minHeight: 52)
            compactDatePicker(icon: "clock", selection: $time, components: .hourAndMinute)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private var transportSelectionSection: some View {
        LazyVGrid(columns: transportGridColumns, spacing: 8) {
            ForEach(currentRegion.supportedModes) { type in
                transportTypeButton(type)
            }
        }
        .padding(.bottom, 5)
    }

    private var routeStationSection: some View {
        VStack(spacing: 0) {
            routeStationContent
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private var routeStationContent: some View {
        switch selectedType {
        case .bus:
            VStack(spacing: 0) {
                TextField("route_example 307", text: $routeId)
                    .padding(12)
                    .foregroundColor(themeManager.primaryTextColor)
                Divider().opacity(0.5).padding(.leading, 12)

                StationInputRow(
                    label: "start_point",
                    type: selectedType,
                    lineCode: $startLineCode,
                    stationName: $startStation,
                    currentRegion: currentRegion
                )

                Divider().opacity(0.5).padding(.leading, 12)

                StationInputRow(
                    label: "end_point",
                    type: selectedType,
                    lineCode: $endLineCode,
                    stationName: $endStation,
                    currentRegion: currentRegion
                )
            }

        case .coach:
            VStack(spacing: 0) {
                TextField("route_example 1610", text: $routeId)
                    .padding(12)
                    .foregroundColor(themeManager.primaryTextColor)
                Divider().opacity(0.5).padding(.leading, 12)

                StationInputRow(
                    label: "start_point",
                    type: selectedType,
                    lineCode: $startLineCode,
                    stationName: $startStation,
                    currentRegion: currentRegion
                )

                Divider().opacity(0.5).padding(.leading, 12)

                StationInputRow(
                    label: "end_point",
                    type: selectedType,
                    lineCode: $endLineCode,
                    stationName: $endStation,
                    currentRegion: currentRegion
                )
            }

        case .tra:
            traSelectionCard

        case .tcmrt:
            standardStartEndStationInputs(type: selectedType)

        case .kmrt, .lrt:
            standardStartEndStationInputs(type: selectedType)

        default:
            standardStartEndStationInputs(type: selectedType)
        }
    }

    private func standardStartEndStationInputs(type: TransportType) -> some View {
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

    private var traSelectionCard: some View {
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
    }

    private var priceAndTransferSection: some View {
        HStack(spacing: 12) {
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
            .background(inputBackgroundColor)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))

            transferButtonWithDialog
        }
    }

    private var transferButtonWithDialog: some View {
        transferButton()
            .frame(height: 50)
            .confirmationDialog("transfer", isPresented: $showTransferTypePicker) {
                transferTypeDialogActions
            }
    }

    @ViewBuilder
    private var transferTypeDialogActions: some View {
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

    private var freeAndNoteSection: some View {
        HStack(spacing: 12) {
            Button(action: { isFree.toggle() }) {
                HStack {
                    Image(systemName: isFree ? "gift.fill" : "gift")
                    Text("free_trip")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isFree ? themeManager.accentColor : inputBackgroundColor)
                .foregroundColor(isFree ? .white : themeManager.secondaryTextColor)
                .cornerRadius(8)
            }
            .accessibilityLabel(Text("a11y_free_trip"))
            .accessibilityValue(isFree ? Text("a11y_on") : Text("a11y_off"))

            TextField("notes_placeholder_add", text: $note)
                .padding(10)
                .background(inputBackgroundColor)
                .cornerRadius(8)
                .foregroundColor(themeManager.primaryTextColor)
        }
    }

    private var submitButtonSection: some View {
        Button(action: saveTrip) {
            Text("submit_button")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isFormValid ? themeManager.accentColor : Color.gray.opacity(0.4))
                .cornerRadius(12)
                .shadow(color: isFormValid ? themeManager.accentColor.opacity(0.3) : Color.clear, radius: 5, x: 0, y: 3)
        }
        .disabled(!isFormValid)
        .padding(.bottom, 20)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {

                        // MARK: - 1. 日期與時間
                        dateTimeSection

                        // MARK: - 2. 運具選擇 (Grid)
                        transportSelectionSection

                        // MARK: - 3. 路線/站點輸入 (修正邏輯)
                        routeStationSection

                        // MARK: - 4. 價格與選項
                        priceAndTransferSection

                        freeAndNoteSection
                        
                        Spacer(minLength: 10)
                        
                        // MARK: - 5. 按鈕
                        submitButtonSection
                    }
                    .padding(20)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("add_trip_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .accessibilityLabel(Text("a11y_close"))
                    .accessibilityHint(Text("a11y_close_add_trip_hint"))
                }
            }
        }
        // 固定高度，取消滑動展開
        .presentationDetents([.height(650)])
        .presentationDragIndicator(.hidden)
        .alert(Text("date_out_of_cycle_title"), isPresented: $showDateOutOfRangeAlert) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("date_out_of_cycle_message")
        }
        
        .onAppear {
            // 初始化 selectedType 為當前地區支持的第一種運具
            if let firstMode = currentRegion.supportedModes.first {
                selectedType = firstMode
                handleTypeChange(firstMode)
            }
            if let range = allowedDateRange, !range.contains(date) {
                date = range.lowerBound
            }
        }
        .onChange(of: startStation) { _, _ in tryAutoFillFromHistory() }
        .onChange(of: endStation) { _, _ in tryAutoFillFromHistory() }
        .onChange(of: routeId) { _, _ in tryAutoFillFromHistory() }
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
    
    // MARK: - 邏輯處理
    func handleTypeChange(_ newType: TransportType) {
        if newType == .bus {
            startStation = ""; endStation = ""
            // 根據地區與身分取得預設票價
            price = currentRegion.defaultBusPrice(identity: currentIdentity)
        } else {
            // 切換其他運具時
            // 如果不是客運，才清空 routeId (因為客運需要 routeId)
            if newType != .coach { routeId = "" }
            
            // 清空起讫站
            startStation = ""
            endStation = ""
            
            //     [修改] 台中捷運只有一條綠線，直接預設選取
            if newType == .tcmrt {
                startLineCode = "GREEN"
                endLineCode = "GREEN"
            } else {
                startLineCode = ""
                endLineCode = ""
            }
            
            price = ""
        }
    }
    
    func tryAutoFillFromHistory() {
        // 1. 北捷邏輯
        if selectedType == .mrt, !startStation.isEmpty, !endStation.isEmpty {
            if let officialPrice = FareService.shared.getFare(from: startStation, to: endStation) {
                price = String(officialPrice)
                return
            }
        }
        // 2. 桃園機捷邏輯
        if selectedType == .tymrt, !startStation.isEmpty, !endStation.isEmpty {
            if let tymrtPrice = TYMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(tymrtPrice)
                return
            }
        }
        // 3. 台中捷運邏輯
        if selectedType == .tcmrt, !startStation.isEmpty, !endStation.isEmpty {
            if let tcmrtPrice = TCMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(tcmrtPrice)
                return
            }
        }
        // 4. 高雄捷運邏輯
        if selectedType == .kmrt, !startStation.isEmpty, !endStation.isEmpty {
            if let kmirtPrice = KMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(kmirtPrice)
                return
            }
        }
        // 5. 台鐵查價邏輯
        if selectedType == .tra, !startStation.isEmpty, !endStation.isEmpty {
            let traPrice = TRAFareService.shared.getFare(from: startStation, to: endStation)
            price = String(traPrice)
            return
        }
        // 6. 歷史紀錄查詢
        let match = viewModel.trips.first { trip in
            guard trip.type == selectedType else { return false }
            
            // 搜尋邏輯：客運需全對，公車對路線，其他對站點
            if selectedType == .coach {
                return !routeId.isEmpty && trip.routeId == routeId &&
                       !startStation.isEmpty && !endStation.isEmpty &&
                       trip.startStation == startStation && trip.endStation == endStation
            } else if selectedType == .bus {
                return !routeId.isEmpty && trip.routeId == routeId
            } else {
                // 北捷、機捷、中捷、高捷或其他：比對起訖站
                return !startStation.isEmpty && !endStation.isEmpty &&
                       trip.startStation == startStation && trip.endStation == endStation
            }
        }
        
        // 自動填入 (避免覆蓋掉剛剛公車預設的金額)
        if let historyTrip = match, price.isEmpty {
            price = String(historyTrip.originalPrice)
        }
    }
    
    func calculatePaidPrice() -> Int {
        if isFree { return 0 }
        let p = Int(price) ?? 0
        //     修改：使用轉乘優惠類型計算折扣
        let discount: Int
        if isTransfer, let type = transferDiscountType {
            discount = type.discount(for: currentIdentity)
        } else {
            discount = 0
        }
        return max(0, p - discount)
    }
    
    func saveTrip() {
        guard let userId = auth.currentUser?.id, let p = Int(price) else { return }
        let calendar = Calendar.current
        let dateComps = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComps = calendar.dateComponents([.hour, .minute], from: time)
        let secondsNow = calendar.component(.second, from: Date())
        var finalComps = DateComponents()
        finalComps.year = dateComps.year; finalComps.month = dateComps.month; finalComps.day = dateComps.day
        finalComps.hour = timeComps.hour; finalComps.minute = timeComps.minute; finalComps.second = secondsNow
        var finalDate = calendar.date(from: finalComps) ?? date
        if let range = allowedDateRange, !range.contains(finalDate) {
            let clamped = min(max(finalDate, range.lowerBound), range.upperBound)
            finalDate = clamped
            date = clamped
            time = clamped
            showDateOutOfRangeAlert = true
        }

        let newTrip = Trip(
            id: UUID().uuidString,
            userId: userId,
            createdAt: finalDate,
            type: selectedType,
            originalPrice: p,
            paidPrice: calculatePaidPrice(),
            isTransfer: isTransfer,
            isFree: isFree,
            startStation: startStation,
            endStation: endStation,
            routeId: routeId,
            note: note,
            transferDiscountType: transferDiscountType,
            cycleId: currentCycleId
        )
        viewModel.addTrip(newTrip)
        
        //     新增：成功震動回饋
        HapticManager.shared.notification(type: .success)
        
        presentationMode.wrappedValue.dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSuccess?()
        }
    }
    
    // MARK: - UI Components
    
    func transportTypeButton(_ type: TransportType) -> some View {
        let isSelected = selectedType == type
        let bgColor = isSelected ? themeManager.transportColor(type) : inputBackgroundColor
        let shadowColor = isSelected ? themeManager.transportColor(type).opacity(0.3) : Color.black.opacity(0.02)
        let fgColor = isSelected ? Color.white : themeManager.secondaryTextColor
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedType = type
                handleTypeChange(type)
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: type.systemIconName)
                    .font(.system(size: 20))
                Text(type.displayName)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(height: 65)
            .frame(maxWidth: .infinity)
            .background(bgColor)
            .foregroundColor(fgColor)
            .cornerRadius(10)
            .shadow(color: shadowColor, radius: 3, x: 0, y: 1)
        }
        .accessibilityLabel(Text(type.displayName))
        .accessibilityValue(isSelected ? Text("a11y_selected") : Text("a11y_not_selected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    func transferButton() -> some View {
        let bgColor = isTransfer ? Color(hex: "#27ae60") : inputBackgroundColor
        let fgColor = isTransfer ? Color.white : themeManager.secondaryTextColor
        let showChevron = filteredTransferTypes.count > 1 && isTransfer
        
        return Button(action: {
            if filteredTransferTypes.count == 1 {
                if isTransfer {
                    isTransfer = false
                    transferDiscountType = nil
                } else {
                    isTransfer = true
                    transferDiscountType = filteredTransferTypes.first ?? currentRegion.defaultTransferType
                }
            } else {
                showTransferTypePicker = true
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isTransfer ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                if let type = transferDiscountType, isTransfer {
                    Text(type.displayNameKey(for: currentIdentity))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text("transfer")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if showChevron {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 12)
            .background(bgColor)
            .foregroundColor(fgColor)
            .cornerRadius(10)
        }
        .accessibilityLabel(Text("a11y_transfer_discount"))
        .accessibilityValue(isTransfer ? (transferDiscountType == nil ? Text("a11y_on") : Text(transferDiscountType!.displayNameKey(for: currentIdentity))) : Text("a11y_off"))
        .accessibilityHint(Text(filteredTransferTypes.count > 1 ? "a11y_transfer_options_hint" : "a11y_transfer_toggle_hint"))
    }
    
    func compactDatePicker(icon: String, selection: Binding<Date>, components: DatePickerComponents) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
            if let range = allowedDateRange, components.contains(.date) {
                DatePicker("", selection: selection, in: range, displayedComponents: components)
                    .labelsHidden()
                    .scaleEffect(0.85)
                    .accentColor(themeManager.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(components == .date ? Text("a11y_date") : Text("a11y_time"))
            } else {
                DatePicker("", selection: selection, displayedComponents: components)
                    .labelsHidden()
                    .scaleEffect(0.85)
                    .accentColor(themeManager.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(components == .date ? Text("a11y_date") : Text("a11y_time"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(inputBackgroundColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 站點輸入列 (已整合 KMRT / TCMRT 選擇器)
struct StationInputRow: View {
    let label: LocalizedStringKey
    let type: TransportType
    @Binding var lineCode: String
    @Binding var stationName: String
    let currentRegion: TPASSRegion
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            
            // === 1. 北捷 (MRT) ===
            if type == .mrt {
                mrtSelector(
                    dataSource: StationData.shared.lines,
                    displayLine: { StationData.shared.displayLineName($0, languageCode: Locale.current.identifier) },
                    displayStation: { StationData.shared.displayStationName($0, languageCode: Locale.current.identifier) }
                )
                
            // === 2. 高雄捷運 (KMRT) ===
            } else if type == .kmrt {
                mrtSelector(
                    dataSource: KMRTStationData.shared.lines,
                    displayLine: { KMRTStationData.shared.displayLineName($0, languageCode: Locale.current.identifier) },
                    displayStation: { KMRTStationData.shared.displayStationName($0, languageCode: Locale.current.identifier) }
                )

            // === 3. 台中捷運 (TCMRT) [    新增這裡] ===
            } else if type == .tcmrt {
                mrtSelector(
                    dataSource: TCMRTStationData.shared.lines,
                    displayLine: { TCMRTStationData.shared.displayLineName($0, languageCode: Locale.current.identifier) },
                    displayStation: { TCMRTStationData.shared.displayStationName($0, languageCode: Locale.current.identifier) }
                )

            // === 4. 桃園機捷 (TYMRT) ===
            } else if type == .tymrt {
                tymrtSelector

            // === 5. 台灣高鐵 (HSR) ===
            } else if type == .hsr {
                hsrSelector
                
            // === 6. 其他運具 (手動輸入) ===
            } else {
                manualInput
            }
        }
        .frame(height: 48)
    }
    
    // MARK: - 抽取出的通用 MRT 選擇器 (北捷/高捷共用邏輯)
    @ViewBuilder
    private func mrtSelector(
        dataSource: [MRTLine],
        displayLine: @escaping (String) -> String,
        displayStation: @escaping (String) -> String
    ) -> some View {
        // 左邊：路線選單
        Menu {
            ForEach(dataSource) { line in
                Button(action: {
                    lineCode = line.code
                    stationName = "" // 切換路線時清空站點
                }) {
                    Text(displayLine(line.name))
                }
            }
        } label: {
            HStack {
                Text(label).font(.caption).foregroundColor(themeManager.primaryTextColor).padding(.leading, 12)
                Spacer()
                if let line = dataSource.first(where: { $0.code == lineCode }) {
                    Text(displayLine(line.name))
                        .font(.subheadline).fontWeight(.bold).foregroundColor(line.color)
                        .lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    Text("select_route").font(.subheadline).foregroundColor(themeManager.primaryTextColor)
                }
                Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor).padding(.trailing, 8)
            }
            .frame(maxHeight: .infinity).frame(maxWidth: .infinity).background(Color.gray.opacity(0.05))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label) + Text(" line"))
            .accessibilityValue(lineCode.isEmpty ? Text("select_route") : Text(displayLine(dataSource.first(where: { $0.code == lineCode })?.name ?? "")))
        }
        
        Divider()
        
        // 右邊：車站選單
        Menu {
            if let line = dataSource.first(where: { $0.code == lineCode }) {
                ForEach(line.stations, id: \.self) { station in
                    Button(action: { stationName = station }) {
                        Text(displayStation(station))
                    }
                }
            } else {
                Text("select_route_first")
            }
        } label: {
            HStack {
                if stationName.isEmpty {
                    Text("select_station").foregroundColor(themeManager.secondaryTextColor)
                } else {
                    Text(displayStation(stationName))
                        .foregroundColor(themeManager.primaryTextColor)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label) + Text(" station"))
            .accessibilityValue(stationName.isEmpty ? Text("select_station") : Text(displayStation(stationName)))
        }
    }
    
    // TYMRT 專用選擇器
    @ViewBuilder
    private var tymrtSelector: some View {
        let availableStations = TYMRTStationData.shared.availableStations(for: currentRegion)
        
        HStack {
            Text(label).font(.caption).foregroundColor(themeManager.primaryTextColor).padding(.leading, 12)
            Spacer()
            Text("機場捷運", comment: "Airport MRT line name")
                .font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: "#8246AF"))
                .lineLimit(1).minimumScaleFactor(0.8)
            Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor).padding(.trailing, 8)
        }
        .frame(maxHeight: .infinity).frame(maxWidth: .infinity).background(Color.gray.opacity(0.05))
        .contentShape(Rectangle())
        
        Divider()
        
        Menu {
            ForEach(availableStations, id: \.self) { station in
                Button(action: { stationName = station }) {
                    Text(TYMRTStationData.shared.displayStationName(station, languageCode: Locale.current.identifier))
                }
            }
        } label: {
            HStack {
                if stationName.isEmpty {
                    Text("選擇站點", comment: "Select station placeholder").foregroundColor(themeManager.secondaryTextColor)
                } else {
                    Text(TYMRTStationData.shared.displayStationName(stationName, languageCode: Locale.current.identifier))
                        .foregroundColor(themeManager.primaryTextColor)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.9)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var hsrSelector: some View {
        let availableStations = HSRStationData.shared.availableStations(for: currentRegion)

        HStack {
            Text(label).font(.caption).foregroundColor(themeManager.primaryTextColor).padding(.leading, 12)
            Spacer()
            Text("hsr_line_name")
                .font(.subheadline).fontWeight(.bold).foregroundColor(Color(hex: "#FF6600"))
                .lineLimit(1).minimumScaleFactor(0.8)
            Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor).padding(.trailing, 8)
        }
        .frame(maxHeight: .infinity).frame(maxWidth: .infinity).background(Color.gray.opacity(0.05))
        .contentShape(Rectangle())

        Divider()

        Menu {
            ForEach(availableStations, id: \.self) { station in
                Button(action: { stationName = station }) {
                    Text(HSRStationData.shared.displayStationName(station, languageCode: Locale.current.identifier))
                }
            }
        } label: {
            HStack {
                if stationName.isEmpty {
                    Text("select_station").foregroundColor(themeManager.secondaryTextColor)
                } else {
                    Text(HSRStationData.shared.displayStationName(stationName, languageCode: Locale.current.identifier))
                        .foregroundColor(themeManager.primaryTextColor)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.9)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor)
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // 手動輸入框
    @ViewBuilder
    private var manualInput: some View {
        Text(label)
            .font(.caption)
            .foregroundColor(themeManager.primaryTextColor)
            .frame(width: 50)
            .padding(.leading, 8)
        Divider()
        TextField("enter_station_name", text: $stationName)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .foregroundColor(themeManager.primaryTextColor)
    }
}

struct TRALineStationInputRow: View {
    let label: LocalizedStringKey
    let regions: [TRARegion]

    @Binding var selectedRegion: TRARegion?
    @Binding var stationId: String

    @EnvironmentObject var themeManager: ThemeManager

    private var languageCode: String { Locale.current.identifier }

    private var selectedLineText: String {
        guard let region = selectedRegion else {
            return NSLocalizedString("select_region", comment: "")
        }
        return TRAStationData.shared.displayRegionName(region.name, languageCode: languageCode)
    }

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Line", selection: $selectedRegion) {
                    Text("select_region").tag(nil as TRARegion?)
                    ForEach(regions) { region in
                        Text(TRAStationData.shared.displayRegionName(region.name, languageCode: languageCode))
                            .tag(region as TRARegion?)
                    }
                }
            } label: {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.leading, 12)
                    Spacer()
                    Text(selectedLineText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(selectedRegion == nil ? themeManager.secondaryTextColor : themeManager.primaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.trailing, 8)
                }
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(label) + Text(" region"))
                .accessibilityValue(Text(selectedLineText))
            }

            Divider()

            Menu {
                if let region = selectedRegion {
                    Picker("Station", selection: $stationId) {
                        Text("select_station").tag("")
                        if !stationId.isEmpty, !region.stations.contains(where: { $0.id == stationId }) {
                            Text(TRAStationData.shared.displayStationName(stationId, languageCode: languageCode))
                                .tag(stationId)
                        }
                        ForEach(region.stations) { station in
                            Text(TRAStationData.shared.displayStationName(station.id, languageCode: languageCode))
                                .tag(station.id)
                        }
                    }
                } else {
                    Text("select_region_first")
                }
            } label: {
                HStack {
                    if stationId.isEmpty {
                        Text("select_station")
                            .foregroundColor(themeManager.secondaryTextColor)
                    } else {
                        Text(TRAStationData.shared.displayStationName(stationId, languageCode: languageCode))
                            .foregroundColor(themeManager.primaryTextColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedRegion == nil ? 0.6 : 1.0)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(label) + Text(" station"))
                .accessibilityValue(stationId.isEmpty ? Text("select_station") : Text(TRAStationData.shared.displayStationName(stationId, languageCode: languageCode)))
            }
        }
        .onChange(of: selectedRegion?.id) { _, _ in
            guard let region = selectedRegion else {
                stationId = ""
                return
            }
            if stationId.isEmpty { return }
            if region.stations.contains(where: { $0.id == stationId }) { return }
            stationId = ""
        }
        .frame(height: 48)
    }
}

