import SwiftUI

struct TripListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    //@EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    
    // 統一的水平邊距，確保所有元素對齊
    private let horizontalPagePadding: CGFloat = 20
    
    @State private var showAddTripSheet = false
    @State private var showFavoritesSheet = false
    @State private var selectedTripToEdit: Trip?
    @State private var isProcessingSwipeAction = false
    @State private var pendingDuplicateDate: String? = nil
    @State private var pendingDeleteDate: String? = nil
    @State private var pendingCommuterTrip: Trip? = nil
    @State private var commuterRouteName: String = ""
    @State private var showCommuterNamePrompt = false
    @State private var showCommuterRoutePicker = false
    
    @State private var isToastShowing = false
    @State private var toastMessage: LocalizedStringKey = ""
    
    var cardBackground: Color {
        themeManager.cardBackgroundColor
    }
    
    private var commmuterPickerOverlay: some View {
        ZStack {
            Color.black.opacity(themeManager.currentTheme == .dark ? 0.55 : 0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("choose_commuter")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                
                Text("choose_commuter_desc")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryTextColor)
                
                VStack(spacing: 8) {
                    let names = Array(Set(viewModel.commuterRoutes.map { $0.name })).sorted()
                    
                    VStack(spacing: 0) {
                        ForEach(names.indices, id: \.self) { index in
                            let name = names[index]
                            Button(action: {
                                if let trip = pendingCommuterTrip {
                                    viewModel.addToCommuterRoute(from: trip, name: name)
                                    showToast(message: "commuter_added \(name)")
                                }
                                pendingCommuterTrip = nil
                                showCommuterRoutePicker = false
                            }) {
                                Text(name)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .font(.system(.body, design: .default))
                            }
                            if index < names.count - 1 {
                                Divider()
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .background(themeManager.cardBackgroundColor.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(themeManager.secondaryTextColor.opacity(0.15), lineWidth: 1)
                    )
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: {
                    showCommuterNamePrompt = true
                    showCommuterRoutePicker = false
                }) {
                    Text("add_other")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.accentColor.opacity(0.12))
                        .foregroundColor(themeManager.accentColor)
                        .cornerRadius(8)
                        .font(.system(.body, design: .default))
                        .fontWeight(.semibold)
                }
                
                Button(action: {
                    showCommuterRoutePicker = false
                }) {
                    Text("cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(themeManager.cardBackgroundColor.opacity(0.9))
                        .foregroundColor(themeManager.primaryTextColor)
                        .cornerRadius(8)
                        .font(.system(.body, design: .default))
                }
            }
            .padding(24)
            .background(themeManager.cardBackgroundColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.4 : 0.2), radius: 10, x: 0, y: 4)
            .padding(24)
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(themeManager.backgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("tripList")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryTextColor)
                        Spacer()
                        
                        Button(action: { showFavoritesSheet = true }) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(themeManager.accentColor)
                                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    }
                    .padding(.horizontal, horizontalPagePadding).padding(.top, 10).padding(.bottom, 10)
                    
                    // CycleSelectorView
                    CycleSelectorView().padding(.horizontal, horizontalPagePadding).padding(.bottom, 10)
                    
                    if viewModel.groupedTrips.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 36))
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("noTripsRecorded")
                                .font(.headline)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .multilineTextAlignment(.center)
                    } else {
                        List {
                            ForEach(viewModel.groupedTrips) { group in
                                Section {
                                    // 行程列表
                                    ForEach(group.trips) { trip in
                                        tripRowWithActions(trip)
                                    }
                                } header: {
                                    // 🔥 關鍵修正：日期 Header 放在 Section header
                                    // 這樣 SwiftUI 就不會把它當成「第一個 swipe row」
                                    DailyHeaderView(
                                        group: group,
                                        onDuplicate: {
                                            viewModel.duplicateDayTrips(from: group.date)
                                            showToast(message: "copied_day \(group.date)")
                                        },
                                        onDelete: {
                                            viewModel.deleteDayTrips(on: group.date)
                                            showToast(message: "deleted_day \(group.date)")
                                        }
                                    )
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, horizontalPagePadding)
                                        .padding(.top, 6)
                                        .padding(.bottom, 4)
                                        .background(themeManager.backgroundColor)
                                        .listRowInsets(.init())
                                        .listRowBackground(Color.clear)
                                }
                                .listSectionSeparator(.hidden)
                            }
                            Color.clear.frame(height: 80).listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .environment(\.defaultMinListHeaderHeight, 0)
                        .environment(\.defaultMinListRowHeight, 0)
                    }
                }
                
                // 浮動新增按鈕
                VStack {
                    Spacer()
                    Button(action: { showAddTripSheet = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                            Text("addTrip_btn")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(Color(hex: "#2c3e50"))
                        .cornerRadius(30)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 20)
                }
                
                // Toast
                if isToastShowing {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(25)
                            .padding(.bottom, 90)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(100)
                }
                
                // Commuter Picker Overlay
                if showCommuterRoutePicker {
                    commmuterPickerOverlay
                        .zIndex(101)
                }
                
            }
            // 關鍵修正：隱藏導航列，解決滑動跳動問題
            .toolbar(.hidden, for: .navigationBar)
            .modifier(TripListSheetsModifier(
                showAddTripSheet: $showAddTripSheet,
                showFavoritesSheet: $showFavoritesSheet,
                selectedTripToEdit: $selectedTripToEdit,
                showToast: showToast
            ))
            .modifier(TripListAlertsModifier(
                pendingDuplicateDate: $pendingDuplicateDate,
                pendingDeleteDate: $pendingDeleteDate,
                showCommuterNamePrompt: $showCommuterNamePrompt,
                commuterRouteName: $commuterRouteName,
                pendingCommuterTrip: $pendingCommuterTrip,
                showToast: showToast
            ))
            
        }
        .onAppear {
            if let user = auth.currentUser, viewModel.selectedCycle == nil, let firstCycle = user.cycles.first {
                viewModel.selectedCycle = firstCycle
            }
        }
        .onChange(of: auth.currentUser) { user in
            if let user = user, viewModel.selectedCycle == nil, let firstCycle = user.cycles.first {
                viewModel.selectedCycle = firstCycle
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func showToast(message: LocalizedStringKey) {
        toastMessage = message
        withAnimation { isToastShowing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isToastShowing = false }
        }
    }
    
    @ViewBuilder
    private func tripRowWithActions(_ trip: Trip) -> some View {
        Button {
            selectedTripToEdit = trip
        } label: {
            TripRowView(trip: trip)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .padding(.vertical, 4)
        .buttonStyle(StaticButtonStyle())
        .contextMenu {
            tripContextMenuContent(trip: trip)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            tripTrailingSwipeAction(trip)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            tripLeadingSwipeActions(trip)
        }
    }
    
    @ViewBuilder
    private func tripTrailingSwipeAction(_ trip: Trip) -> some View {
        Button(role: .destructive) {
            viewModel.deleteTrip(trip)
            showToast(message: "trip_deleted")
        } label: {
            Label("delete", systemImage: "trash.fill")
        }
        .tint(.red)
    }
    
    @ViewBuilder
    private func tripLeadingSwipeActions(_ trip: Trip) -> some View {
        Button {
            guard !isProcessingSwipeAction else { return }
            isProcessingSwipeAction = true
            let wasTransfer = trip.isTransfer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                var tx = Transaction(animation: nil)
                withTransaction(tx) {
                    viewModel.toggleTransfer(trip)
                }
                showToast(message: wasTransfer ? "transfer_cancelled" : "transfer_added")
                isProcessingSwipeAction = false
            }
        } label: {
            Label(trip.isTransfer ? "cancel_transfer" : "add_transfer", systemImage: trip.isTransfer ? "link.badge.plus" : "link")
        }
        .tint(themeManager.accentColor)
        .disabled(isProcessingSwipeAction)
        
        Button {
            guard !isProcessingSwipeAction else { return }
            isProcessingSwipeAction = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                var tx = Transaction(animation: nil)
                withTransaction(tx) {
                    viewModel.duplicateTrip(trip)
                }
                showToast(message: "trip_duplicated")
                isProcessingSwipeAction = false
            }
        } label: {
            Label("duplicate_trip", systemImage: "doc.on.doc.fill")
        }
        .tint(themeManager.accentColor)
        .disabled(isProcessingSwipeAction)
        
        Button {
            guard !isProcessingSwipeAction else { return }
            isProcessingSwipeAction = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                var tx = Transaction(animation: nil)
                withTransaction(tx) {
                    viewModel.createReturnTrip(trip)
                }
                showToast(message: "trip_added")
                isProcessingSwipeAction = false
            }
        } label: {
            Label("return_trip", systemImage: "arrow.uturn.backward")
        }
        .tint(themeManager.accentColor)
        .disabled(isProcessingSwipeAction)
    }
    
    @ViewBuilder
    func tripContextMenuContent(trip: Trip) -> some View {
        Button {
            viewModel.addToFavorites(from: trip)
            showToast(message: "favorite_route_added")
        } label: {
            Label("add_to_favorites", systemImage: "star")
        }
        
        Button {
            pendingCommuterTrip = trip
            commuterRouteName = ""
            if viewModel.commuterRoutes.isEmpty {
                showCommuterNamePrompt = true
            } else {
                showCommuterRoutePicker = true
            }
        } label: {
            Label("add_to_commuter", systemImage: "briefcase.fill")
        }
        
        Divider()
        
        Button {
            viewModel.toggleTransfer(trip)
            showToast(message: trip.isTransfer ? "transfer_cancelled" : "transfer_added")
        } label: {
            Label(trip.isTransfer ? "cancel_transfer" : "add_transfer", systemImage: trip.isTransfer ? "link.badge.minus" : "link")
        }
        
        Button {
            viewModel.duplicateTrip(trip)
            showToast(message: "trip_duplicated")
        } label: {
            Label("duplicate_trip", systemImage: "doc.on.doc.fill")
        }
        
        Button {
            viewModel.createReturnTrip(trip)
            showToast(message: "trip_added")
        } label: {
            Label("return_trip", systemImage: "arrow.uturn.backward")
        }
        
        Divider()
        
        Button(role: .destructive) {
            viewModel.deleteTrip(trip)
            showToast(message: "trip_deleted")
        } label: {
            Label("delete", systemImage: "trash.fill")
        }
    }
}

