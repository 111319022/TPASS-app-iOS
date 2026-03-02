import SwiftUI

struct HomeStationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    var showCloseButton: Bool = false
    @State private var showAddStation = false
    
    var homeStations: [HomeStation] {
        auth.currentUser?.homeStations ?? []
    }
    
    var body: some View {
        List {
            if homeStations.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 48))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("no_home_stations")
                            .font(.headline)
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("no_home_stations_hint")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(homeStations) { station in
                        HomeStationRow(station: station)
                    }
                    .onDelete(perform: deleteStations)
                } header: {
                    Text("home_stations_list")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .navigationTitle("home_stations_settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showCloseButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showAddStation = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .sheet(isPresented: $showAddStation) {
            AddHomeStationView()
        }
    }
    
    private func deleteStations(at offsets: IndexSet) {
        for index in offsets {
            let station = homeStations[index]
            auth.deleteHomeStation(station)
        }
    }
}

struct HomeStationRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let station: HomeStation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: station.transportType.systemIconName)
                .font(.title2)
                .foregroundColor(themeManager.transportColor(station.transportType))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                HStack(spacing: 4) {
                    Text(station.transportType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lineCode = station.lineCode, !lineCode.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lineCode)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AddHomeStationView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedType: TransportType = .mrt
    @State private var stationName: String = ""
    @State private var lineCode: String = ""
    
    // 雙層選單狀態
    @State private var selectedLine: String = ""
    @State private var showLineSelector = false
    @State private var showStationSelector = false
    
    var currentRegion: TPASSRegion {
        auth.currentRegion
    }
    
    var isFormValid: Bool {
        !stationName.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // 運具類型選擇
                    Picker("transport_type", selection: $selectedType) {
                        ForEach(TransportType.allCases.filter { type in
                            // 只顯示有站點的運具類型
                            type == .mrt || type == .tra || type == .bus || type == .coach || type == .tymrt || type == .tcmrt || type == .kmrt || type == .bike
                        }) { type in
                            HStack {
                                Image(systemName: type.systemIconName)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedType) { _, _ in
                        // 切換運具類型時清空選擇
                        stationName = ""
                        lineCode = ""
                        selectedLine = ""
                    }
                } header: {
                    Text("select_transport_type")
                        .foregroundColor(themeManager.secondaryTextColor)
                }
                
                Section {
                    if selectedType == .mrt || selectedType == .tcmrt || selectedType == .kmrt {
                        // 捷運：雙層選單（線路 -> 站點）
                        Button(action: {
                            showLineSelector = true
                        }) {
                            HStack {
                                Text("select_line")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if selectedLine.isEmpty {
                                    Text("please_select")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(selectedLine)
                                        .foregroundColor(themeManager.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !selectedLine.isEmpty {
                            Button(action: {
                                showStationSelector = true
                            }) {
                                HStack {
                                    Text("station")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                    if stationName.isEmpty {
                                        Text("please_select")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(stationName)
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else if selectedType == .tymrt {
                        // 機捷：直接選站點（沒有線路概念）
                        Button(action: {
                            showStationSelector = true
                        }) {
                            HStack {
                                Text("station")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if stationName.isEmpty {
                                    Text("please_select")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(stationName)
                                        .foregroundColor(themeManager.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if selectedType == .tra {
                        // 台鐵：雙層選單（區域 -> 站點）
                        Button(action: {
                            showLineSelector = true
                        }) {
                            HStack {
                                Text("select_region")
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if selectedLine.isEmpty {
                                    Text("please_select")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(selectedLine)
                                        .foregroundColor(themeManager.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !selectedLine.isEmpty {
                            Button(action: {
                                showStationSelector = true
                            }) {
                                HStack {
                                    Text("station")
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                    if stationName.isEmpty {
                                        Text("please_select")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(stationName)
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        // 公車、客運、Ubike 站點手動輸入
                        TextField("station_name", text: $stationName)
                    }
                } header: {
                    Text("home_station_info")
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColor)
            .navigationTitle("add_home_station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeManager.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save") {
                        saveHomeStation()
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? themeManager.accentColor : themeManager.secondaryTextColor)
                }
            }
            .sheet(isPresented: $showLineSelector) {
                lineSelectorView()
            }
            .sheet(isPresented: $showStationSelector) {
                stationSelectorView()
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    @ViewBuilder
    private func lineSelectorView() -> some View {
        NavigationView {
            List {
                if selectedType == .mrt {
                    ForEach(StationData.shared.lines.filter { $0.code != "AIRTRAIN" }, id: \.code) { line in
                        Button(action: {
                            selectedLine = line.name
                            lineCode = line.code
                            stationName = ""  // 清空站點選擇
                            showLineSelector = false
                        }) {
                            HStack {
                                Text(line.name)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if selectedLine == line.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                    }
                } else if selectedType == .tcmrt {
                    ForEach(TCMRTStationData.shared.lines, id: \.code) { line in
                        Button(action: {
                            selectedLine = line.name
                            lineCode = line.code
                            stationName = ""
                            showLineSelector = false
                        }) {
                            HStack {
                                Text(line.name)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if selectedLine == line.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                    }
                } else if selectedType == .kmrt {
                    ForEach(KMRTStationData.shared.lines, id: \.code) { line in
                        Button(action: {
                            selectedLine = line.name
                            lineCode = line.code
                            stationName = ""
                            showLineSelector = false
                        }) {
                            HStack {
                                Text(line.name)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if selectedLine == line.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                    }
                } else if selectedType == .tra {
                    ForEach(TRAStationData.shared.getAllRegions(), id: \.name) { region in
                        Button(action: {
                            selectedLine = region.name
                            lineCode = ""
                            stationName = ""
                            showLineSelector = false
                        }) {
                            HStack {
                                Text(region.name)
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if selectedLine == region.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColor)
            .navigationTitle(selectedType == .tra ? "select_region" : "select_line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel") {
                        showLineSelector = false
                    }
                    .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    @ViewBuilder
    private func stationSelectorView() -> some View {
        NavigationView {
            List {
                if selectedType == .mrt {
                    if let line = StationData.shared.lines.first(where: { $0.name == selectedLine }) {
                        ForEach(line.stations, id: \.self) { station in
                            Button(action: {
                                stationName = station
                                showStationSelector = false
                            }) {
                                HStack {
                                    Text(station)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                    if stationName == station {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } else if selectedType == .tymrt {
                    let stations = TYMRTStationData.shared.availableStations(for: currentRegion)
                    ForEach(stations, id: \.self) { station in
                        Button(action: {
                            stationName = station
                            showStationSelector = false
                        }) {
                            HStack {
                                Text(TYMRTStationData.shared.displayStationName(station, languageCode: Locale.current.identifier))
                                    .foregroundColor(themeManager.primaryTextColor)
                                Spacer()
                                if stationName == station {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.accentColor)
                                }
                            }
                        }
                    }
                } else if selectedType == .tcmrt {
                    if let line = TCMRTStationData.shared.lines.first(where: { $0.name == selectedLine }) {
                        ForEach(line.stations, id: \.self) { station in
                            Button(action: {
                                stationName = station
                                showStationSelector = false
                            }) {
                                HStack {
                                    Text(station)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                    if stationName == station {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } else if selectedType == .kmrt {
                    if let line = KMRTStationData.shared.lines.first(where: { $0.name == selectedLine }) {
                        ForEach(line.stations, id: \.self) { station in
                            Button(action: {
                                stationName = station
                                showStationSelector = false
                            }) {
                                HStack {
                                    Text(station)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                    if stationName == station {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } else if selectedType == .tra {
                    if let region = TRAStationData.shared.getAllRegions().first(where: { $0.name == selectedLine }) {
                        ForEach(region.stations, id: \.id) { station in
                            Button(action: {
                                stationName = station.name
                                showStationSelector = false
                            }) {
                                HStack {
                                    Text(station.name)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Spacer()
                                    if stationName == station.name {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColor)
            .navigationTitle("select_station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel") {
                        showStationSelector = false
                    }
                    .foregroundColor(themeManager.accentColor)
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    
    private func saveHomeStation() {
        let finalLineCode = lineCode.isEmpty ? nil : lineCode
        auth.addHomeStation(name: stationName, transportType: selectedType, lineCode: finalLineCode)
        HapticManager.shared.notification(type: .success)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    NavigationStack {
        HomeStationSettingsView()
            .environmentObject(AuthService.shared)
            .environmentObject(ThemeManager.shared)
    }
}
