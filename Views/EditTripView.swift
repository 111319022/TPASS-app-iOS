import SwiftUI

struct EditTripView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var localizationManager: LocalizationManager
    
    // The trip to be edited (passed in)
    let trip: Trip
    var onSuccess: (() -> Void)? = nil
    
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
    
    // Price and Options
    @State private var price: String
    @State private var note: String
    @State private var isTransfer: Bool
    @State private var isFree: Bool
    
    // Identity (for calculating discount)
    var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
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
    
    // 🔥 Custom init to load existing trip data
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
                            ForEach(TransportType.allCases) { type in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedType = type
                                        // Unlike Add, we don't clear fields immediately when editing to prevent accidental data loss,
                                        // unless user explicitly wants to clear. Or we can keep the logic consistent:
                                        if type == .bus {
                                            startStation = ""; endStation = ""
                                            // Only reset price if it was empty or switching from non-bus
                                            if price.isEmpty { price = (currentIdentity == .student) ? "12" : "15" }
                                        } else {
                                            if type != .coach { routeId = "" }
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
                            }
                        }
                        .padding(.bottom, 5)
                        
                        // 3. Route/Station Input
                        VStack(spacing: 0) {
                            if selectedType == .bus || selectedType == .coach {
                                TextField(localizationManager.localizedFormat("route_example", selectedType == .bus ? "307" : "1610"), text: $routeId)
                                    .padding(12)
                                    .foregroundColor(themeManager.primaryTextColor)
                                
                                if selectedType == .coach {
                                    Divider().opacity(0.5).padding(.leading, 12)
                                }
                            }
                            
                            if selectedType != .bus {
                                VStack(spacing: 0) {
                                    StationInputRow(label: localizationManager.localized("start_point"), type: selectedType, lineCode: $startLineCode, stationName: $startStation)
                                    Divider().opacity(0.5).padding(.leading, 12)
                                    StationInputRow(label: localizationManager.localized("end_point"), type: selectedType, lineCode: $endLineCode, stationName: $endStation)
                                }
                            }
                        }
                        .background(inputBackgroundColor)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        
                        // 4. Price & Options
                        HStack(spacing: 12) {
                            HStack {
                                Text("$").font(.headline).foregroundColor(themeManager.secondaryTextColor)
                                TextField(localizationManager.localized("price_placeholder"), text: $price)
                                    .keyboardType(.numberPad)
                                    .font(.title3.bold())
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .frame(height: 50)
                            .padding(.horizontal, 12)
                            .background(inputBackgroundColor)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                            
                            Button(action: { isTransfer.toggle() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isTransfer ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                    Text("\(localizationManager.localized("transfer")) (-\(currentIdentity.transferDiscount))")
                                        .font(.subheadline).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.8)
                                }
                                .frame(maxHeight: .infinity).padding(.horizontal, 12)
                                .background(isTransfer ? Color(hex: "#27ae60") : inputBackgroundColor)
                                .foregroundColor(isTransfer ? .white : themeManager.secondaryTextColor)
                                .cornerRadius(10)
                            }
                            .frame(height: 50)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: { isFree.toggle() }) {
                                HStack {
                                    Image(systemName: isFree ? "gift.fill" : "gift")
                                    Text(localizationManager.localized("free_trip"))
                                        .font(.subheadline).fontWeight(.medium)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(isFree ? themeManager.accentColor : inputBackgroundColor)
                                .foregroundColor(isFree ? .white : themeManager.secondaryTextColor)
                                .cornerRadius(8)
                            }
                            
                            TextField(localizationManager.localized("notes_placeholder"), text: $note)
                                .padding(10)
                                .background(inputBackgroundColor)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        Spacer(minLength: 10)
                        
                        // 5. Update Button
                        Button(action: updateTrip) {
                            Text(localizationManager.localized("update_button"))
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
            .navigationTitle(localizationManager.localized("edit_trip_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
        }
        // Auto-fill logic triggers
        .onChange(of: startStation) { _ in recalculateMRTPrice() }
        .onChange(of: endStation) { _ in recalculateMRTPrice() }
        .onChange(of: isFree) { val in if val { isTransfer = false; price = "0" } }
        .onChange(of: isTransfer) { val in if val { isFree = false } }
    }
    
    // MARK: - Logic
    
    func recalculateMRTPrice() {
        // 北捷站點變化時自動查詢票價
        if selectedType == .mrt, !startStation.isEmpty, !endStation.isEmpty {
            if let fare = FareService.shared.getFare(from: startStation, to: endStation) {
                price = String(fare)
                isTransfer = false // 重置轉乘狀態
            }
        }
    }
    
    func calculatePaidPrice() -> Int {
        if isFree { return 0 }
        let p = Int(price) ?? 0
        let discount = isTransfer ? currentIdentity.transferDiscount : 0
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
        let finalDate = calendar.date(from: finalComps) ?? date
        
        // 🔥 Create updated trip object (using SAME ID)
        let updatedTrip = Trip(
            id: trip.id, // Keep the original ID
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
            note: note
        )
        
        viewModel.updateTrip(updatedTrip)
        onSuccess?()
        presentationMode.wrappedValue.dismiss()
    }
    
    // Reuse component
    func compactDatePicker(icon: String, selection: Binding<Date>, components: DatePickerComponents) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundColor(themeManager.secondaryTextColor)
            DatePicker("", selection: selection, displayedComponents: components)
                .labelsHidden().scaleEffect(0.85).accentColor(themeManager.accentColor)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(inputBackgroundColor)
        .cornerRadius(8)
    }
}
