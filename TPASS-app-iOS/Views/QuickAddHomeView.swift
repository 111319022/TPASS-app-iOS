import SwiftUI

struct QuickAddHomeView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    var onSuccess: (() -> Void)? = nil
    
    private var resolvedCycleForDate: Cycle? {
        viewModel.cycleForTrip(date: date)
    }
    
    private var currentRegion: TPASSRegion {
        resolvedCycleForDate?.region ?? auth.currentRegion
    }
    
    private var currentSupportedModes: [TransportType] {
        resolvedCycleForDate?.effectiveSupportedModes ?? currentRegion.supportedModes
    }
    
    private var currentCycleId: String? {
        resolvedCycleForDate?.id
    }
    
    // 回家站點列表
    private var homeStations: [HomeStation] {
        auth.currentUser?.homeStations ?? []
    }
    
    // 篩選：只顯示當前方案支援的運具，台鐵站點需額外檢查是否在方案範圍內
    private var availableHomeStations: [HomeStation] {
        let supportedTypes = currentSupportedModes
        return homeStations.filter { station in
            // 首先檢查運具是否支援
            guard supportedTypes.contains(station.transportType) else {
                return false
            }
            
            // 如果是台鐵，需要額外檢查站點是否在方案範圍內
            if station.transportType == .tra {
                let validStations = TRAStationData.shared.getStations(for: currentRegion)
                if let stationID = TRAStationData.shared.resolveStationID(station.name) {
                    return validStations.contains(where: { $0.id == stationID })
                }
                return false
            }
            
            return true
        }
    }
    
    // === 表單狀態 ===
    @State private var date = Date()
    @State private var time = Date()
    @State private var selectedHomeStation: HomeStation?
    @State private var startStation: String = ""
    @State private var startLineCode: String = ""
    @State private var routeId: String = ""
    
    // TRA 雙欄選擇狀態
    @State private var startTRARegion: TRARegion?
    
    // 取得目前方案可用的區域列表
    private var availableTRARegions: [TRARegion] {
        TRAStationData.shared.getRegions(for: currentRegion)
    }
    
    // 金額與選項
    @State private var price: String = ""
    @State private var isTransfer: Bool = false
    @State private var isFree: Bool = false
    @State private var transferDiscountType: TransferDiscountType? = nil
    @State private var showTransferTypePicker = false
    @State private var showDateOutOfRangeAlert = false
    @State private var showNoHomeStationsAlert = false
    @State private var showHomeStationSettings = false
    
    var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
    }
    
    // 根據市民設定篩選轉乘類型
    private var filteredTransferTypes: [TransferDiscountType] {
        let allTypes = currentRegion.supportedTransferTypes
        let userCity = auth.currentUser?.citizenCity
        
        guard let userCity = userCity else {
            return allTypes
        }
        
        return allTypes.filter { transferType in
            if let requiredCity = transferType.citizenRequirement {
                return requiredCity == userCity
            }
            return true
        }
    }
    
    var isFormValid: Bool {
        selectedHomeStation != nil && !startStation.isEmpty && ((!price.isEmpty && Int(price) != nil) || isFree)
    }
    
    var inputBackgroundColor: Color {
        let isDark: Bool = {
            switch themeManager.currentTheme {
            case .dark:
                return true
            case .light, .muji, .purple:
                return false
            case .system:
                return UITraitCollection.current.userInterfaceStyle == .dark
            }
        }()
        return isDark ? Color(uiColor: .secondarySystemBackground) : Color.white
    }
    
    private var allowedCycle: Cycle? {
        viewModel.selectedCycle ?? viewModel.resolveCycle(for: date)
    }

    private var allowedDateRange: ClosedRange<Date>? {
        guard let cycle = allowedCycle else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        return start...end
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        
                        // 1. 選擇回家站點
                        if availableHomeStations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("no_home_stations_available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("no_home_stations_available_hint")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                NavigationLink(destination: HomeStationSettingsView()) {
                                    Text("go_to_settings")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(themeManager.accentColor)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(inputBackgroundColor)
                            .cornerRadius(10)
                        } else {
                            VStack(spacing: 0) {
                                Text("select_home_station")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 12)
                                    .padding(.bottom, 8)
                                
                                ForEach(availableHomeStations) { station in
                                    Button(action: {
                                        selectedHomeStation = station
                                        // 自動設定終點站和運具類型
                                        recalculatePriceForHomeStation(station)
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: station.transportType.systemIconName)
                                                .font(.title3)
                                                .foregroundColor(themeManager.transportColor(station.transportType))
                                                .frame(width: 32)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(station.name)
                                                    .font(.headline)
                                                    .foregroundColor(themeManager.primaryTextColor)
                                                Text(station.transportType.displayName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if selectedHomeStation?.id == station.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(selectedHomeStation?.id == station.id ? themeManager.accentColor.opacity(0.1) : Color.clear)
                                    }
                                    
                                    if station.id != availableHomeStations.last?.id {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                                .padding(.bottom, 12)
                            }
                            .background(inputBackgroundColor)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        }
                        
                        // 2. Date & Time
                        HStack(spacing: 12) {
                            compactDatePicker(icon: "calendar", selection: $date, components: .date)
                                .frame(maxWidth: .infinity)
                            compactDatePicker(icon: "clock", selection: $time, components: .hourAndMinute)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // 3. 起點選擇（根據選中的回家站點類型）
                        if let homeStation = selectedHomeStation {
                            startStationInputView(for: homeStation)
                        }
                        
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
                            .padding(.horizontal, 16)
                            .background(inputBackgroundColor)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                            
                            transferButton()
                                .frame(height: 50)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: { isFree.toggle() }) {
                                HStack {
                                    Image(systemName: isFree ? "gift.fill" : "gift")
                                    Text("free_trip")
                                        .font(.subheadline).fontWeight(.medium)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(isFree ? themeManager.accentColor : inputBackgroundColor)
                                .foregroundColor(isFree ? .white : themeManager.secondaryTextColor)
                                .cornerRadius(8)
                            }
                        }
                        
                        Spacer(minLength: 10)
                        
                        // 5. Add Button
                        Button(action: addTrip) {
                            Text("add_trip_button")
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
                }
            }
            .navigationTitle("quick_add_home_trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showHomeStationSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .confirmationDialog("transfer", isPresented: $showTransferTypePicker) {
                transferTypeDialogActions
            }
            .sheet(isPresented: $showHomeStationSettings) {
                NavigationView {
                    HomeStationSettingsView(showCloseButton: true)
                }
            }
        }
        .alert(Text("date_out_of_cycle_title"), isPresented: $showDateOutOfRangeAlert) {
            Button("date_out_of_cycle_cancel_action", role: .cancel) { }
            Button("date_out_of_cycle_force_add_action") {
                addTrip(forceAdjustOutOfRangeDate: true)
            }
        } message: {
            Text("date_out_of_cycle_force_add_message")
        }
        .onAppear {
            // 設定當前時間，避免秒數錯誤
            let now = Date()
            date = now
            time = now
        }
        .onChange(of: startStation) { _, _ in
            if let homeStation = selectedHomeStation {
                recalculatePriceForHomeStation(homeStation)
            }
        }
        .onChange(of: date) { _, _ in
            refreshBusDefaultPriceIfNeeded()
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
                    transferDiscountType = filteredTransferTypes.first
                }
            } else {
                transferDiscountType = nil
            }
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func startStationInputView(for homeStation: HomeStation) -> some View {
        VStack(spacing: 0) {
            if homeStation.transportType == .bus {
                TextField("route_example 307", text: $routeId)
                    .padding(12)
                    .foregroundColor(themeManager.primaryTextColor)
                Divider().opacity(0.5).padding(.leading, 12)
                
                StationInputRow(
                    label: "start_point",
                    type: homeStation.transportType,
                    lineCode: $startLineCode,
                    stationName: $startStation,
                    currentRegion: currentRegion
                )
            } else if homeStation.transportType == .tra {
                TRALineStationInputRow(
                    label: "start_point",
                    regions: availableTRARegions,
                    selectedRegion: $startTRARegion,
                    stationId: $startStation
                )
            } else if homeStation.transportType == .mrt || homeStation.transportType == .tymrt || homeStation.transportType == .tcmrt || homeStation.transportType == .kmrt || homeStation.transportType == .hsr {
                StationInputRow(
                    label: "start_point",
                    type: homeStation.transportType,
                    lineCode: $startLineCode,
                    stationName: $startStation,
                    currentRegion: currentRegion
                )
            }
        }
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
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
                    transferDiscountType = filteredTransferTypes.first
                }
            } else if filteredTransferTypes.isEmpty {
                isTransfer = false
                transferDiscountType = nil
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
        .disabled(filteredTransferTypes.isEmpty)
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
    
    func compactDatePicker(icon: String, selection: Binding<Date>, components: DatePickerComponents) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(width: 20)
            
            if let range = allowedDateRange {
                DatePicker("", selection: selection, in: range, displayedComponents: components)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .accentColor(themeManager.accentColor)
            } else {
                DatePicker("", selection: selection, displayedComponents: components)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .accentColor(themeManager.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(inputBackgroundColor)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    
    // MARK: - Logic

    private func refreshBusDefaultPriceIfNeeded() {
        guard let homeStation = selectedHomeStation, homeStation.transportType == .bus else { return }
        price = currentRegion.defaultBusPrice(identity: currentIdentity)
        isTransfer = false
    }
    
    func recalculatePriceForHomeStation(_ homeStation: HomeStation) {
        if homeStation.transportType == .bus {
            price = currentRegion.defaultBusPrice(identity: currentIdentity)
            isTransfer = false
            return
        }

        guard !startStation.isEmpty else { return }
        
        let endStation = homeStation.name
        
        switch homeStation.transportType {
        case .mrt:
            if let fare = TPEMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        case .tymrt:
            if let fare = TYMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        case .tra:
            guard let startStationID = TRAStationData.shared.resolveStationID(startStation),
                  let endStationID = TRAStationData.shared.resolveStationID(endStation) else { return }
            let fare = TRAFareService.shared.getFare(from: startStationID, to: endStationID)
            price = String(fare)
            isTransfer = false
        case .tcmrt:
            if let fare = TCMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        case .kmrt:
            if let fare = KMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        case .hsr:
            if let fare = THSRFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        default:
            break
        }
    }
    
    func calculatePaidPrice() -> Int {
        if isFree { return 0 }
        let p = Int(price) ?? 0
        let discount: Int
        if isTransfer, let type = transferDiscountType {
            discount = type.discount(for: currentIdentity)
        } else {
            discount = 0
        }
        return max(0, p - discount)
    }
    
    func addTrip() {
        addTrip(forceAdjustOutOfRangeDate: false)
    }

    private func addTrip(forceAdjustOutOfRangeDate: Bool) {
        guard let userId = auth.currentUser?.id,
              let homeStation = selectedHomeStation,
              let p = Int(price) else { return }
        
        let calendar = Calendar.current
        let dateComps = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComps = calendar.dateComponents([.hour, .minute], from: time)
        let secondsNow = calendar.component(.second, from: Date())
        
        var finalComps = DateComponents()
        finalComps.year = dateComps.year
        finalComps.month = dateComps.month
        finalComps.day = dateComps.day
        finalComps.hour = timeComps.hour
        finalComps.minute = timeComps.minute
        finalComps.second = secondsNow
        var finalDate = calendar.date(from: finalComps) ?? date
        
        if let range = allowedDateRange, !range.contains(finalDate) {
            if !forceAdjustOutOfRangeDate {
                showDateOutOfRangeAlert = true
                HapticManager.shared.notification(type: .warning)
                return
            }

            finalDate = range.lowerBound
            date = range.lowerBound
            time = range.lowerBound
        }

        let resolvedCycleId = viewModel.cycleForTrip(date: finalDate)?.id ?? currentCycleId
        
        let discount: Int
        if isTransfer, let type = transferDiscountType {
            discount = type.discount(for: currentIdentity)
        } else {
            discount = 0
        }
        
        let paidPrice = isFree ? 0 : (p - discount)
        
        let newTrip = Trip(
            id: String(Int64(Date().timeIntervalSince1970 * 1000)),
            userId: userId,
            createdAt: finalDate,
            type: homeStation.transportType,
            originalPrice: p,
            paidPrice: paidPrice,
            isTransfer: isTransfer,
            isFree: isFree,
            startStation: startStation,
            endStation: homeStation.name,
            routeId: routeId,
            note: "",
            transferDiscountType: transferDiscountType,
            cycleId: resolvedCycleId
        )
        
        viewModel.addTrip(newTrip)
        
        HapticManager.shared.notification(type: .success)
        
        onSuccess?()
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    QuickAddHomeView()
        .environmentObject(AppViewModel())
        .environmentObject(AuthService.shared)
        .environmentObject(ThemeManager.shared)
}
