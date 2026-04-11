import SwiftUI

struct QuickAddOutboundView: View {
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

    private var currentCycleId: String? {
        resolvedCycleForDate?.id
    }

    private var outboundStations: [OutboundStation] {
        auth.currentUser?.outboundStations ?? []
    }

    private var availableOutboundStations: [OutboundStation] {
        let supportedTypes = currentRegion.supportedModes
        return outboundStations.filter { station in
            guard supportedTypes.contains(station.transportType) else {
                return false
            }

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

    @State private var date = Date()
    @State private var time = Date()
    @State private var selectedOutboundStation: OutboundStation?
    @State private var endStation: String = ""
    @State private var endLineCode: String = ""
    @State private var routeId: String = ""
    @State private var endTRARegion: TRARegion?
    @State private var price: String = ""
    @State private var isTransfer: Bool = false
    @State private var isFree: Bool = false
    @State private var transferDiscountType: TransferDiscountType? = nil
    @State private var showTransferTypePicker = false
    @State private var showDateOutOfRangeAlert = false
    @State private var showOutboundStationSettings = false

    var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
    }

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

    private var availableTRARegions: [TRARegion] {
        TRAStationData.shared.getRegions(for: currentRegion)
    }

    var isFormValid: Bool {
        selectedOutboundStation != nil && !endStation.isEmpty && ((!price.isEmpty && Int(price) != nil) || isFree)
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
                        if availableOutboundStations.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.walk.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("no_departure_stations_available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("no_departure_stations_available_hint")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                NavigationLink(destination: OutboundStationSettingsView()) {
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
                                Text("select_departure_station")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 12)
                                    .padding(.bottom, 8)

                                ForEach(availableOutboundStations) { station in
                                    Button(action: {
                                        selectedOutboundStation = station
                                        endStation = ""
                                        endLineCode = ""
                                        endTRARegion = nil
                                        routeId = ""
                                        price = ""
                                        isTransfer = false
                                        transferDiscountType = nil
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

                                            if selectedOutboundStation?.id == station.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(selectedOutboundStation?.id == station.id ? themeManager.accentColor.opacity(0.1) : Color.clear)
                                    }

                                    if station.id != availableOutboundStations.last?.id {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                                .padding(.bottom, 12)
                            }
                            .background(inputBackgroundColor)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        }

                        HStack(spacing: 12) {
                            compactDatePicker(icon: "calendar", selection: $date, components: .date)
                                .frame(maxWidth: .infinity)
                            compactDatePicker(icon: "clock", selection: $time, components: .hourAndMinute)
                                .frame(maxWidth: .infinity)
                        }

                        if let outboundStation = selectedOutboundStation {
                            endStationInputView(for: outboundStation)
                        }

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
            .navigationTitle("quick_add_departure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showOutboundStationSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(themeManager.accentColor)
                    }
                }
            }
            .confirmationDialog("transfer", isPresented: $showTransferTypePicker) {
                transferTypeDialogActions
            }
            .sheet(isPresented: $showOutboundStationSettings) {
                NavigationView {
                    OutboundStationSettingsView(showCloseButton: true)
                }
            }
        }
        .alert(Text("date_out_of_cycle_title"), isPresented: $showDateOutOfRangeAlert) {
            Button("ok", role: .cancel) { }
        } message: {
            Text("date_out_of_cycle_message")
        }
        .onAppear {
            let now = Date()
            date = now
            time = now
        }
        .onChange(of: endStation) { _, _ in
            if let outboundStation = selectedOutboundStation {
                recalculatePriceForOutboundStation(outboundStation)
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
                    transferDiscountType = filteredTransferTypes.first
                }
            } else {
                transferDiscountType = nil
            }
        }
    }

    @ViewBuilder
    private func endStationInputView(for outboundStation: OutboundStation) -> some View {
        VStack(spacing: 0) {
            if outboundStation.transportType == .bus {
                TextField("route_example 307", text: $routeId)
                    .padding(12)
                    .foregroundColor(themeManager.primaryTextColor)
                Divider().opacity(0.5).padding(.leading, 12)

                StationInputRow(
                    label: "end_point",
                    type: outboundStation.transportType,
                    lineCode: $endLineCode,
                    stationName: $endStation,
                    currentRegion: currentRegion
                )
            } else if outboundStation.transportType == .tra {
                TRALineStationInputRow(
                    label: "end_point",
                    regions: availableTRARegions,
                    selectedRegion: $endTRARegion,
                    stationId: $endStation
                )
            } else if outboundStation.transportType == .mrt || outboundStation.transportType == .tymrt || outboundStation.transportType == .tcmrt || outboundStation.transportType == .kmrt || outboundStation.transportType == .hsr {
                StationInputRow(
                    label: "end_point",
                    type: outboundStation.transportType,
                    lineCode: $endLineCode,
                    stationName: $endStation,
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

    func recalculatePriceForOutboundStation(_ outboundStation: OutboundStation) {
        guard !endStation.isEmpty else { return }

        let startStation = outboundStation.name

        switch outboundStation.transportType {
        case .mrt:
            if let fare = TPEMRTFareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false
            }
        case .tymrt:
            if auth.currentUser?.citizenCity == .taoyuan,
               let citizenFare = TYMRTFareService.shared.getCitizenFare(from: startStation, to: endStation) {
                price = String(citizenFare)
                isTransfer = false
            } else if let fare = TYMRTFareService.shared.getFare(from: startStation, to: endStation) {
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
        case .bus:
            if price.isEmpty {
                price = currentRegion.defaultBusPrice(identity: currentIdentity)
            }
        default:
            break
        }
    }

    func addTrip() {
        guard let userId = auth.currentUser?.id,
              let outboundStation = selectedOutboundStation,
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
            let clamped = min(max(finalDate, range.lowerBound), range.upperBound)
            finalDate = clamped
            date = clamped
            time = clamped
            showDateOutOfRangeAlert = true
        }

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
            type: outboundStation.transportType,
            originalPrice: p,
            paidPrice: paidPrice,
            isTransfer: isTransfer,
            isFree: isFree,
            startStation: outboundStation.name,
            endStation: endStation,
            routeId: routeId,
            note: "",
            transferDiscountType: transferDiscountType,
            cycleId: currentCycleId
        )

        viewModel.addTrip(newTrip)

        HapticManager.shared.notification(type: .success)

        onSuccess?()
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    QuickAddOutboundView()
        .environmentObject(AppViewModel())
        .environmentObject(AuthService.shared)
        .environmentObject(ThemeManager.shared)
}