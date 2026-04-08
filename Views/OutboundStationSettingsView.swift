import SwiftUI

struct OutboundStationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager

    var showCloseButton: Bool = false
    @State private var showAddStation = false

    var outboundStations: [OutboundStation] {
        auth.currentUser?.outboundStations ?? []
    }

    var body: some View {
        List {
            if outboundStations.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.walk.circle")
                            .font(.system(size: 48))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("no_departure_stations")
                            .font(.headline)
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("no_departure_stations_hint")
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
                    ForEach(outboundStations) { station in
                        OutboundStationRow(station: station)
                    }
                    .onDelete(perform: deleteStations)
                } header: {
                    Text("departure_stations_list")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .navigationTitle("departure_stations_settings")
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
            AddOutboundStationView()
        }
    }

    private func deleteStations(at offsets: IndexSet) {
        for index in offsets {
            let station = outboundStations[index]
            auth.deleteOutboundStation(station)
        }
    }
}

struct OutboundStationRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let station: OutboundStation

    private var displayStationName: String {
        let lang = Locale.current.identifier
        switch station.transportType {
        case .mrt:
            return StationData.shared.displayStationName(station.name, languageCode: lang)
        case .tymrt:
            return TYMRTStationData.shared.displayStationName(station.name, languageCode: lang)
        case .hsr:
            return HSRStationData.shared.displayStationName(station.name, languageCode: lang)
        case .tcmrt:
            return TCMRTStationData.shared.displayStationName(station.name, languageCode: lang)
        case .kmrt, .lrt:
            return KMRTStationData.shared.displayStationName(station.name, languageCode: lang)
        case .tra:
            return TRAStationData.shared.displayStationName(station.name, languageCode: lang)
        default:
            return station.name
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: station.transportType.systemIconName)
                .font(.title2)
                .foregroundColor(themeManager.transportColor(station.transportType))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayStationName)
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

