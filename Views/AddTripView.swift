import SwiftUI

struct AddTripView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager

    
    var onSuccess: (() -> Void)? = nil
    
    // === 表單狀態 ===
    @State private var date = Date()
    @State private var time = Date()
    @State private var selectedType: TransportType = .mrt
    
    // 路線與站點
    @State private var routeId: String = ""
    @State private var startStation: String = ""
    @State private var endStation: String = ""
    @State private var startLineCode: String = ""
    @State private var endLineCode: String = ""
    
    // TRA 區域選擇（起站和終點分開）
    @State private var selectedTRARegionStart: String = ""
    @State private var selectedTRARegionEnd: String = ""
    
    // 金額與選項
    @State private var price: String = ""
    @State private var note: String = ""
    @State private var isTransfer: Bool = false
    @State private var isFree: Bool = false
    
    var currentIdentity: Identity {
        auth.currentUser?.identity ?? .adult
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
                        HStack(spacing: 12) {
                            compactDatePicker(icon: "calendar", selection: $date, components: .date)
                                .frame(maxWidth: .infinity, minHeight: 52)
                            compactDatePicker(icon: "clock", selection: $time, components: .hourAndMinute)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        
                        // MARK: - 2. 運具選擇 (Grid)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(TransportType.allCases) { type in
                                Button(action: {
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
                                    .background(selectedType == type ? themeManager.transportColor(type) : inputBackgroundColor)
                                    .foregroundColor(selectedType == type ? .white : themeManager.secondaryTextColor)
                                    .cornerRadius(10)
                                    .shadow(color: selectedType == type ? themeManager.transportColor(type).opacity(0.3) : Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.bottom, 5)
                        
                        // MARK: - 3. 路線/站點輸入 (修正邏輯)
                        VStack(spacing: 0) {
                            // 公車
                            if selectedType == .bus {
                                TextField("route_example 307", text: $routeId)
                                    .padding(12)
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            // 客運
                            else if selectedType == .coach {
                                VStack(spacing: 0) {
                                    TextField("route_example 1610", text: $routeId)
                                        .padding(12)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Divider().opacity(0.5).padding(.leading, 12)
                                    
                                    StationInputRow(
                                        label: "start_point",
                                        type: selectedType,
                                        lineCode: $startLineCode,
                                        stationName: $startStation
                                    )
                                    
                                    Divider().opacity(0.5).padding(.leading, 12)
                                    
                                    StationInputRow(
                                        label: "end_point",
                                        type: selectedType,
                                        lineCode: $endLineCode,
                                        stationName: $endStation
                                    )
                                }
                            }
                            // 台鐵 - 兩欄設計
                            else if selectedType == .tra {
                                let stationData = TRAStationData.shared
                                let traRegions = stationData.regions
                                let traSelectedRegionStart = traRegions.first { $0.id == selectedTRARegionStart }
                                let traStationsStart = traSelectedRegionStart?.stations ?? []
                                let traSelectedRegionEnd = traRegions.first { $0.id == selectedTRARegionEnd }
                                let traStationsEnd = traSelectedRegionEnd?.stations ?? []
                                
                                // 起站
                                HStack(spacing: 0) {
                                    Menu {
                                        ForEach(traRegions, id: \.id) { region in
                                            Button(TRAStationData.shared.displayRegionName(region.name, languageCode: Locale.current.identifier)) {
                                                selectedTRARegionStart = region.id
                                                startStation = ""
                                            }
                                        }
                                    } label: {
                                        HStack {
                                        Text(TRAStationData.shared.displayRegionName(traSelectedRegionStart?.name ?? "", languageCode: Locale.current.identifier).isEmpty ? (Locale.current.identifier.hasPrefix("en") ? "Select Region" : "選擇區域") : TRAStationData.shared.displayRegionName(traSelectedRegionStart?.name ?? "", languageCode: Locale.current.identifier))
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(maxHeight: .infinity)
                                        .background(Color.gray.opacity(0.05))
                                    }
                                    
                                    Divider()
                                    
                                    Menu {
                                        ForEach(traStationsStart, id: \.id) { station in
                                            Button(TRAStationData.shared.displayStationName(station.name, languageCode: Locale.current.identifier)) {
                                                startStation = station.id
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(TRAStationData.shared.displayStationName(traStationsStart.first { $0.id == startStation }?.name ?? "", languageCode: Locale.current.identifier).isEmpty ? (Locale.current.identifier.hasPrefix("en") ? "Select Station" : "選擇車站") : TRAStationData.shared.displayStationName(traStationsStart.first { $0.id == startStation }?.name ?? "", languageCode: Locale.current.identifier))
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(maxHeight: .infinity)
                                        .foregroundColor(traStationsStart.isEmpty ? Color.gray : themeManager.primaryTextColor)
                                    }
                                    .disabled(traStationsStart.isEmpty)
                                }
                                .frame(height: 44)
                                .foregroundColor(themeManager.primaryTextColor)
                                
                                Divider().opacity(0.5).padding(.leading, 12)
                                
                                // 終點
                                HStack(spacing: 0) {
                                    Menu {
                                        ForEach(traRegions, id: \.id) { region in
                                            Button(TRAStationData.shared.displayRegionName(region.name, languageCode: Locale.current.identifier)) {
                                                selectedTRARegionEnd = region.id
                                                endStation = ""
                                            }
                                        }
                                    } label: {
                                        HStack {
                                        Text(TRAStationData.shared.displayRegionName(traSelectedRegionEnd?.name ?? "", languageCode: Locale.current.identifier).isEmpty ? (Locale.current.identifier.hasPrefix("en") ? "Select Region" : "選擇區域") : TRAStationData.shared.displayRegionName(traSelectedRegionEnd?.name ?? "", languageCode: Locale.current.identifier))
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(maxHeight: .infinity)
                                        .background(Color.gray.opacity(0.05))
                                    }
                                    
                                    Divider()
                                    
                                    Menu {
                                        ForEach(traStationsEnd, id: \.id) { station in
                                            Button(TRAStationData.shared.displayStationName(station.name, languageCode: Locale.current.identifier)) {
                                                endStation = station.id
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(TRAStationData.shared.displayStationName(traStationsEnd.first { $0.id == endStation }?.name ?? "", languageCode: Locale.current.identifier).isEmpty ? (Locale.current.identifier.hasPrefix("en") ? "Select Station" : "選擇車站") : TRAStationData.shared.displayStationName(traStationsEnd.first { $0.id == endStation }?.name ?? "", languageCode: Locale.current.identifier))
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 12)
                                        .frame(maxHeight: .infinity)
                                        .foregroundColor(traStationsEnd.isEmpty ? Color.gray : themeManager.primaryTextColor)
                                    }
                                    .disabled(traStationsEnd.isEmpty)
                                }
                                .frame(height: 44)
                                .foregroundColor(themeManager.primaryTextColor)
                            }
                            // 其他運具
                            else {
                                VStack(spacing: 0) {
                                    StationInputRow(
                                        label: "start_point",
                                        type: selectedType,
                                        lineCode: $startLineCode,
                                        stationName: $startStation
                                    )
                                    
                                    Divider().opacity(0.5).padding(.leading, 12)
                                    
                                    StationInputRow(
                                        label: "end_point",
                                        type: selectedType,
                                        lineCode: $endLineCode,
                                        stationName: $endStation
                                    )
                                }
                            }
                        }
                        .background(inputBackgroundColor)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        
                        // MARK: - 4. 價格與選項
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
                            
                            Button(action: { isTransfer.toggle() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isTransfer ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                                    (Text("transfer") + Text(" (-\(currentIdentity.transferDiscount))"))
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxHeight: .infinity)
                                .padding(.horizontal, 12)
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
                            
                            TextField("notes_placeholder_add", text: $note)
                                .padding(10)
                                .background(inputBackgroundColor)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        
                        Spacer(minLength: 10)
                        
                        // MARK: - 5. 按鈕
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
                    .padding(20)
                }
            }
            .navigationTitle("add_trip_title")
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
        // 固定高度，取消滑動展開
        .presentationDetents([.height(650)])
        .presentationDragIndicator(.hidden)
        
        .onChange(of: startStation) { _, _ in tryAutoFillFromHistory() }
        .onChange(of: endStation) { _, _ in tryAutoFillFromHistory() }
        .onChange(of: routeId) { _, _ in tryAutoFillFromHistory() }
        .onChange(of: isFree) { _, val in if val { isTransfer = false; price = "0" } }
        .onChange(of: isTransfer) { _, val in if val { isFree = false } }
    }
    
    // MARK: - 邏輯處理
    func handleTypeChange(_ newType: TransportType) {
        // 重置邏輯
        if newType == .bus {
            startStation = ""; endStation = ""
            price = (currentIdentity == .student) ? "12" : "15"
        } else {
            // 切換其他運具時
            // 如果不是客運，才清空 routeId (因為客運需要 routeId)
            if newType != .coach { routeId = "" }
            // 🔥 清空起读站
            startStation = ""
            endStation = ""
            startLineCode = ""
            endLineCode = ""
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
        // 3. 台鐵查價邏輯
        if selectedType == .tra, !startStation.isEmpty, !endStation.isEmpty {
            let traPrice = TRAFareService.shared.getFare(from: startStation, to: endStation)
            price = String(traPrice)
            return
        }
        // 4. 歷史紀錄查詢
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
                // 北捷、機捷或其他：比對起訖站
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
        let discount = isTransfer ? currentIdentity.transferDiscount : 0
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
        let finalDate = calendar.date(from: finalComps) ?? date
        
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
            note: note
        )
        viewModel.addTrip(newTrip)
        presentationMode.wrappedValue.dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSuccess?()
        }
    }
    
    // MARK: - UI Components
    
    func compactDatePicker(icon: String, selection: Binding<Date>, components: DatePickerComponents) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(themeManager.secondaryTextColor)
            DatePicker("", selection: selection, displayedComponents: components)
                .labelsHidden()
                .scaleEffect(0.85)
                .accentColor(themeManager.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(inputBackgroundColor)
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 站點輸入列 (修正：50/50 分割)
struct StationInputRow: View {
    let label: LocalizedStringKey
    let type: TransportType
    @Binding var lineCode: String
    @Binding var stationName: String
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            
            // === 1. 北捷 (MRT) 雙層選單 ===
            if type == .mrt {
                Menu {
                    ForEach(StationData.shared.lines) { line in
                        Button(action: {
                            lineCode = line.code
                            stationName = ""
                        }) {
                            Text(StationData.shared.displayLineName(line.name, languageCode: Locale.current.identifier))
                        }
                    }
                } label: {
                    HStack {
                        Text(label).font(.caption).foregroundColor(themeManager.primaryTextColor).padding(.leading, 12)
                        Spacer()
                        if let line = StationData.shared.lines.first(where: { $0.code == lineCode }) {
                            Text(StationData.shared.displayLineName(line.name, languageCode: Locale.current.identifier))
                                .font(.subheadline).fontWeight(.bold).foregroundColor(line.color).lineLimit(1).minimumScaleFactor(0.8)
                        } else {
                            Text("select_route").font(.subheadline).foregroundColor(themeManager.primaryTextColor)
                        }
                        Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor).padding(.trailing, 8)
                    }
                    .frame(maxHeight: .infinity).frame(maxWidth: .infinity).background(Color.gray.opacity(0.05))
                }
                
                Divider()
                
                Menu {
                    if let line = StationData.shared.lines.first(where: { $0.code == lineCode }) {
                        ForEach(line.stations, id: \.self) { station in
                            Button(action: { stationName = station }) {
                                Text(StationData.shared.displayStationName(station, languageCode: Locale.current.identifier))
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
                            Text(StationData.shared.displayStationName(stationName, languageCode: Locale.current.identifier))
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        Spacer()
                        Image(systemName: "chevron.down").font(.caption2).foregroundColor(themeManager.primaryTextColor)
                    }
                    .padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
            // === 2. 桃園機捷 (TYMRT) 單層選單 ===
            } else if type == .tymrt {
                // 左邊：顯示標籤和機捷名稱 (50%)
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.leading, 12)
                    Spacer()
                    Text("機場捷運", comment: "Airport MRT line name")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#8246AF"))
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
                .contentShape(Rectangle())
                
                Divider()
                
                // 右邊：站點選單 (50%)
                Menu {
                    ForEach(TYMRTStationData.shared.line.stations, id: \.self) { station in
                        Button(action: { stationName = station }) {
                            Text(TYMRTStationData.shared.displayStationName(station, languageCode: Locale.current.identifier))
                        }
                    }
                } label: {
                    HStack {
                        if stationName.isEmpty {
                            Text("選擇站點", comment: "Select station placeholder")
                                .foregroundColor(themeManager.secondaryTextColor)
                        } else {
                            Text(TYMRTStationData.shared.displayStationName(stationName, languageCode: Locale.current.identifier))
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
                }
                
            // === 3. 其他運具 (手動輸入) ===
            } else {
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
        .frame(height: 48)
    }
}
