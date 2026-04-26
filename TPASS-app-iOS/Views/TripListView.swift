import SwiftUI
import SwiftData

// 轉乘選擇資料結構
struct TransferSelectionData: Identifiable {
    let id = UUID()
    let trip: Trip
    let region: TPASSRegion
}

struct TripListView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    
    @SceneStorage("mainTab.selectedTab") private var selectedTab: Int = 0
    
    private let horizontalPagePadding: CGFloat = 20
    
    @State private var showAddTripSheet = false
    @State private var showFavoritesSheet = false
    @State private var showQuickAddHomeSheet = false
    @State private var showQuickAddOutboundSheet = false
    @State private var selectedTripToEdit: Trip?
    @State private var isProcessingSwipeAction = false
    @State private var pendingDuplicateTrip: Trip? = nil
    @State private var pendingDuplicateTripUseHaptic = false
    @State private var pendingDuplicateDaySourceDate: String? = nil
    @State private var pendingDuplicateDaySourceCycleId: String? = nil
    @State private var pendingDuplicateDayTargetDate = Date()
    @State private var showDuplicateDayPicker = false
    @State private var pendingDeleteDate: String? = nil
    @State private var pendingDeleteCycleId: String? = nil
    @State private var pendingCommuterTrip: Trip? = nil
    @State private var commuterRouteName: String = ""
    @State private var showCommuterNamePrompt = false
    @State private var showCommuterRoutePicker = false
    @State private var transferSelectionData: TransferSelectionData?
    @State private var swipedRowId: String? = nil
    @State private var showNoCycleAlert = false
    @State private var isToastShowing = false
    @State private var toastMessage: LocalizedStringKey = ""
    @State private var showVoiceQuickTripSheet = false
    
    // MARK: - 教學狀態
    @AppStorage("hasShownTutorial_v1") private var hasShownTutorial = false
    @AppStorage("tutorialStep_v1") private var savedTutorialStep: Int = 0
    @AppStorage("hasShownFirstTimeHint") private var hasShownFirstTimeHint = false
    @State private var currentTutorialStep: SpotlightTutorialStep = .welcome
    @State private var showTutorial = false
    @State private var tutorialPositions = TutorialPositions()
    
    var cardBackground: Color {
        themeManager.cardBackgroundColor
    }

    private var selectedCycleDateRange: ClosedRange<Date>? {
        guard let cycle = viewModel.activeCycle else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.start)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: cycle.end) ?? cycle.end
        return start...end
    }

    private var isSelectedCyclePast: Bool {
        guard let cycle = viewModel.activeCycle else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        return cycle.end < today
    }

    private var isSelectedCycleCurrent: Bool {
        guard let cycle = viewModel.activeCycle else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return cycle.start <= today && cycle.end >= today
    }

    private var demoTrip: Trip {
        Trip(
            userId: auth.currentUser?.id ?? "demo-user",
            createdAt: Date(),
            type: .mrt,
            originalPrice: 20,
            paidPrice: 20,
            isTransfer: false,
            isFree: false,
            startStation: "科技大樓",
            endStation: "台北車站",
            routeId: "",
            note: ""
        )
    }

    private var shouldShowDemoTripRow: Bool {
        showTutorial && (currentTutorialStep == .swipeActions || currentTutorialStep == .longPressCommuter)
    }

    private var demoTripRow: some View {
        TripRowView(trip: demoTrip)
            .opacity(0.98)
            .allowsHitTesting(false)
            .reportFrame(id: "tripRow", in: .global)
            .onPreferenceChange(ViewFrameKey.self) { frames in
                if let rowFrame = frames["tripRow"] {
                    tutorialPositions.tripRowFrame = rowFrame
                }
            }
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
                        
                        Button(action: {
                            if auth.currentUser?.cycles.isEmpty ?? true {
                                showNoCycleAlert = true
                            } else {
                                showQuickAddHomeSheet = true
                            }
                        }) {
                            Image(systemName: "house.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(themeManager.accentColor)
                                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .reportFrame(id: "quickHomeButton", in: .global)
                        .onPreferenceChange(ViewFrameKey.self) { frames in
                            if let frame = frames["quickHomeButton"] {
                                tutorialPositions.quickHomeButtonFrame = frame
                            }
                        }
                        
                        Button(action: {
                            if auth.currentUser?.cycles.isEmpty ?? true {
                                showNoCycleAlert = true
                            } else {
                                showQuickAddOutboundSheet = true
                            }
                        }) {
                            Image(systemName: "figure.walk.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(themeManager.accentColor)
                                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .reportFrame(id: "quickDepartureButton", in: .global)
                        .onPreferenceChange(ViewFrameKey.self) { frames in
                            if let frame = frames["quickDepartureButton"] {
                                tutorialPositions.quickDepartureButtonFrame = frame
                            }
                        }
                        
                        Button(action: { showFavoritesSheet = true }) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(themeManager.accentColor)
                                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .reportFrame(id: "favoritesButton", in: .global)
                        .onPreferenceChange(ViewFrameKey.self) { frames in
                            if let frame = frames["favoritesButton"] {
                                tutorialPositions.favoritesButtonFrame = frame
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPagePadding)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
                    CycleSelectorView()
                        .padding(.horizontal, horizontalPagePadding)
                        .padding(.bottom, 6)
                        .reportFrame(id: "cycleSelector", in: .global)
                        .onPreferenceChange(ViewFrameKey.self) { frames in
                            if let frame = frames["cycleSelector"] {
                                tutorialPositions.cycleSelectorFrame = frame
                            }
                        }
                    
                    if viewModel.groupedTrips.isEmpty && !shouldShowDemoTripRow {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 36))
                                .foregroundColor(themeManager.secondaryTextColor)
                            Text("noTripsRecorded")
                                .font(.headline)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            if shouldShowDemoTripRow {
                                Section {
                                    demoTripRow
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                        .buttonStyle(StaticButtonStyle())
                                } header: {
                                    let today = Date().formatted(date: .numeric, time: .omitted)
                                    DailyHeaderView(
                                        group: DailyTripGroup(date: today, trips: [demoTrip]),
                                        showDuplicateToToday: true,
                                        onDuplicateToToday: {},
                                        onDuplicateToDate: {},
                                        onDelete: {}
                                    )
                                    .textCase(nil)
                                    .padding(.vertical, 4)
                                    .background(themeManager.backgroundColor)
                                    .listRowInsets(EdgeInsets())
                                    .padding(.bottom, 4)
                                }
                            }
                            
                            if !showTutorial {
                                ForEach(viewModel.groupedTrips) { group in
                                    Section {
                                        ForEach(group.trips) { trip in
                                            tripRowWithCustomSwipe(trip)
                                                .listRowSeparator(.hidden)
                                                .listRowBackground(Color.clear)
                                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                        }
                                    } header: {
                                        DailyHeaderView(
                                            group: group,
                                            showDuplicateToToday: isSelectedCycleCurrent,
                                            onDuplicateToToday: { duplicateDayToToday(group) },
                                            onDuplicateToDate: { requestDuplicateDayToDate(group) },
                                            onDelete: { requestDeleteDay(group) }
                                        )
                                        .textCase(nil)
                                        .padding(.vertical, 4)
                                        .background(themeManager.backgroundColor)
                                        .listRowInsets(EdgeInsets())
                                        .padding(.bottom, 4)
                                    }
                                }
                            }
                            Color.clear.frame(height: 80).listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.groupedTrips)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
                
                // 浮動新增按鈕
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: {
                            if auth.currentUser?.cycles.isEmpty ?? true {
                                showNoCycleAlert = true
                            } else {
                                showVoiceQuickTripSheet = true
                            }
                        }) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(Color(hex: "#2c3e50"))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        Button(action: {
                            if auth.currentUser?.cycles.isEmpty ?? true {
                                showNoCycleAlert = true
                            } else {
                                showAddTripSheet = true
                            }
                        }) {
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
                        .reportFrame(id: "addButton", in: .global)
                        .onPreferenceChange(ViewFrameKey.self) { frames in
                            if let frame = frames["addButton"] {
                                tutorialPositions.addButtonFrame = frame
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                // Toast 與其他 Overlay...
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

                if showTutorial {
                    SpotlightTutorialOverlay(
                        currentStep: $currentTutorialStep,
                        onFinish: {
                            withAnimation {
                                showTutorial = false
                                hasShownTutorial = true
                                savedTutorialStep = 0
                            }
                        },
                        positions: tutorialPositions
                    )
                    .environmentObject(themeManager)
                    .zIndex(999)
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .modifier(TripListSheetsModifier(
                showAddTripSheet: $showAddTripSheet,
                showFavoritesSheet: $showFavoritesSheet,
                showQuickAddHomeSheet: $showQuickAddHomeSheet,
                showQuickAddOutboundSheet: $showQuickAddOutboundSheet,
                selectedTripToEdit: $selectedTripToEdit,
                transferSelectionData: $transferSelectionData,
                isProcessingSwipeAction: $isProcessingSwipeAction,
                showToast: showToast
            ))
            .sheet(isPresented: $showVoiceQuickTripSheet) {
                VoiceQuickTripView(onSuccess: {
                    showToast(message: "voice_trip_saved")
                }, onSwitchToManual: {
                    showAddTripSheet = true
                })
            }
            .sheet(isPresented: $showDuplicateDayPicker) {
                let range = selectedCycleDateRange ?? (Date()...Date())
                VStack(spacing: 16) {
                    Text("duplicate_day_select_title")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryTextColor)

                    Text("duplicate_day_select_message")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryTextColor)

                    DatePicker(
                        "",
                        selection: $pendingDuplicateDayTargetDate,
                        in: range,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.graphical)

                    HStack(spacing: 12) {
                        Button("cancel", role: .cancel) {
                            pendingDuplicateDaySourceDate = nil
                            pendingDuplicateDaySourceCycleId = nil
                            showDuplicateDayPicker = false
                        }

                        Spacer()

                        Button("confirm_duplicate_day") {
                            if let source = pendingDuplicateDaySourceDate {
                                let calendar = Calendar.current
                                let targetDay = calendar.startOfDay(for: pendingDuplicateDayTargetDate)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.duplicateDayTrips(
                                        from: source,
                                        cycleId: pendingDuplicateDaySourceCycleId,
                                        targetDay: targetDay,
                                        targetCycleId: pendingDuplicateDaySourceCycleId
                                    )
                                }
                                let formatted = DateFormatter.localizedString(
                                    from: targetDay,
                                    dateStyle: .medium,
                                    timeStyle: .none
                                )
                                showToast(message: "copied_day_to \(formatted)")
                            }
                            pendingDuplicateDaySourceDate = nil
                            pendingDuplicateDaySourceCycleId = nil
                            showDuplicateDayPicker = false
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
            }
            .modifier(TripListAlertsModifier(
                pendingDeleteDate: $pendingDeleteDate,
                pendingDeleteCycleId: $pendingDeleteCycleId,
                showCommuterNamePrompt: $showCommuterNamePrompt,
                commuterRouteName: $commuterRouteName,
                pendingCommuterTrip: $pendingCommuterTrip,
                showNoCycleAlert: $showNoCycleAlert,
                selectedTab: $selectedTab,
                showToast: showToast
            ))
        }
        .onAppear {
            if let user = auth.currentUser {
                let sortedCycles = user.cycles.sorted { $0.start > $1.start }
                let isSelectedCycleValid = viewModel.selectedCycle != nil &&
                    user.cycles.contains(where: { $0.id == viewModel.selectedCycle?.id })
                if !isSelectedCycleValid {
                    let newCycle = sortedCycles.first
                    if viewModel.selectedCycle?.id != newCycle?.id {
                        viewModel.selectedCycle = newCycle
                    }
                }
            }

            if !hasShownTutorial {
                if let step = SpotlightTutorialStep(rawValue: savedTutorialStep) {
                    currentTutorialStep = step
                } else {
                    currentTutorialStep = .welcome
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showTutorial = true
                    }
                }
            }
        }
        .onChange(of: currentTutorialStep) { _, step in
            savedTutorialStep = step.rawValue
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

    private func performDuplicateTrip(_ trip: Trip, useHaptic: Bool) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewModel.duplicateTrip(trip)
        }
        if useHaptic {
            HapticManager.shared.impact(style: .medium)
        }
        showToast(message: "trip_duplicated")
    }

    private func duplicateDayToToday(_ group: DailyTripGroup) {
        let cycleId = group.trips.first?.cycleId ?? viewModel.activeCycle?.id
        viewModel.duplicateDayTrips(from: group.date, cycleId: cycleId)
        showToast(message: "copied_day \(group.date)")
    }

    private func requestDeleteDay(_ group: DailyTripGroup) {
        pendingDeleteDate = group.date
        pendingDeleteCycleId = group.trips.first?.cycleId ?? viewModel.activeCycle?.id
    }

    private func requestDuplicateTrip(_ trip: Trip, useDelay: Bool) {
        if useDelay {
            guard !isProcessingSwipeAction else { return }
            isProcessingSwipeAction = true
        }

        if isSelectedCyclePast {
            pendingDuplicateTrip = trip
            pendingDuplicateTripUseHaptic = useDelay
            if useDelay {
                isProcessingSwipeAction = false
            }
            return
        }

        if useDelay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                performDuplicateTrip(trip, useHaptic: true)
                isProcessingSwipeAction = false
            }
        } else {
            performDuplicateTrip(trip, useHaptic: false)
        }
    }

    private func requestDuplicateDayToDate(_ group: DailyTripGroup) {
        guard let range = selectedCycleDateRange else { return }
        pendingDuplicateDaySourceDate = group.date
        pendingDuplicateDaySourceCycleId = group.trips.first?.cycleId ?? viewModel.activeCycle?.id
        let calendar = Calendar.current
        let preferredDate = group.trips.first?.createdAt ?? range.lowerBound
        let normalized = calendar.startOfDay(for: preferredDate)
        pendingDuplicateDayTargetDate = range.contains(normalized) ? normalized : range.upperBound
        showDuplicateDayPicker = true
    }
    
    @ViewBuilder
    private func tripRowWithCustomSwipe(_ trip: Trip) -> some View {
        SwipeableRowView(
            rowId: trip.id,
            swipedRowId: $swipedRowId,
            leadingWidth: 246,
            trailingWidth: 88,
            leading: { close in
                HStack(spacing: 0) {
                    customSwipeActionButton(
                        title: trip.isTransfer ? "cancel_transfer" : "add_transfer",
                        systemImage: trip.isTransfer ? "link.badge.plus" : "link",
                        backgroundColor: themeManager.accentColor,
                        action: {
                            handleTransferAction(for: trip)
                            close()
                        }
                    )
                    customSwipeActionButton(
                        title: "duplicate_trip",
                        systemImage: "doc.on.doc.fill",
                        backgroundColor: Color.blue,
                        action: {
                            requestDuplicateTrip(trip, useDelay: false)
                            close()
                        }
                    )
                    customSwipeActionButton(
                        title: "return_trip",
                        systemImage: "arrow.uturn.backward",
                        backgroundColor: Color.indigo,
                        action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.createReturnTrip(trip)
                            }
                            HapticManager.shared.impact(style: .medium)
                            showToast(message: "trip_added")
                            close()
                        }
                    )
                }
            },
            trailing: { close in
                HStack(spacing: 0) {
                    customSwipeActionButton(
                        title: "delete",
                        systemImage: "trash.fill",
                        backgroundColor: Color.red,
                        action: {
                            HapticManager.shared.notification(type: .warning)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.deleteTrip(trip)
                            }
                            showToast(message: "trip_deleted")
                            close()
                        }
                    )
                }
            },
            content: {
                TripRowView(trip: trip)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTripToEdit = trip
                    }
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    if tutorialPositions.tripRowFrame == .zero {
                                        tutorialPositions.tripRowFrame = geo.frame(in: .global)
                                    }
                                }
                        }
                    )
                    .contextMenu {
                        tripContextMenuContent(trip: trip)
                    }
            }
        )
        .disabled(isProcessingSwipeAction)
    }

    private func handleTransferAction(for trip: Trip) {
        if trip.isTransfer {
            viewModel.setTransferType(trip, transferType: nil)
            HapticManager.shared.impact(style: .medium)
            showToast(message: "transfer_cancelled")
            return
        }

        let region = viewModel.cycleById(trip.cycleId)?.region ??
                    viewModel.cycleForTrip(date: trip.createdAt)?.region ??
                    AuthService.shared.currentRegion
        let availableTypes = region.availableTransferTypes

        if availableTypes.count > 1 {
            transferSelectionData = TransferSelectionData(trip: trip, region: region)
        } else if availableTypes.count == 1 {
            viewModel.setTransferType(trip, transferType: availableTypes[0])
            HapticManager.shared.impact(style: .medium)
            showToast(message: "transfer_added")
        }
    }

    private func customSwipeActionButton(
        title: LocalizedStringKey,
        systemImage: String,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
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
            if trip.isTransfer {
                viewModel.setTransferType(trip, transferType: nil)
                HapticManager.shared.impact(style: .medium)
                showToast(message: "transfer_cancelled")
            } else {
                let region = viewModel.cycleById(trip.cycleId)?.region ??
                            viewModel.cycleForTrip(date: trip.createdAt)?.region ??
                            AuthService.shared.currentRegion
                let availableTypes = region.availableTransferTypes
                DispatchQueue.main.async {
                    if availableTypes.count > 1 {
                        transferSelectionData = TransferSelectionData(trip: trip, region: region)
                    } else if availableTypes.count == 1 {
                        viewModel.setTransferType(trip, transferType: availableTypes[0])
                        HapticManager.shared.impact(style: .medium)
                        showToast(message: "transfer_added")
                    }
                }
            }
        } label: {
            Label(trip.isTransfer ? "cancel_transfer" : "add_transfer", systemImage: trip.isTransfer ? "xmark.circle" : "link")
        }
        
        Button {
            requestDuplicateTrip(trip, useDelay: false)
        } label: {
            Label("duplicate_trip", systemImage: "doc.on.doc.fill")
        }
        
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.createReturnTrip(trip)
            }
            showToast(message: "trip_added")
        } label: {
            Label("return_trip", systemImage: "arrow.uturn.backward")
        }
        
        Divider()
        
        Button(role: .destructive) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.deleteTrip(trip)
            }
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
    @Query(sort: \TransitCard.createdAt, order: .reverse) private var cards: [TransitCard]
    @State private var showCyclePickerSheet = false
    
    var cardBackground: Color {
        switch themeManager.currentTheme {
        case .muji, .light, .purple: return Color.white
        case .dark: return Color(uiColor: .secondarySystemGroupedBackground)
        case .system: return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
        }
    }

    private var sortedCycles: [Cycle] {
        (auth.currentUser?.cycles ?? []).sorted { $0.start > $1.start }
    }

    private func cardName(for cardId: String?) -> String? {
        guard let cardId else { return nil }
        return cards.first(where: { $0.id.uuidString == cardId })?.name
    }

    private var cycleAccessibilityValue: Text {
        if let region = viewModel.activeCycle?.region ?? sortedCycles.first?.region {
            return Text(viewModel.cycleDateRange) + Text(", ") + Text(region.displayNameKey)
        }
        return Text(viewModel.cycleDateRange)
    }
    
    var body: some View {
        Button {
            showCyclePickerSheet = true
        } label: {
            VStack(spacing: 8) {
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
                if let cycle = viewModel.activeCycle ?? sortedCycles.first {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor)
                        Text(cycle.region.displayNameKey)
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        if let cardName = cardName(for: cycle.cardId) {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                            Text(cardName)
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        }
        .sheet(isPresented: $showCyclePickerSheet) {
            CyclePickerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }
}

// CyclePickerSheet 保持不變
struct CyclePickerSheet: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Query(sort: \TransitCard.createdAt, order: .reverse) private var cards: [TransitCard]

    private var sortedCycles: [Cycle] {
        (auth.currentUser?.cycles ?? []).sorted { $0.start > $1.start }
    }

    private var cardBackground: Color {
        switch themeManager.currentTheme {
        case .muji, .light, .purple: return Color.white
        case .dark: return Color(uiColor: .secondarySystemGroupedBackground)
        case .system: return colorScheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : Color.white
        }
    }

    private func cardName(for cardId: String?) -> String? {
        guard let cardId else { return nil }
        return cards.first(where: { $0.id.uuidString == cardId })?.name
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().frame(width: 40, height: 5).foregroundColor(.secondary.opacity(0.3)).padding(.top, 10)
            Text("cycle_picker_title").font(.title3.bold()).foregroundColor(themeManager.primaryTextColor).padding(.vertical, 12)

            if sortedCycles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus").font(.system(size: 40)).foregroundColor(themeManager.secondaryTextColor.opacity(0.5))
                    Text("no_cycles_yet").font(.headline).foregroundColor(themeManager.secondaryTextColor)
                }
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sortedCycles) { cycle in cycleRow(cycle) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
            }
        }
        .background(themeManager.backgroundColor)
    }

    @ViewBuilder
    private func cycleRow(_ cycle: Cycle) -> some View {
        let isSelected = viewModel.selectedCycle?.id == cycle.id
        let now = Date()
        let isCurrent = cycle.start <= now && cycle.end >= now

        Button {
            HapticManager.shared.impact(style: .medium)
            viewModel.selectedCycle = cycle
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack {
                    Image(systemName: "mappin.circle.fill").font(.title2).foregroundColor(isSelected ? .white : themeManager.accentColor)
                }
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? themeManager.accentColor : themeManager.accentColor.opacity(0.12)))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(cycle.region.displayNameKey).font(.subheadline).fontWeight(.bold).foregroundColor(themeManager.primaryTextColor)
                        if let cardName = cardName(for: cycle.cardId) {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor.opacity(0.8))
                            Text(cardName)
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryTextColor)
                                .lineLimit(1)
                        }
                        if isCurrent {
                            Text("active").font(.caption2).fontWeight(.semibold).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(themeManager.accentColor).cornerRadius(4)
                        }
                    }
                    Text(cycleDateRangeText(cycle)).font(.caption).foregroundColor(themeManager.secondaryTextColor)
                    if cycle.region.monthlyPrice > 0 {
                        Text("$\(cycle.region.monthlyPrice)").font(.caption).fontWeight(.medium).foregroundColor(themeManager.accentColor)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(themeManager.accentColor)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? themeManager.accentColor.opacity(0.08) : cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? themeManager.accentColor.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1))
        }
    }

    private func cycleDateRangeText(_ cycle: Cycle) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"
        return "\(f.string(from: cycle.start)) ~ \(f.string(from: cycle.end))"
    }
}

