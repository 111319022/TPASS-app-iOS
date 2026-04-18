import SwiftUI

struct FavoritesManagementView: View {

    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var onQuickAdd: ((String) -> Void)? = nil
    var onQuickAddCommuter: ((String) -> Void)? = nil
    
    @State private var editingCommuterRoute: CommuterRoute? = nil
    @State private var showToast = false
    @State private var toastMessage: LocalizedStringKey = ""
    @State private var swipedFavIds: Set<UUID> = []
    @State private var swipedCommuterIds: Set<UUID> = []
    
    private var screenBackground: Color {
        switch themeManager.currentTheme {
        case .muji:
            return Color(hex: "#f5f0eb")
        case .light, .purple:
            return Color(uiColor: .systemGroupedBackground)
        case .dark:
            return Color(uiColor: .secondarySystemBackground)
        case .system:
            return colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemGroupedBackground)
        }
    }
    
    private var rowBackground: Color {
        switch themeManager.currentTheme {
        case .dark:
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .system:
            return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : themeManager.cardBackgroundColor
        case .muji, .light, .purple:
            return themeManager.cardBackgroundColor
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(screenBackground)
                    .ignoresSafeArea()
                
                if viewModel.favorites.isEmpty && viewModel.commuterRoutes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 48))
                            .foregroundColor(themeManager.secondaryTextColor)
                        Text("favorites_empty_title")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        Text("favorites_empty_desc")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        if !viewModel.favorites.isEmpty {
                            Section(header: sectionHeader("favoriteRoutes")) {
                                ForEach(viewModel.favorites) { fav in
                                    favoriteButtonWithActions(fav)
                                }
                            }
                        } else {
                            Section(header: sectionHeader("favoriteRoutes")) {
                                Text("favorites_empty_favorites_only_desc")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                    .listRowBackground(themeManager.cardBackgroundColor)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        
                        if !viewModel.commuterRoutes.isEmpty {
                            Section(header: sectionHeader("commuterRoutes")) {
                                ForEach(viewModel.commuterRoutes) { route in
                                    commuterRouteButtonWithActions(route)
                                }
                            }
                        } else {
                            Section(header: sectionHeader("commuterRoutes")) {
                                Text("favorites_empty_commuter_only_desc")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                    .listRowBackground(themeManager.cardBackgroundColor)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .navigationTitle("favoriteRoutes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") {
                        dismiss()
                    }
                    .font(.system(.body, design: .default))
                    .foregroundColor(themeManager.accentColor)
                }
            }
            .sheet(item: $editingCommuterRoute) { route in
                CommuterRouteDetailView(routeId: route.id)
            }
            
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(25)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
    }
    
    private func showToast(message: LocalizedStringKey) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }

    private func favoriteTitleText(_ fav: FavoriteRoute) -> Text {
        // 🔧 修正：檢查是否有起訖站資訊
        let hasStations = !fav.startStation.isEmpty && !fav.endStation.isEmpty
        
        if fav.type == .bus || fav.type == .coach {
            // 如果有起訖站就顯示，沒有就只顯示路線編號
            if hasStations {
                let lang = Locale.current.identifier
                let start = displayStationName(fav.startStation, type: fav.type, languageCode: lang)
                let end = displayStationName(fav.endStation, type: fav.type, languageCode: lang)
                return Text("route_title_bus \(fav.routeId)") + Text(" (") + Text(fav.type.displayName) + Text(")") + Text("\n\(start) → \(end)")
            } else {
                return Text("route_title_bus \(fav.routeId)") + Text(" (") + Text(fav.type.displayName) + Text(")")
            }
        }
        
        let lang = Locale.current.identifier
        let start = displayStationName(fav.startStation, type: fav.type, languageCode: lang)
        let end = displayStationName(fav.endStation, type: fav.type, languageCode: lang)
        return Text("\(start) → \(end)")
    }
    
    //     新增：取得本地化的路線名稱字串 (解決 Toast 顯示資料庫代碼的問題)
    private func getLocalizedRouteName(_ fav: FavoriteRoute) -> String {
        let lang = Locale.current.identifier
        
        // 🔧 修正：檢查是否有起訖站資訊
        let hasStations = !fav.startStation.isEmpty && !fav.endStation.isEmpty
        
        // 1. 公車/客運
        if fav.type == .bus || fav.type == .coach {
            if hasStations {
                // 有起訖站，顯示完整資訊
                let start = displayStationName(fav.startStation, type: fav.type, languageCode: lang)
                let end = displayStationName(fav.endStation, type: fav.type, languageCode: lang)
                if lang.hasPrefix("en") {
                    return "Route \(fav.routeId) (\(start) → \(end))"
                } else {
                    return String(localized: "route_title_bus \(fav.routeId)") + " (\(start) → \(end))"
                }
            } else {
                // 沒有起訖站，只顯示路線編號
                if lang.hasPrefix("en") {
                    return "Route \(fav.routeId)"
                } else {
                    return String(localized: "route_title_bus \(fav.routeId)")
                }
            }
        }
        
        // 2. 軌道運輸 (捷運/台鐵/機捷)
        let start = displayStationName(fav.startStation, type: fav.type, languageCode: lang)
        let end = displayStationName(fav.endStation, type: fav.type, languageCode: lang)
        return "\(start) → \(end)"
    }
    
    private func displayStationName(_ stationName: String, type: TransportType, languageCode: String) -> String {
        if type == .tymrt {
            return TYMRTStationData.shared.displayStationName(stationName, languageCode: languageCode)
        } else if type == .hsr {
            return HSRStationData.shared.displayStationName(stationName, languageCode: languageCode)
        } else if type == .tra {
            return TRAStationData.shared.displayStationName(stationName, languageCode: languageCode)
        } else if type == .tcmrt {
            return TCMRTStationData.shared.displayStationName(stationName, languageCode: languageCode)
        } else if type == .kmrt {
            return KMRTStationData.shared.displayStationName(stationName, languageCode: languageCode)
        } else {
            return StationData.shared.displayStationName(stationName, languageCode: languageCode)
        }
    }
    
    @ViewBuilder
    private func favoriteButtonWithActions(_ fav: FavoriteRoute) -> some View {
        Button(action: {
            //     修正：使用 getLocalizedRouteName 取得正確的站名
            let routeName = getLocalizedRouteName(fav)
            
            viewModel.quickAddTrip(from: fav)
            
            //     [新增] 震動：快速新增成功
            HapticManager.shared.notification(type: .success)
            
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onQuickAdd?(routeName)
            }
        }) {
            favoriteRowView(fav, rowBackground: rowBackground)
        }

        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.removeFavorite(fav)
                swipedFavIds.remove(fav.id)
                
                //     [新增] 震動：刪除成功
                HapticManager.shared.notification(type: .success)
            } label: {
                Label("delete", systemImage: "trash.fill")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removeFavorite(fav)
                swipedFavIds.remove(fav.id)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func commuterRouteButtonWithActions(_ route: CommuterRoute) -> some View {
        ZStack(alignment: .trailing) {
            // 1. 底層主要按鈕 (新增通勤路線)
            Button(action: {
                let routeName = route.name
                viewModel.quickAddCommuterRoute(route)
                
                //     [新增] 震動：快速新增整組成功
                HapticManager.shared.notification(type: .success)
                
                showToast(message: "favorites_added_commuter \(routeName)")
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onQuickAddCommuter?(routeName)
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.name)
                            .font(.system(.body, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryTextColor)
                        Text("count_trips \(route.tripCount)")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    Spacer()
                    // 預留右側空間，避免文字與編輯圖示重疊
                    Color.clear.frame(width: 44, height: 20)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(rowBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.secondaryTextColor.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // 2. 編輯圖示 (改用 TapGesture 以防按鈕衝突)
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(width: 44, height: 44) // 固定點擊熱區大小
                .contentShape(Rectangle())   // 確保整格都可以點
                .onTapGesture {
                    // 這裡會優先攔截點擊，不會觸發底層的 Button
                    editingCommuterRoute = route
                }
                .padding(.trailing, 8)
        }
        
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.removeCommuterRoute(route)
                swipedCommuterIds.remove(route.id)
                
                //     [新增] 震動：刪除成功
                HapticManager.shared.notification(type: .success)
            } label: {
                Label("delete", systemImage: "trash.fill")
            }
        }
        .contextMenu {
            Button {
                editingCommuterRoute = route
            } label: {
                Label("edit", systemImage: "square.and.pencil")
            }

            Button(role: .destructive) {
                viewModel.removeCommuterRoute(route)
                swipedCommuterIds.remove(route.id)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func favoriteRowView(_ fav: FavoriteRoute, rowBackground: Color) -> some View {
        HStack(spacing: 12) {
            favoriteIconView(fav.type)
            
            VStack(alignment: .leading, spacing: 2) {
                favoriteTitleText(fav)
                    .font(.system(.body, design: .default))
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryTextColor)
                
                HStack(spacing: 8) {
                    Text("$\(fav.price)")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    if fav.isFree {
                        Text("free_trip")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    if fav.isTransfer {
                        Text("transfer")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.accentColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(themeManager.accentColor)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(rowBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.secondaryTextColor.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.05), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(themeManager.secondaryTextColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private func favoriteIconView(_ type: TransportType) -> some View {
        ZStack {
            Circle()
                .fill(themeManager.transportColor(type).opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: type.systemIconName)
                .font(.system(size: 16))
                .foregroundColor(themeManager.transportColor(type))
        }
    }
    
    @ViewBuilder
    private func favoriteDetailView(_ fav: FavoriteRoute) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            favoriteTitleText(fav)
                .font(.system(.body, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryTextColor)
            
            HStack(spacing: 8) {
                Text("$\(fav.price)")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                if fav.isFree {
                    Text("free")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                if fav.isTransfer {
                    Text("transfer")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - CommuterRouteDetailView
struct CommuterRouteDetailView: View {
        @EnvironmentObject var viewModel: AppViewModel
        @EnvironmentObject var auth: AuthService
        @EnvironmentObject var themeManager: ThemeManager
        @Environment(\.dismiss) var dismiss
        @Environment(\.colorScheme) var colorScheme
        
        let routeId: UUID
        
        private var route: CommuterRoute? {
            viewModel.commuterRoutes.first(where: { $0.id == routeId })
        }
        
        private var screenBackground: Color {
            switch themeManager.currentTheme {
            case .muji:
                return Color(hex: "#f5f0eb")
            case .light, .purple:
                return Color(uiColor: .systemGroupedBackground)
            case .dark:
                return Color(uiColor: .secondarySystemBackground)
            case .system:
                return colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemGroupedBackground)
            }
        }
        
        private var rowBackground: Color {
            themeManager.cardBackgroundColor.opacity(themeManager.currentTheme == .dark ? 0.88 : 1)
        }

        private var currentIdentity: Identity {
            auth.currentUser?.identity ?? .adult
        }

        private func tripTitleText(_ trip: CommuterTripTemplate) -> Text {
            // 🔧 修正：檢查是否有起訖站資訊
            let hasStations = !trip.startStation.isEmpty && !trip.endStation.isEmpty
            
            if trip.type == .bus || trip.type == .coach {
                // 如果有起訖站就顯示，沒有就只顯示路線編號
                if hasStations {
                    let start = displayStationNameForCommuter(trip.startStation, type: trip.type)
                    let end = displayStationNameForCommuter(trip.endStation, type: trip.type)
                    return Text("route_title_bus \(trip.routeId)") + Text(" (") + Text(trip.type.displayName) + Text(")") + Text("\n\(start) → \(end)")
                } else {
                    return Text("route_title_bus \(trip.routeId)") + Text(" (") + Text(trip.type.displayName) + Text(")")
                }
            }
            
            let start = displayStationNameForCommuter(trip.startStation, type: trip.type)
            let end = displayStationNameForCommuter(trip.endStation, type: trip.type)
            return Text("\(start) → \(end)")
        }
        
        private func displayStationNameForCommuter(_ stationName: String, type: TransportType) -> String {
            let lang = Locale.current.identifier
            if type == .tymrt {
                return TYMRTStationData.shared.displayStationName(stationName, languageCode: lang)
            } else if type == .hsr {
                return HSRStationData.shared.displayStationName(stationName, languageCode: lang)
            } else if type == .tra {
                return TRAStationData.shared.displayStationName(stationName, languageCode: lang)
            } else if type == .tcmrt {
                return TCMRTStationData.shared.displayStationName(stationName, languageCode: lang)
            } else if type == .kmrt {
                return KMRTStationData.shared.displayStationName(stationName, languageCode: lang)
            } else {
                return StationData.shared.displayStationName(stationName, languageCode: lang)
            }
        }
        
        var body: some View {
            NavigationView {
                ZStack {
                    Rectangle()
                        .fill(screenBackground)
                        .ignoresSafeArea()
                    
                    if let route = route, !route.trips.isEmpty {
                        List {
                            ForEach(route.trips) { trip in
                                HStack(spacing: 12) {
                                    // 運具 icon
                                    Image(systemName: trip.type.systemIconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.transportColor(trip.type))
                                        .frame(width: 24, alignment: .center)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        tripTitleText(trip)
                                            .font(.system(.body, design: .default))
                                            .fontWeight(.semibold)
                                            .foregroundColor(themeManager.primaryTextColor)
                                        Text(trip.timeString)
                                            .font(.caption)
                                            .foregroundColor(themeManager.secondaryTextColor)
                                        if trip.isTransfer {
                                            Text(trip.transferDiscountType?.displayNameKey(for: currentIdentity) ?? "transfer")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(themeManager.accentColor)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(themeManager.accentColor.opacity(0.15))
                                                .cornerRadius(6)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("$\(trip.price)")
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                    
                                        Button(action: {
                                            viewModel.removeCommuterTrip(routeId: routeId, tripId: trip.id)
                                        }) {
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                .background(rowBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(themeManager.secondaryTextColor.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.08), lineWidth: 1)
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.removeCommuterTrip(routeId: routeId, tripId: trip.id)
                                    } label: {
                                        Label("delete", systemImage: "trash.fill")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 36))
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("commuter_route_empty")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryTextColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle(route?.name ?? String(localized: "commuter_route"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("done") {
                            dismiss()
                        }
                        .font(.system(.body, design: .default))
                        .foregroundColor(themeManager.accentColor)
                    }
                }
            }
        }
    }