struct AddOutboundStationView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedType: TransportType = .mrt
    @State private var stationName: String = ""
    @State private var lineCode: String = ""

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
                    Picker("transport_type", selection: $selectedType) {
                        ForEach(TransportType.allCases.filter { type in
                            type == .mrt || type == .tra || type == .bus || type == .coach || type == .tymrt || type == .tcmrt || type == .kmrt || type == .hsr || type == .bike
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
                                    Text(displayLineOrRegionName(selectedLine, for: selectedType))
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
                                        Text(displayStationName(stationName, for: selectedType))
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else if selectedType == .tymrt || selectedType == .hsr {
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
                                    Text(displayStationName(stationName, for: selectedType))
                                        .foregroundColor(themeManager.accentColor)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if selectedType == .tra {
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
                                    Text(displayLineOrRegionName(selectedLine, for: selectedType))
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
                                        Text(displayStationName(stationName, for: selectedType))
                                            .foregroundColor(themeManager.accentColor)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        TextField("station_name", text: $stationName)
                    }
                } header: {
                        Text("departure_station_info")
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColor)
                    .navigationTitle("add_departure_station")
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
                        saveOutboundStation()
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
                        selectorRow(name: StationData.shared.displayLineName(line.name, languageCode: Locale.current.identifier), isSelected: selectedLine == line.name) {
                            selectedLine = line.name
                            lineCode = line.code
                            stationName = ""
                            showLineSelector = false
                        }
                    }
                } else if selectedType == .tcmrt {
                    ForEach(TCMRTStationData.shared.lines, id: \.code) { line in
                        selectorRow(name: TCMRTStationData.shared.displayLineName(line.name, languageCode: Locale.current.identifier), isSelected: selectedLine == line.name) {
                            selectedLine = line.name
                            lineCode = line.code
                            stationName = ""
                            showLineSelector = false
                        }
                    }
                } else if selectedType == .kmrt {
                    ForEach(KMRTStationData.shared.lines, id: \.code) { line in
                        selectorRow(name: KMRTStationData.shared.displayLineName(line.name, languageCode: Locale.current.identifier), isSelected: selectedLine == line.name) {
                            selectedLine = line.name
                            lineCode = line.code
                            stationName = ""
                            showLineSelector = false
                        }
                    }
                } else if selectedType == .tra {
                    ForEach(TRAStationData.shared.getAllRegions(), id: \.name) { region in
                        selectorRow(name: TRAStationData.shared.displayRegionName(region.name, languageCode: Locale.current.identifier), isSelected: selectedLine == region.name) {
                            selectedLine = region.name
                            lineCode = ""
                            stationName = ""
                            showLineSelector = false
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
                            selectorRow(name: StationData.shared.displayStationName(station, languageCode: Locale.current.identifier), isSelected: stationName == station) {
                                stationName = station
                                showStationSelector = false
                            }
                        }
                    }
                } else if selectedType == .tymrt {
                    let stations = TYMRTStationData.shared.availableStations(for: currentRegion)
                    ForEach(stations, id: \.self) { station in
                        let displayName = TYMRTStationData.shared.displayStationName(station, languageCode: Locale.current.identifier)
                        selectorRow(name: displayName, isSelected: stationName == station) {
                            stationName = station
                            showStationSelector = false
                        }
                    }
                } else if selectedType == .hsr {
                    let stations = HSRStationData.shared.availableStations(for: currentRegion)
                    ForEach(stations, id: \.self) { station in
                        let displayName = HSRStationData.shared.displayStationName(station, languageCode: Locale.current.identifier)
                        selectorRow(name: displayName, isSelected: stationName == station) {
                            stationName = station
                            showStationSelector = false
                        }
                    }
                } else if selectedType == .tcmrt {
                    if let line = TCMRTStationData.shared.lines.first(where: { $0.name == selectedLine }) {
                        ForEach(line.stations, id: \.self) { station in
                            selectorRow(name: TCMRTStationData.shared.displayStationName(station, languageCode: Locale.current.identifier), isSelected: stationName == station) {
                                stationName = station
                                showStationSelector = false
                            }
                        }
                    }
                } else if selectedType == .kmrt {
                    if let line = KMRTStationData.shared.lines.first(where: { $0.name == selectedLine }) {
                        ForEach(line.stations, id: \.self) { station in
                            selectorRow(name: KMRTStationData.shared.displayStationName(station, languageCode: Locale.current.identifier), isSelected: stationName == station) {
                                stationName = station
                                showStationSelector = false
                            }
                        }
                    }
                } else if selectedType == .tra {
                    if let region = TRAStationData.shared.getAllRegions().first(where: { $0.name == selectedLine }) {
                        ForEach(region.stations, id: \.id) { station in
                            selectorRow(name: TRAStationData.shared.displayStationName(station.id, languageCode: Locale.current.identifier), isSelected: stationName == station.id) {
                                stationName = station.id
                                showStationSelector = false
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

    private func selectorRow(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(themeManager.accentColor)
                }
            }
        }
    }

    private func saveOutboundStation() {
        let normalizedName: String
        if selectedType == .tra {
            normalizedName = TRAStationData.shared.resolveStationID(stationName) ?? stationName
        } else {
            normalizedName = stationName
        }
        let finalLineCode = lineCode.isEmpty ? nil : lineCode
        auth.addOutboundStation(name: normalizedName, transportType: selectedType, lineCode: finalLineCode)
        HapticManager.shared.notification(type: .success)
        presentationMode.wrappedValue.dismiss()
    }

    private func displayLineOrRegionName(_ value: String, for type: TransportType) -> String {
        let lang = Locale.current.identifier
        switch type {
        case .mrt:
            return StationData.shared.displayLineName(value, languageCode: lang)
        case .tcmrt:
            return TCMRTStationData.shared.displayLineName(value, languageCode: lang)
        case .kmrt, .lrt:
            return KMRTStationData.shared.displayLineName(value, languageCode: lang)
        case .tra:
            return TRAStationData.shared.displayRegionName(value, languageCode: lang)
        default:
            return value
        }
    }

    private func displayStationName(_ value: String, for type: TransportType) -> String {
        let lang = Locale.current.identifier
        switch type {
        case .mrt:
            return StationData.shared.displayStationName(value, languageCode: lang)
        case .tymrt:
            return TYMRTStationData.shared.displayStationName(value, languageCode: lang)
        case .hsr:
            return HSRStationData.shared.displayStationName(value, languageCode: lang)
        case .tcmrt:
            return TCMRTStationData.shared.displayStationName(value, languageCode: lang)
        case .kmrt, .lrt:
            return KMRTStationData.shared.displayStationName(value, languageCode: lang)
        case .tra:
            return TRAStationData.shared.displayStationName(value, languageCode: lang)
        default:
            return value
        }
    }
}

#Preview {
    NavigationStack {
        OutboundStationSettingsView()
            .environmentObject(AuthService.shared)
            .environmentObject(ThemeManager.shared)
    }
}