// MARK: - Sub Views

struct CycleSelectorView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    var cardBackground: Color {
        switch themeManager.currentTheme {
        case .muji:
            return Color.white
        case .light:
            return Color.white
        case .dark:
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .system:
            return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
        }
    }
    
    var body: some View {
        Menu {
            Button { viewModel.selectedCycle = nil } label: {
                if viewModel.selectedCycle == nil { Label("currentCycleAuto", systemImage: "checkmark") }
                else { Text("currentCycleAuto") }
            }
            Divider()
            if let cycles = auth.currentUser?.cycles {
                ForEach(cycles) { cycle in
                    Button { viewModel.selectedCycle = cycle } label: {
                        if viewModel.selectedCycle?.id == cycle.id { Label(cycle.title, systemImage: "checkmark") }
                        else { Text(cycle.title) }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(themeManager.secondaryTextColor)
                Text(viewModel.cycleDateRange)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct DailyHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    let group: DailyTripGroup
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    @State private var showActions = false
    
    var cardBackground: Color {
        switch themeManager.currentTheme {
        case .muji:
            return Color.white
        case .light:
            return Color.white
        case .dark:
            return Color(uiColor: .secondarySystemGroupedBackground)
        case .system:
            return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
        }
    }
    
    var body: some View {
        ZStack {
            themeManager.cardBackgroundColor.opacity(0.95)
                .cornerRadius(12)
            
            HStack(spacing: 8) {
                Text(group.date)
                    .font(.headline)
                    .foregroundColor(themeManager.primaryTextColor)
                Spacer()
                Text("$\(group.dailyTotal)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(themeManager.currentTheme == .muji ? Color.black.opacity(0.05) : Color(UIColor.systemGray6))
                    .cornerRadius(8)
                
                Button {
                    showActions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .font(.caption)
                        .padding(.leading, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .confirmationDialog("day_actions_title", isPresented: $showActions, titleVisibility: .visible) {
                    Button("duplicate_day") {
                        onDuplicate()
                    }
                    Button("delete_day", role: .destructive) {
                        onDelete()
                    }
                    Button("cancel", role: .cancel) { }
                } message: {
                    Text("day_actions \(group.date)")
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showActions = true
        }
    }
}

struct TripRowView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let trip: Trip
    
    var body: some View {
        HStack(spacing: 15) {
            let themeColor = themeManager.transportColor(trip.type)
            
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: trip.type.systemIconName)
                    .font(.system(size: 18))
                    .foregroundColor(themeColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(trip.type.displayName)
                        .font(.headline)
                        .foregroundColor(themeColor)
                    
                    let details = [
                        trip.routeId.isEmpty ? nil : trip.routeId,
                        (trip.startStation.isEmpty || trip.endStation.isEmpty) ? nil : "\(StationData.shared.displayStationName(trip.startStation, languageCode: Locale.current.identifier)) → \(StationData.shared.displayStationName(trip.endStation, languageCode: Locale.current.identifier))"
                    ].compactMap { $0 }.joined(separator: " ")
                    
                    if !details.isEmpty {
                        Text("|")
                            .foregroundColor(themeManager.secondaryTextColor)
                            .font(.system(size: 12))
                        
                        Text(details)
                            .font(.system(size: 15))
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 6) {
                    Text("\(trip.timeStr)")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    if trip.isFree {
                        TagView(icon: "dollarsign.circle.fill", text: String(localized: "free_trip"), color: .green)
                    }
                    if trip.isTransfer {
                        TagView(icon: "link", text: String(localized: "transfer"), color: themeManager.accentColor)
                    }
                    if !trip.note.isEmpty {
                        TagView(icon: "note.text", text: "", color: .orange)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(trip.paidPrice)")
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .foregroundColor(trip.paidPrice == 0 ? themeManager.accentColor : themeManager.primaryTextColor)
                if trip.paidPrice != trip.originalPrice {
                    Text("original_price_label $\(trip.originalPrice)")
                        .font(.caption2)
                        .strikethrough()
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct TagView: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .foregroundColor(color)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

// MARK: - ViewModifiers

struct TripListSheetsModifier: ViewModifier {
    @Binding var showAddTripSheet: Bool
    @Binding var showFavoritesSheet: Bool
    @Binding var selectedTripToEdit: Trip?
    let showToast: (LocalizedStringKey) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showAddTripSheet) {
                AddTripView(onSuccess: {
                    showToast("trip_added")
                })
            }
            .sheet(isPresented: $showFavoritesSheet) {
                FavoritesManagementView(onQuickAdd: { routeName in
                    showToast("favorites_added \(routeName)")
                }, onQuickAddCommuter: { routeName in
                    showToast("favorites_added_commuter \(routeName)")
                })
            }
            .sheet(item: $selectedTripToEdit) { trip in
                EditTripView(trip: trip, onSuccess: {
                    showToast("trip_updated")
                })
                .presentationDetents([.height(650)])
                .presentationDragIndicator(.hidden)
            }
    }
}

struct TripListAlertsModifier: ViewModifier {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var pendingDuplicateDate: String?
    @Binding var pendingDeleteDate: String?
    @Binding var showCommuterNamePrompt: Bool
    @Binding var commuterRouteName: String
    @Binding var pendingCommuterTrip: Trip?
    let showToast: (LocalizedStringKey) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("duplicate_day", isPresented: Binding(get: { pendingDuplicateDate != nil }, set: { if !$0 { pendingDuplicateDate = nil } })) {
                Button("cancel", role: .cancel) { pendingDuplicateDate = nil }
                Button("duplicate_day") {
                    if let date = pendingDuplicateDate {
                        viewModel.duplicateDayTrips(from: date)
                        showToast("copied_day \(date)")
                    }
                    pendingDuplicateDate = nil
                }
            } message: {
                if let date = pendingDuplicateDate {
                    Text("confirm_duplicate \(date)")
                }
            }
            .alert("delete_day", isPresented: Binding(get: { pendingDeleteDate != nil }, set: { if !$0 { pendingDeleteDate = nil } })) {
                Button("cancel", role: .cancel) { pendingDeleteDate = nil }
                Button("delete_day", role: .destructive) {
                    if let date = pendingDeleteDate {
                        viewModel.deleteDayTrips(on: date)
                        showToast("deleted_day \(date)")
                    }
                    pendingDeleteDate = nil
                }
            } message: {
                if let date = pendingDeleteDate {
                    Text("confirm_delete_day \(date)")
                }
            }
            .alert("choose_commuter", isPresented: $showCommuterNamePrompt) {
                TextField("commuter_name_placeholder", text: $commuterRouteName)
                Button("cancel", role: .cancel) {
                    pendingCommuterTrip = nil
                    commuterRouteName = ""
                }
                Button("add_commuter") {
                    let trimmed = commuterRouteName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let trip = pendingCommuterTrip, !trimmed.isEmpty {
                        viewModel.addToCommuterRoute(from: trip, name: trimmed)
                        showToast("commuter_added \(trimmed)")
                    }
                    pendingCommuterTrip = nil
                    commuterRouteName = ""
                }
            } message: {
                Text("commuter_name_prompt")
            }
    }
}