// 💡 標題重構：去除底色與外框，變成浮在背景上的純文字
struct DailyHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    let group: DailyTripGroup
    let showDuplicateToToday: Bool
    let onDuplicateToToday: () -> Void
    let onDuplicateToDate: () -> Void
    let onDelete: () -> Void
    @State private var showActions = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(group.date)
                .font(.subheadline) // 與 DAAK 一樣稍微縮小字體
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryTextColor)
            Spacer()
            Text("$\(group.dailyTotal)")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(themeManager.secondaryTextColor)
            
            Button {
                showActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(StaticButtonStyle())
            .confirmationDialog("day_actions_title", isPresented: $showActions, titleVisibility: .visible) {
                if showDuplicateToToday {
                    Button("duplicate_day_to_today") {
                        HapticManager.shared.impact(style: .medium)
                        onDuplicateToToday()
                    }
                }
                Button("duplicate_day_to_date") {
                    HapticManager.shared.impact(style: .medium)
                    onDuplicateToDate()
                }
                Button("delete_day", role: .destructive) {
                    HapticManager.shared.notification(type: .warning)
                    onDelete()
                }
                Button("cancel", role: .cancel) { }
            } message: {
                Text("day_actions \(group.date)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            showActions = true
        }
    }
}

struct TripRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let trip: Trip
    
    private func displayStationName(_ stationName: String, type: TransportType) -> String {
        let lang = Locale.current.identifier
        if type == .tymrt { return TYMRTStationData.shared.displayStationName(stationName, languageCode: lang) }
        else if type == .hsr { return HSRStationData.shared.displayStationName(stationName, languageCode: lang) }
        else if type == .tra { return TRAStationData.shared.displayStationName(stationName, languageCode: lang) }
        else if type == .tcmrt { return TCMRTStationData.shared.displayStationName(stationName, languageCode: lang) }
        else if type == .kmrt { return KMRTStationData.shared.displayStationName(stationName, languageCode: lang) }
        else if type == .lrt { return LRTStationData.shared.displayStationName(stationName, languageCode: lang) }
        else { return StationData.shared.displayStationName(stationName, languageCode: lang) }
    }
    
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
                        (trip.startStation.isEmpty || trip.endStation.isEmpty) ? nil : "\(displayStationName(trip.startStation, type: trip.type)) → \(displayStationName(trip.endStation, type: trip.type))"
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
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(themeManager.cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.04), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
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

