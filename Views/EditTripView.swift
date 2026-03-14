import SwiftUI

struct EditTripView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    // The trip to be edited (passed in)
    let trip: Trip
    var onSuccess: (() -> Void)? = nil
    
    // 新增：取得目前選中周期的方案，若無則用日期自動解析
    private var resolvedCycleForTrip: Cycle? {
        if let cycle = viewModel.cycleById(trip.cycleId) { return cycle }
        return viewModel.resolveCycle(for: date)
    }
    
    private var currentRegion: TPASSRegion {
        resolvedCycleForTrip?.region ?? auth.currentRegion
    }
    
    // 取得該方案可用的區域列表
    private var availableTRARegions: [TRARegion] {
        TRAStationData.shared.getRegions(for: currentRegion)
    }
    
    // TRA 站點資料來源
    var traStationsStart: [TRAStation] {
        TRAStationData.shared.getStations(for: currentRegion)
    }
    
    var traStationsEnd: [TRAStation] {
        TRAStationData.shared.getStations(for: currentRegion)
    }
    
    // === Form State (initialized with trip data) ===
    @State private var date: Date
    @State private var time: Date
    @State private var selectedType: TransportType
    
    // Route and Station
    @State private var routeId: String
    @State private var startStation: String
    @State private var endStation: String
    @State private var startLineCode: String = ""
    @State private var endLineCode: String = ""
    
    // 台鐵區域選擇
    @State private var selectedStartRegion: TRARegion?
    @State private var selectedEndRegion: TRARegion?
    
    // Price and Options
    @State private var price: String
    @State private var note: String
    @State private var isTransfer: Bool
    @State private var isFree: Bool
    @State private var transferDiscountType: TransferDiscountType?  // 新增：轉乘優惠類型
    @State private var showTransferTypePicker = false  // 新增：顯示轉乘類型選擇器
    @State private var showDateOutOfRangeAlert = false
    
    // Identity (for calculating discount)
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
        return isDark ? Color(uiColor: .secondarySystemBackground) : Color.white
    }

    private var allowedCycle: Cycle? {
        viewModel.cycleById(trip.cycleId) ?? viewModel.selectedCycle ?? viewModel.resolveCycle(for: trip.createdAt)
    }

    private var allowedDateRange: ClosedRange<Date>? {
        guard let cycle = allowedCycle else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        return start...end
    }
    
    // Custom init to load existing trip data
    init(trip: Trip, onSuccess: (() -> Void)? = nil) {
        self.trip = trip
        self.onSuccess = onSuccess
        _date = State(initialValue: trip.createdAt)
        _time = State(initialValue: trip.createdAt)
        _selectedType = State(initialValue: trip.type)
        _routeId = State(initialValue: trip.routeId)
        _startStation = State(initialValue: trip.startStation)
        _endStation = State(initialValue: trip.endStation)
        _price = State(initialValue: String(trip.originalPrice))
        _note = State(initialValue: trip.note)
        _isTransfer = State(initialValue: trip.isTransfer)
        _isFree = State(initialValue: trip.isFree)
        _transferDiscountType = State(initialValue: trip.transferDiscountType)
        
        // Try to reverse lookup MRT line code (optional, for better UI)
        if trip.type == .mrt {
            // Simple logic: find which line contains the station
            if let line = StationData.shared.lines.first(where: { $0.stations.contains(trip.startStation) }) {
                _startLineCode = State(initialValue: line.code)
            }
            if let line = StationData.shared.lines.first(where: { $0.stations.contains(trip.endStation) }) {
                _endLineCode = State(initialValue: line.code)
            }
        }
        // 台中捷運線路反查
        else if trip.type == .tcmrt {
            if let line = TCMRTStationData.shared.lines.first(where: { $0.stations.contains(trip.startStation) }) {
                _startLineCode = State(initialValue: line.code)
            }
            if let line = TCMRTStationData.shared.lines.first(where: { $0.stations.contains(trip.endStation) }) {
                _endLineCode = State(initialValue: line.code)
            }
        }
        // 高雄捷運線路反查
        else if trip.type == .kmrt {
            if let line = KMRTStationData.shared.lines.first(where: { $0.stations.contains(trip.startStation) }) {
                _startLineCode = State(initialValue: line.code)
            }
            if let line = KMRTStationData.shared.lines.first(where: { $0.stations.contains(trip.endStation) }) {
                _endLineCode = State(initialValue: line.code)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        
                        // 1. Date & Time
                        HStack(spacing: 12) {
                            compactDatePicker(icon: "calendar", selection: $date, components: .date)
                                .frame(maxWidth: .infinity)
                            compactDatePicker(icon: "clock", selection: $time, components: .hourAndMinute)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // 2. Transport Type (Grid)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            // 修改：只顯示該地區支援的運具
                            ForEach(currentRegion.supportedModes) { type in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedType = type
                                        // 切換運具時清空起讫站
                                        if type == .bus {
                                            startStation = ""; endStation = ""
                                            // 修改：根據地區與身分取得預設票價
                                            if price.isEmpty { price = currentRegion.defaultBusPrice(identity: currentIdentity) }
                                        } else {
                                            if type != .coach { routeId = "" }
                                            // 清空起讫站
                                            startStation = ""
                                            endStation = ""
                                            startLineCode = ""
                                            endLineCode = ""
                                        }
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
                                    .background(selectedType == type ? themeManager.transportColor(type) : inputBackgroundColor)
                                    .foregroundColor(selectedType == type ? .white : themeManager.secondaryTextColor)
                                    .cornerRadius(10)
                                    .shadow(color: selectedType == type ? themeManager.transportColor(type).opacity(0.3) : Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
                                }
                                .accessibilityLabel(Text(type.displayName))
                                .accessibilityValue(selectedType == type ? Text("a11y_selected") : Text("a11y_not_selected"))
                                .accessibilityAddTraits(selectedType == type ? .isSelected : [])
                            }
                        }
                        .padding(.bottom, 5)
                        
                        // 3. Route/Station Input
                        routeStationInputView()
                        
                        // 4. Price & Options
                        HStack(spacing: 12) {
                            HStack {
                                Text("$").font(.headline).foregroundColor(themeManager.secondaryTextColor)
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
                            
                            // 修改：轉乘按鈕可選擇優惠類型
                            Button(action: {
                                if filteredTransferTypes.count == 1 {
                                    // 只有一種轉乘類型，直接切換
                                    if isTransfer {
                                        isTransfer = false
                                        transferDiscountType = nil
                                    } else {
                                        isTransfer = true
                                        transferDiscountType = filteredTransferTypes.first ?? currentRegion.defaultTransferType
                                    }
                                } else {
                                    // 多種轉乘類型，總是顯示選擇器
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
                                            .font(.subheadline).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                    if filteredTransferTypes.count > 1 && isTransfer {
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                    }
                                }
                                .frame(maxHeight: .infinity).padding(.horizontal, 12)
                                .background(isTransfer ? Color(hex: "#27ae60") : inputBackgroundColor)
                                .foregroundColor(isTransfer ? .white : themeManager.secondaryTextColor)
                                .cornerRadius(10)
                            }
                            .frame(height: 50)
                            .accessibilityLabel(Text("a11y_transfer_discount"))
                            .accessibilityValue(isTransfer ? (transferDiscountType == nil ? Text("a11y_on") : Text(transferDiscountType!.displayNameKey(for: currentIdentity))) : Text("a11y_off"))
                            .accessibilityHint(Text(filteredTransferTypes.count > 1 ? "a11y_transfer_options_hint" : "a11y_transfer_toggle_hint"))
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
                        
                        HStack(spacing: 12) {
                            Button(action: { isFree.toggle() }) {
                                HStack {
                                    Image(systemName: isFree ? "gift.fill" : "gift")
                                    Text("free_trip")
                                        .font(.subheadline).fontWeight(.medium)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(isFree ? themeManager.accentColor : inputBackgroundColor)
                                .foregroundColor(isFree ? .white : themeManager.secondaryTextColor)
                                .cornerRadius(8)
                            }
                            .accessibilityLabel(Text("a11y_free_trip"))
                            .accessibilityValue(isFree ? Text("a11y_on") : Text("a11y_off"))
                            
                            TextField("notes_placeholder", text: $note)
                                .padding(10)
                                .background(inputBackgroundColor)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        Spacer(minLength: 10)
                        
                        // 5. Update Button
                        Button(action: updateTrip) {
                            Text("update_button")
                                .font(.headline).fontWeight(.bold)
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
                    .padding(20)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("edit_trip_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .accessibilityLabel(Text("a11y_close"))
                    .accessibilityHint(Text("a11y_close_edit_trip_hint"))
                }
            }
        }
        .alert(Text("date_out_of_cycle_title"), isPresented: $showDateOutOfRangeAlert) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("date_out_of_cycle_message")
        }
        // Auto-fill logic triggers
        .onChange(of: startStation) { _, _ in recalculateMRTPrice() }
        .onChange(of: endStation) { _, _ in recalculateMRTPrice() }
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
    
    // MARK: - Logic
    
    func recalculateMRTPrice() {
        // 1. 北捷
        if selectedType == .mrt, !startStation.isEmpty, !endStation.isEmpty {
            if let fare = FareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false // 重置轉乘狀態
            }
        }
        // 2. 機捷
        else if selectedType == .tymrt, !startStation.isEmpty, !endStation.isEmpty {
            if let fare = TYMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        }
        // 3. 台鐵
        else if selectedType == .tra, !startStation.isEmpty, !endStation.isEmpty {
            let fare = TRAFareService.shared.getFare(from: startStation, to: endStation)
            price = String(fare)
            isTransfer = false
        }
        // 4. 台中捷運
        else if selectedType == .tcmrt, !startStation.isEmpty, !endStation.isEmpty {
            if let fare = TCMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        }
        // 5. 高雄捷運
        else if selectedType == .kmrt, !startStation.isEmpty, !endStation.isEmpty {
            if let fare = KMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        }
    }
    
    func calculatePaidPrice() -> Int {
        if isFree { return 0 }
        let p = Int(price) ?? 0
        // 修改：使用轉乘優惠類型計算折扣
        let discount: Int
        if isTransfer, let type = transferDiscountType {
            discount = type.discount(for: currentIdentity)
        } else {
            discount = 0
        }
        return max(0, p - discount)
    }
    
    func updateTrip() {
        guard let userId = auth.currentUser?.id, let p = Int(price) else { return }
        
        let calendar = Calendar.current
        let dateComps = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComps = calendar.dateComponents([.hour, .minute], from: time)
        
        // 获取原始时间的秒数和时分
        let originalTimeComps = calendar.dateComponents([.hour, .minute, .second], from: trip.createdAt)
        let originalSecond = originalTimeComps.second ?? 0
        
        // 判断时间是否有变化
        let timeChanged = (timeComps.hour != originalTimeComps.hour) || (timeComps.minute != originalTimeComps.minute)
        
        var finalComps = DateComponents()
        finalComps.year = dateComps.year; finalComps.month = dateComps.month; finalComps.day = dateComps.day
        finalComps.hour = timeComps.hour; finalComps.minute = timeComps.minute
        finalComps.second = timeChanged ? 0 : originalSecond
        var finalDate = calendar.date(from: finalComps) ?? date
        if let range = allowedDateRange, !range.contains(finalDate) {
            let clamped = min(max(finalDate, range.lowerBound), range.upperBound)
            finalDate = clamped
            date = clamped
            time = clamped
            showDateOutOfRangeAlert = true
        }
        
        // 修改：使用轉乘優惠類型計算折扣
        let discount: Int
        if isTransfer, let type = transferDiscountType {
            discount = type.discount(for: currentIdentity)
        } else {
            discount = 0
        }
        
        let paidPrice = isFree ? 0 : (p - discount)
        
        let updatedTrip = Trip(
            id: trip.id, // Keep the original ID
            userId: userId,
            createdAt: finalDate,
            type: selectedType,
            originalPrice: p,
            paidPrice: paidPrice,
            isTransfer: isTransfer,
            isFree: isFree,
            startStation: startStation,
            endStation: endStation,
            routeId: routeId,
            note: note,
            transferDiscountType: transferDiscountType,
            cycleId: trip.cycleId ?? resolvedCycleForTrip?.id
        )
        
        viewModel.updateTrip(updatedTrip)
        
        // 新增：成功震動回饋
        HapticManager.shared.notification(type: .success)
        
        onSuccess?()
        presentationMode.wrappedValue.dismiss()
    }
    
    // MARK: - UI Components
    
    func routeStationInputView() -> some View {
        Group {
            if selectedType == .bus {
                busSelectionView
            } else if selectedType == .coach {
                coachSelectionView
            } else if selectedType == .tra {
                traSelectionView
            } else if selectedType == .mrt {
                mrtSelectionView
            } else if selectedType == .tymrt {
                tymrtSelectionView
            } else if selectedType == .tcmrt {
                tcmrtSelectionView
            } else if selectedType == .kmrt || selectedType == .lrt {
                kmrtSelectionView
            } else {
                manualInputView
            }
        }
    }
    
    // MARK: - Subviews for Route Selection
    
    @ViewBuilder
    private var busSelectionView: some View {
        VStack(spacing: 0) {
            TextField("route_example 307", text: $routeId)
                .padding(12)
                .foregroundColor(themeManager.primaryTextColor)
            Divider().opacity(0.5).padding(.leading, 12)
            
            StationInputRow(label: "start_point", type: selectedType, lineCode: $startLineCode, stationName: $startStation, currentRegion: currentRegion)
            Divider().opacity(0.5).padding(.leading, 12)
            StationInputRow(label: "end_point", type: selectedType, lineCode: $endLineCode, stationName: $endStation, currentRegion: currentRegion)
        }
            .background(inputBackgroundColor)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private var coachSelectionView: some View {
        VStack(spacing: 0) {
            TextField("route_example 1610", text: $routeId)
                .padding(12)
                .foregroundColor(themeManager.primaryTextColor)
            Divider().opacity(0.5).padding(.leading, 12)
            
            StationInputRow(label: "start_point", type: selectedType, lineCode: $startLineCode, stationName: $startStation, currentRegion: currentRegion)
            Divider().opacity(0.5).padding(.leading, 12)
            StationInputRow(label: "end_point", type: selectedType, lineCode: $endLineCode, stationName: $endStation, currentRegion: currentRegion)
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private var traSelectionView: some View {
        VStack(spacing: 0) {
            TRALineStationInputRow(
                label: "start_point",
                regions: availableTRARegions,
                selectedRegion: $selectedStartRegion,
                stationId: $startStation
            )

            Divider().opacity(0.5).padding(.leading, 12)

            TRALineStationInputRow(
                label: "end_point",
                regions: availableTRARegions,
                selectedRegion: $selectedEndRegion,
                stationId: $endStation
            )
        }
        .onAppear {
            restoreTRARegions()
        }
    }

    // 自動反查區域 (當進入編輯模式時)
    private func restoreTRARegions() {
        if selectedType == .tra {
            let normalizedStartId = normalizedTRAStationId(startStation)
            let normalizedEndId = normalizedTRAStationId(endStation)
            startStation = normalizedStartId
            endStation = normalizedEndId

            // 找起點（使用站代碼比對）
            if let found = availableTRARegions.first(where: { $0.stations.contains(where: { $0.id == normalizedStartId }) }) {
                selectedStartRegion = found
            } else if selectedStartRegion == nil, let fallback = availableTRARegions.first {
                selectedStartRegion = fallback
            }

            // 找終點（使用站代碼比對）
            if let found = availableTRARegions.first(where: { $0.stations.contains(where: { $0.id == normalizedEndId }) }) {
                selectedEndRegion = found
            } else if selectedEndRegion == nil, let fallback = availableTRARegions.first {
                selectedEndRegion = fallback
            }
        }
    }

    private func normalizedTRAStationId(_ value: String) -> String {
        if value.isEmpty { return value }
        if availableTRARegions.contains(where: { $0.stations.contains(where: { $0.id == value }) }) {
            return value
        }
        let zhName = TRAStationData.shared.normalizeStationNameToZH(value)
        if let station = TRAStationData.shared.allStations.first(where: { $0.name == zhName }) {
            return station.id
        }
        return value
    }
    
    @ViewBuilder
    private var mrtSelectionView: some View {
        VStack(spacing: 0) {
            StationInputRow(label: "start_point", type: selectedType, lineCode: $startLineCode, stationName: $startStation, currentRegion: currentRegion)
            Divider().opacity(0.5).padding(.leading, 12)
            StationInputRow(label: "end_point", type: selectedType, lineCode: $endLineCode, stationName: $endStation, currentRegion: currentRegion)
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private var tymrtSelectionView: some View {
        VStack(spacing: 0) {
            StationInputRow(label: "start_point", type: selectedType, lineCode: $startLineCode, stationName: $startStation, currentRegion: currentRegion)
            Divider().opacity(0.5).padding(.leading, 12)
            StationInputRow(label: "end_point", type: selectedType, lineCode: $endLineCode, stationName: $endStation, currentRegion: currentRegion)
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private var tcmrtSelectionView: some View {
        VStack(spacing: 0) {
            StationInputRow(label: "start_point", type: selectedType, lineCode: $startLineCode, stationName: $startStation, currentRegion: currentRegion)
            Divider().opacity(0.5).padding(.leading, 12)
            StationInputRow(label: "end_point", type: selectedType, lineCode: $endLineCode, stationName: $endStation, currentRegion: currentRegion)
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private var kmrtSelectionView: some View {
        VStack(spacing: 0) {
            StationInputRow(label: "start_point", type: selectedType, lineCode: $startLineCode, stationName: $startStation, currentRegion: currentRegion)
            Divider().opacity(0.5).padding(.leading, 12)
            StationInputRow(label: "end_point", type: selectedType, lineCode: $endLineCode, stationName: $endStation, currentRegion: currentRegion)
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    @ViewBuilder
    private var manualInputView: some View {
        VStack(spacing: 0) {
            StationInputRow(label: "start_point", type: selectedType, lineCode: $startLineCode, stationName: $startStation, currentRegion: currentRegion)
            Divider().opacity(0.5).padding(.leading, 12)
            StationInputRow(label: "end_point", type: selectedType, lineCode: $endLineCode, stationName: $endStation, currentRegion: currentRegion)
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    // Reuse component
    func compactDatePicker(icon: String, selection: Binding<Date>, components: DatePickerComponents) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(themeManager.secondaryTextColor)
            if let range = allowedDateRange, components.contains(.date) {
                DatePicker("", selection: selection, in: range, displayedComponents: components)
                    .labelsHidden()
                    .scaleEffect(0.85)
                    .accentColor(themeManager.accentColor)
                    .accessibilityLabel(components == .date ? Text("a11y_date") : Text("a11y_time"))
            } else {
                DatePicker("", selection: selection, displayedComponents: components)
                    .labelsHidden()
                    .scaleEffect(0.85)
                    .accentColor(themeManager.accentColor)
                    .accessibilityLabel(components == .date ? Text("a11y_date") : Text("a11y_time"))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(inputBackgroundColor)
        .cornerRadius(8)
    }
    
}