struct SwipeableRowView<Content: View, Leading: View, Trailing: View>: View {
    let rowId: String
    @Binding var swipedRowId: String?
    private let leadingWidth: CGFloat
    private let trailingWidth: CGFloat
    private let cornerRadius: CGFloat
    private let gap: CGFloat = 12
    private let leading: (_ close: @escaping () -> Void) -> Leading
    private let trailing: (_ close: @escaping () -> Void) -> Trailing
    private let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0

    init(
        rowId: String,
        swipedRowId: Binding<String?>,
        leadingWidth: CGFloat,
        trailingWidth: CGFloat,
        cornerRadius: CGFloat = 16,
        @ViewBuilder leading: @escaping (_ close: @escaping () -> Void) -> Leading,
        @ViewBuilder trailing: @escaping (_ close: @escaping () -> Void) -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.rowId = rowId
        self._swipedRowId = swipedRowId
        self.leadingWidth = leadingWidth
        self.trailingWidth = trailingWidth
        self.cornerRadius = cornerRadius
        self.leading = leading
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        ZStack {
            // 背景層：固定在左右兩側的圓角膠囊按鈕
            HStack(spacing: 0) {
                if offset > 0 {
                    leading(closeRow)
                        .frame(width: leadingWidth)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    Spacer(minLength: 0)
                } else if offset < 0 {
                    Spacer(minLength: 0)
                    trailing(closeRow)
                        .frame(width: trailingWidth)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }

            // 前景層：滑動卡片
            content()
                .offset(x: offset)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.92), value: offset)
        .onChange(of: swipedRowId) { _, newValue in
            if newValue != rowId && offset != 0 {
                closeRow()
            }
        }
    }

    private func closeRow() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
            offset = 0
            lastOffset = 0
            if swipedRowId == rowId {
                swipedRowId = nil
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation.width
                let verticalTranslation = value.translation.height

                if offset != 0 && abs(verticalTranslation) > 6 && abs(verticalTranslation) > abs(translation) * 0.6 {
                    closeRow()
                    return
                }

                if abs(verticalTranslation) > 8 && abs(verticalTranslation) > abs(translation) * 0.9 {
                    if offset != 0 || swipedRowId == rowId {
                        closeRow()
                    }
                    return
                }

                guard abs(translation) > abs(verticalTranslation) * 1.2 else {
                    return
                }

                if swipedRowId != rowId {
                    swipedRowId = rowId
                }

                var newOffset = lastOffset + translation
                // 狀態鎖定：展開時不允許拖曳越過中心線
                if lastOffset > 0 { newOffset = max(0, newOffset) }
                else if lastOffset < 0 { newOffset = min(0, newOffset) }

                let maxLeading = leadingWidth + gap
                let maxTrailing = trailingWidth + gap

                // 阻尼效果
                if newOffset > maxLeading {
                    newOffset = maxLeading + (newOffset - maxLeading) * 0.1
                } else if newOffset < -maxTrailing {
                    newOffset = -maxTrailing + (newOffset + maxTrailing) * 0.1
                }

                offset = newOffset
            }
            .onEnded { value in
                let translation = value.translation.width
                let verticalTranslation = value.translation.height

                if offset != 0 && abs(verticalTranslation) > 6 && abs(verticalTranslation) > abs(translation) * 0.6 {
                    closeRow()
                    return
                }

                if abs(verticalTranslation) > 8 && abs(verticalTranslation) > abs(translation) * 0.9 {
                    closeRow()
                    return
                }

                guard abs(translation) > abs(verticalTranslation) * 1.2 else { return }

                let velocity = value.predictedEndTranslation.width - translation
                let projected = translation + velocity * 0.1
                let threshold: CGFloat = 46

                let maxLeading = leadingWidth + gap
                let maxTrailing = trailingWidth + gap
                var targetOffset: CGFloat = 0

                // 狀態機判斷目標位置
                if lastOffset == 0 {
                    if projected > threshold {
                        targetOffset = maxLeading
                    } else if projected < -threshold {
                        targetOffset = -maxTrailing
                    }
                } else if lastOffset > 0 {
                    if projected < -threshold {
                        targetOffset = 0
                    } else {
                        targetOffset = maxLeading
                    }
                } else {
                    if projected > threshold {
                        targetOffset = 0
                    } else {
                        targetOffset = -maxTrailing
                    }
                }

                withAnimation(.spring(response: 0.55, dampingFraction: 0.9)) {
                    offset = targetOffset
                    lastOffset = targetOffset
                    swipedRowId = targetOffset == 0 ? nil : rowId
                }
            }
    }
}

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle())
    }
}

// ViewModifiers 保持不變
struct TripListSheetsModifier: ViewModifier {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showAddTripSheet: Bool
    @Binding var showFavoritesSheet: Bool
    @Binding var showQuickAddHomeSheet: Bool
    @Binding var showQuickAddOutboundSheet: Bool
    @Binding var selectedTripToEdit: Trip?
    @Binding var transferSelectionData: TransferSelectionData?
    @Binding var isProcessingSwipeAction: Bool
    let showToast: (LocalizedStringKey) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showAddTripSheet) { AddTripView(onSuccess: { showToast("trip_added") }) }
            .sheet(isPresented: $showFavoritesSheet) { FavoritesManagementView(onQuickAdd: { r in showToast("favorites_added \(r)") }, onQuickAddCommuter: { r in showToast("favorites_added_commuter \(r)") }) }
            .sheet(isPresented: $showQuickAddHomeSheet) { QuickAddHomeView(onSuccess: { showToast("trip_added") }) }
            .sheet(isPresented: $showQuickAddOutboundSheet) { QuickAddOutboundView(onSuccess: { showToast("trip_added") }) }
            .sheet(item: $selectedTripToEdit) { trip in
                EditTripView(trip: trip, onSuccess: { showToast("trip_updated") })
                .presentationDetents([.height(650)])
                .presentationDragIndicator(.hidden)
            }
            .sheet(item: $transferSelectionData) { data in
                TransferTypeSelectionView(
                    trip: data.trip, region: data.region, viewModel: viewModel,
                    isPresented: Binding(get: { transferSelectionData != nil }, set: { if !$0 { transferSelectionData = nil } }),
                    onSelected: { selectedType in
                        if selectedType != nil { showToast("transfer_added") } else { showToast("transfer_cancelled") }
                        isProcessingSwipeAction = false
                    }
                )
                .environmentObject(auth)
                .environmentObject(themeManager)
                .presentationDetents([.height(420), .medium])
                .presentationDragIndicator(.visible)
            }
    }
}

struct TripListAlertsModifier: ViewModifier {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService
    @Binding var pendingDeleteDate: String?
    @Binding var pendingDeleteCycleId: String?
    @Binding var showCommuterNamePrompt: Bool
    @Binding var commuterRouteName: String
    @Binding var pendingCommuterTrip: Trip?
    @Binding var showNoCycleAlert: Bool
    @Binding var selectedTab: Int
    let showToast: (LocalizedStringKey) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("delete_day", isPresented: Binding(get: { pendingDeleteDate != nil }, set: { if !$0 { pendingDeleteDate = nil } })) {
                Button("cancel", role: .cancel) { pendingDeleteDate = nil }
                Button("delete_day", role: .destructive) {
                    if let date = pendingDeleteDate {
                        let cycleId = pendingDeleteCycleId ?? viewModel.activeCycle?.id
                        viewModel.deleteDayTrips(on: date, cycleId: cycleId)
                        showToast("deleted_day \(date)")
                    }
                    pendingDeleteDate = nil; pendingDeleteCycleId = nil
                }
            } message: {
                if let date = pendingDeleteDate {
                    if let cycle = viewModel.cycleById(pendingDeleteCycleId ?? viewModel.activeCycle?.id) {
                        Text("confirm_delete_day_cycle_prefix \(date)") + Text(cycle.region.displayNameKey) + Text("confirm_delete_day_cycle_suffix")
                    } else {
                        Text("confirm_delete_day \(date)")
                    }
                }
            }
            .alert("choose_commuter", isPresented: $showCommuterNamePrompt) {
                TextField("commuter_name_placeholder", text: $commuterRouteName)
                Button("cancel", role: .cancel) { pendingCommuterTrip = nil; commuterRouteName = "" }
                Button("add_commuter") {
                    let trimmed = commuterRouteName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let trip = pendingCommuterTrip, !trimmed.isEmpty {
                        viewModel.addToCommuterRoute(from: trip, name: trimmed)
                        showToast("commuter_added \(trimmed)")
                    }
                    pendingCommuterTrip = nil; commuterRouteName = ""
                }
            } message: { Text("commuter_name_prompt") }
            .alert("no_cycles_yet", isPresented: $showNoCycleAlert) {
                Button("cancel", role: .cancel) { }
                Button("add_new_cycle") { selectedTab = 2 }
            } message: { Text("no_cycles_description") }
    }
}

struct FavoritesButtonFrameKey: PreferenceKey { static var defaultValue: CGRect = .zero; static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() } }
struct CycleSelectorFrameKey: PreferenceKey { static var defaultValue: CGRect = .zero; static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() } }
struct AddButtonFrameKey: PreferenceKey { static var defaultValue: CGRect = .zero; static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() } }
struct TripRowFrameKey: PreferenceKey { static var defaultValue: CGRect = .zero; static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() } }
