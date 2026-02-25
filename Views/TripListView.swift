import SwiftUI

//     轉乘選擇資料結構
struct TransferSelectionData: Identifiable {
    let id = UUID()
    let trip: Trip
    let region: TPASSRegion
}

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
    @State private var pendingDuplicateTrip: Trip? = nil
    @State private var pendingDuplicateTripUseHaptic = false
    @State private var pendingDuplicateDaySourceDate: String? = nil
    @State private var pendingDuplicateDayTargetDate = Date()
    @State private var showDuplicateDayPicker = false
    @State private var pendingDeleteDate: String? = nil
    @State private var pendingCommuterTrip: Trip? = nil
    @State private var commuterRouteName: String = ""
    @State private var showCommuterNamePrompt = false
    @State private var showCommuterRoutePicker = false
    
    //     新增：轉乘類型選擇
    @State private var transferSelectionData: TransferSelectionData?
    
    @State private var isToastShowing = false
    @State private var toastMessage: LocalizedStringKey = ""
    
    // MARK: - 教學狀態
    // 使用 AppStorage 自動記住使用者是否看過教學
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
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(themeManager.cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(themeManager.secondaryTextColor.opacity(0.15), lineWidth: 1)
            )
            .opacity(0.98)
            .allowsHitTesting(false)
            //     關鍵：回報演示行程的準確座標給教學系統
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
                        
                        Button(action: { showFavoritesSheet = true }) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(themeManager.accentColor)
                                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .accessibilityLabel(Text("a11y_favorites"))
                        .accessibilityHint(Text("a11y_favorites_hint"))
                        //     關鍵：回報星星按鈕的準確座標給教學系統
                        .reportFrame(id: "favoritesButton", in: .global)
                        .onPreferenceChange(ViewFrameKey.self) { frames in
                            if let favFrame = frames["favoritesButton"] {
                                tutorialPositions.favoritesButtonFrame = favFrame
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPagePadding).padding(.top, 10).padding(.bottom, 10)
                    
                    // CycleSelectorView
                    CycleSelectorView()
                        .padding(.horizontal, horizontalPagePadding)
                        .padding(.bottom, 10)
                        //     關鍵：回報週期選擇器的準確座標給教學系統
                        .reportFrame(id: "cycleSelector", in: .global)
                        .onPreferenceChange(ViewFrameKey.self) { frames in
                            if let selectorFrame = frames["cycleSelector"] {
                                tutorialPositions.cycleSelectorFrame = selectorFrame
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
                            
                            // 新使用者提示：只在首次且當前週期是彈性週期時顯示
                            if let cycle = viewModel.activeCycle, cycle.region == .flexible, !hasShownFirstTimeHint {
                                VStack(spacing: 12) {
                                    Text("first_time_hint_title")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    
                                    Text("first_time_hint_message")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                }
                                .padding(20)
                                .background(themeManager.cardBackgroundColor)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1.5)
                                )
                                .padding(.horizontal, 40)
                                .padding(.top, 8)
                                .onTapGesture {
                                    // 點擊後標記為已顯示
                                    hasShownFirstTimeHint = true
                                }
                                .onAppear {
                                    print("🎉 [DEBUG] First time hint displayed!")
                                    print("   - Cycle: \(cycle.title)")
                                    print("   - Region: \(cycle.region)")
                                    print("   - hasShownFirstTimeHint: \(hasShownFirstTimeHint)")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .multilineTextAlignment(.center)
                        .onAppear {
                            print("📋 [DEBUG] Empty trips view displayed")
                            print("   - activeCycle: \(viewModel.activeCycle?.title ?? "nil")")
                            print("   - activeCycle region: \(viewModel.activeCycle?.region.rawValue ?? "nil")")
                            print("   - hasShownFirstTimeHint: \(hasShownFirstTimeHint)")
                            print("   - shouldShowDemoTripRow: \(shouldShowDemoTripRow)")
                        }
                    } else {
                        List {
                            // 教學模式：只顯示演示行程
                            if shouldShowDemoTripRow {
                                Section {
                                    demoTripRow
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .padding(.vertical, 4)
                                        .buttonStyle(StaticButtonStyle())
                                        .allowsHitTesting(false)
                                } header: {
                                    let today = Date().formatted(date: .numeric, time: .omitted)
                                    DailyHeaderView(
                                        group: DailyTripGroup(date: today, trips: [demoTrip]),
                                        showDuplicateToToday: true,
                                        onDuplicateToToday: {},
                                        onDuplicateToDate: {},
                                        onDelete: {}
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
                            
                            // 正常模式：顯示所有行程（教學模式時隱藏）
                            if !showTutorial {
                                ForEach(viewModel.groupedTrips) { group in
                                    Section {
                                        // 行程列表
                                        ForEach(group.trips) { trip in
                                            tripRowWithActions(trip)
                                        }
                                    } header: {
                                        //     關鍵修正：日期 Header 放在 Section header
                                        // 這樣 SwiftUI 就不會把它當成「第一個 swipe row」
                                        DailyHeaderView(
                                            group: group,
                                            showDuplicateToToday: isSelectedCycleCurrent,
                                            onDuplicateToToday: {
                                                duplicateDayToToday(group)
                                            },
                                            onDuplicateToDate: {
                                                requestDuplicateDayToDate(group)
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
                    //     關鍵：回報按鈕的準確座標給教學系統
                    .reportFrame(id: "addButton", in: .global)
                    .padding(.bottom, 20)
                    .onPreferenceChange(ViewFrameKey.self) { frames in
                        if let btnFrame = frames["addButton"] {
                            tutorialPositions.addButtonFrame = btnFrame
                        }
                    }
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
                
                // ===     新增：教學遮罩層 ===
                if showTutorial {
                    SpotlightTutorialOverlay(
                        currentStep: $currentTutorialStep,
                        onFinish: {
                            // 當教學結束時執行的動作
                            withAnimation {
                                showTutorial = false
                                hasShownTutorial = true
                                savedTutorialStep = 0
                            }
                        },
                        positions: tutorialPositions
                    )
                    .environmentObject(themeManager)
                    .zIndex(999) // 確保蓋在最上面
                    .transition(.opacity)
                }
                
            }
            // 關鍵修正：隱藏導航列，解決滑動跳動問題
            .toolbar(.hidden, for: .navigationBar)
            .modifier(TripListSheetsModifier(
                showAddTripSheet: $showAddTripSheet,
                showFavoritesSheet: $showFavoritesSheet,
                selectedTripToEdit: $selectedTripToEdit,
                transferSelectionData: $transferSelectionData,
                isProcessingSwipeAction: $isProcessingSwipeAction,
                showToast: showToast
            ))
            .modifier(TripListAlertsModifier(
                pendingDeleteDate: $pendingDeleteDate,
                showCommuterNamePrompt: $showCommuterNamePrompt,
                commuterRouteName: $commuterRouteName,
                pendingCommuterTrip: $pendingCommuterTrip,
                showToast: showToast
            ))
            .alert("duplicate_trip_past_title", isPresented: Binding(
                get: { pendingDuplicateTrip != nil },
                set: { if !$0 { pendingDuplicateTrip = nil } }
            )) {
                Button("cancel", role: .cancel) { pendingDuplicateTrip = nil }
                Button("continue_copy") {
                    if let trip = pendingDuplicateTrip {
                        performDuplicateTrip(trip, useHaptic: pendingDuplicateTripUseHaptic)
                    }
                    pendingDuplicateTrip = nil
                }
            } message: {
                Text("duplicate_trip_past_message")
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
                            showDuplicateDayPicker = false
                        }

                        Spacer()

                        Button("confirm_duplicate_day") {
                            if let source = pendingDuplicateDaySourceDate {
                                let calendar = Calendar.current
                                let targetDay = calendar.startOfDay(for: pendingDuplicateDayTargetDate)
                                viewModel.duplicateDayTrips(from: source, targetDay: targetDay)
                                let formatted = DateFormatter.localizedString(
                                    from: targetDay,
                                    dateStyle: .medium,
                                    timeStyle: .none
                                )
                                showToast(message: "copied_day_to \(formatted)")
                            }
                            pendingDuplicateDaySourceDate = nil
                            showDuplicateDayPicker = false
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
            }
            
        }
        .onAppear {
            if let user = auth.currentUser, viewModel.selectedCycle == nil {
                let sortedCycles = user.cycles.sorted { $0.start > $1.start }
                if let firstCycle = sortedCycles.first {
                    viewModel.selectedCycle = firstCycle
                }
            }
            
            // 檢查是否需要顯示教學
            if !hasShownTutorial {
                // 重置步驟到第一步
                if let step = SpotlightTutorialStep(rawValue: savedTutorialStep) {
                    currentTutorialStep = step
                } else {
                    currentTutorialStep = .welcome
                }
                
                // 延遲一點點顯示，讓 UI 先載入完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showTutorial = true
                    }
                }
            }
        }
        .onChange(of: auth.currentUser) { oldUser, user in
            if let user = user, viewModel.selectedCycle == nil {
                let sortedCycles = user.cycles.sorted { $0.start > $1.start }
                if let firstCycle = sortedCycles.first {
                    viewModel.selectedCycle = firstCycle
                }
            }
        }
        .onChange(of: currentTutorialStep) { oldStep, step in
            // 保存當前步驟
            savedTutorialStep = step.rawValue
        }
    }
    
    // MARK: - Helper Methods
    
    private func displayStationName(_ stationName: String, type: TransportType) -> String {
        let lang = Locale.current.identifier
        if type == .tymrt {
            return TYMRTStationData.shared.displayStationName(stationName, languageCode: lang)
        } else if type == .tcmrt {
            return TCMRTStationData.shared.displayStationName(stationName, languageCode: lang)
        } else if type == .kmrt {
            return KMRTStationData.shared.displayStationName(stationName, languageCode: lang)
        } else {
            return StationData.shared.displayStationName(stationName, languageCode: lang)
        }
    }
    
    func showToast(message: LocalizedStringKey) {
        toastMessage = message
        withAnimation { isToastShowing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { isToastShowing = false }
        }
    }

    private func performDuplicateTrip(_ trip: Trip, useHaptic: Bool) {
        viewModel.duplicateTrip(trip)
        if useHaptic {
            HapticManager.shared.impact(style: .medium)
        }
        showToast(message: "trip_duplicated")
    }

    private func duplicateDayToToday(_ group: DailyTripGroup) {
        viewModel.duplicateDayTrips(from: group.date)
        showToast(message: "copied_day \(group.date)")
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
        let calendar = Calendar.current
        let preferredDate = group.trips.first?.createdAt ?? range.lowerBound
        let normalized = calendar.startOfDay(for: preferredDate)
        pendingDuplicateDayTargetDate = range.contains(normalized) ? normalized : range.upperBound
        showDuplicateDayPicker = true
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
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        // 只在第一筆時記錄位置
                        if tutorialPositions.tripRowFrame == .zero {
                            tutorialPositions.tripRowFrame = geo.frame(in: .global)
                        }
                    }
            }
        )
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
            HapticManager.shared.notification(type: .warning)
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
            
            // 🔧 如果正在取消轉乘，直接執行
            if trip.isTransfer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    let tx = Transaction(animation: nil)
                    withTransaction(tx) {
                        viewModel.setTransferType(trip, transferType: nil)
                    }
                    HapticManager.shared.impact(style: .medium)
                    showToast(message: "transfer_cancelled")
                    isProcessingSwipeAction = false
                }
            } else {
                // 🔧 如果要添加轉乘，先檢查可用的轉乘類型
                let region = viewModel.cycleById(trip.cycleId)?.region ?? 
                            viewModel.cycleForTrip(date: trip.createdAt)?.region ?? 
                            AuthService.shared.currentRegion
                
                let availableTypes = region.availableTransferTypes
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if availableTypes.count > 1 {
                        // 多個選項，顯示選擇菜單（不震動，等選單內選擇後再震動）
                        transferSelectionData = TransferSelectionData(trip: trip, region: region)
                        isProcessingSwipeAction = false
                    } else if availableTypes.count == 1 {
                        // 只有一個選項，直接使用
                        let tx = Transaction(animation: nil)
                        withTransaction(tx) {
                            viewModel.setTransferType(trip, transferType: availableTypes[0])
                        }
                        HapticManager.shared.impact(style: .medium)
                        showToast(message: "transfer_added")
                        isProcessingSwipeAction = false
                    }
                }
            }
        } label: {
            Label(trip.isTransfer ? "cancel_transfer" : "add_transfer", systemImage: trip.isTransfer ? "link.badge.plus" : "link")
        }
        .tint(themeManager.accentColor)
        .disabled(isProcessingSwipeAction)
        
        Button {
            requestDuplicateTrip(trip, useDelay: true)
        } label: {
            Label("duplicate_trip", systemImage: "doc.on.doc.fill")
        }
        .tint(themeManager.accentColor)
        .disabled(isProcessingSwipeAction)
        
        Button {
            guard !isProcessingSwipeAction else { return }
            isProcessingSwipeAction = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let tx = Transaction(animation: nil)
                withTransaction(tx) {
                    viewModel.createReturnTrip(trip)
                }
                HapticManager.shared.impact(style: .medium)
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
            // 🔧 如果正在取消轉乘，直接執行
            if trip.isTransfer {
                viewModel.setTransferType(trip, transferType: nil)
                HapticManager.shared.impact(style: .medium)
                showToast(message: "transfer_cancelled")
            } else {
                // 🔧 如果要添加轉乘，先檢查可用的轉乘類型
                let region = viewModel.cycleById(trip.cycleId)?.region ?? 
                            viewModel.cycleForTrip(date: trip.createdAt)?.region ?? 
                            AuthService.shared.currentRegion
                
                let availableTypes = region.availableTransferTypes
                
                //     使用延遲確保資料準備完成
                DispatchQueue.main.async {
                    if availableTypes.count > 1 {
                        // 多個選項，顯示選擇菜單（不震動，等選單內選擇後再震動）
                        transferSelectionData = TransferSelectionData(trip: trip, region: region)
                    } else if availableTypes.count == 1 {
                        // 只有一個選項，直接使用
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

    private var sortedCycles: [Cycle] {
        (auth.currentUser?.cycles ?? []).sorted { $0.start > $1.start }
    }

    private var cycleAccessibilityValue: Text {
        if let region = viewModel.activeCycle?.region ?? sortedCycles.first?.region {
            return Text(viewModel.cycleDateRange) + Text(", ") + Text(region.displayNameKey)
        }
        return Text(viewModel.cycleDateRange)
    }
    
    var body: some View {
        Menu {
            Button { viewModel.selectedCycle = nil } label: {
                if viewModel.selectedCycle == nil { Label("currentCycleAuto", systemImage: "checkmark") }
                else { Text("currentCycleAuto") }
            }
            Divider()
            if !sortedCycles.isEmpty {
                ForEach(sortedCycles) { cycle in
                    Button { viewModel.selectedCycle = cycle } label: {
                        if viewModel.selectedCycle?.id == cycle.id {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cycle.title)
                                    Text(cycle.region.displayNameKey)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "checkmark")
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cycle.title)
                                Text(cycle.region.displayNameKey)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
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
                
                if let region = viewModel.activeCycle?.region ?? auth.currentUser?.cycles.first?.region {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                            .foregroundColor(themeManager.accentColor)
                        Text(region.displayNameKey)
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                        Spacer()
                    }
                }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("a11y_cycle"))
        .accessibilityValue(cycleAccessibilityValue)
        .accessibilityHint(Text("a11y_cycle_hint"))
    }
}

struct DailyHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    let group: DailyTripGroup
    let showDuplicateToToday: Bool
    let onDuplicateToToday: () -> Void
    let onDuplicateToDate: () -> Void
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
                .accessibilityLabel(Text("a11y_day_actions"))
                .accessibilityHint(Text("a11y_day_actions_hint \(group.date)"))
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
    
    private func displayStationName(_ stationName: String, type: TransportType) -> String {
        let lang = Locale.current.identifier
        if type == .tymrt {
            return TYMRTStationData.shared.displayStationName(stationName, languageCode: lang)
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

    private var accessibilitySummary: String {
        let separator = String(localized: "a11y_list_separator")
        var parts: [String] = [NSLocalizedString(trip.type.displayNameKey, comment: "")]

        if !trip.routeId.isEmpty {
            parts.append(String(format: NSLocalizedString("a11y_route_format", comment: ""), trip.routeId))
        }

        if !trip.startStation.isEmpty || !trip.endStation.isEmpty {
            let startName = trip.startStation.isEmpty ? "" : displayStationName(trip.startStation, type: trip.type)
            let endName = trip.endStation.isEmpty ? "" : displayStationName(trip.endStation, type: trip.type)
            if !startName.isEmpty && !endName.isEmpty {
                parts.append(String(format: NSLocalizedString("a11y_station_range_format", comment: ""), startName, endName))
            } else if !startName.isEmpty {
                parts.append(String(format: NSLocalizedString("a11y_start_format", comment: ""), startName))
            } else if !endName.isEmpty {
                parts.append(String(format: NSLocalizedString("a11y_end_format", comment: ""), endName))
            }
        }

        parts.append(String(format: NSLocalizedString("a11y_time_format", comment: ""), trip.timeStr))
        parts.append(String(format: NSLocalizedString("a11y_paid_format", comment: ""), trip.paidPrice))

        if trip.paidPrice != trip.originalPrice {
            parts.append(String(format: NSLocalizedString("a11y_original_format", comment: ""), trip.originalPrice))
        }
        if trip.isFree {
            parts.append(NSLocalizedString("a11y_free_trip", comment: ""))
        }
        if trip.isTransfer {
            parts.append(NSLocalizedString("a11y_transfer_discount", comment: ""))
        }
        if !trip.note.isEmpty {
            parts.append(NSLocalizedString("a11y_has_note", comment: ""))
        }

        return parts.joined(separator: separator)
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
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
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
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject var auth: AuthService //     添加 auth 以傳遞給子視圖
    @EnvironmentObject var themeManager: ThemeManager //     添加 themeManager 以傳遞給子視圖
    @Binding var showAddTripSheet: Bool
    @Binding var showFavoritesSheet: Bool
    @Binding var selectedTripToEdit: Trip?
    @Binding var transferSelectionData: TransferSelectionData?
    @Binding var isProcessingSwipeAction: Bool
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
            //     新增：轉乘類型選擇菜單
            .sheet(item: $transferSelectionData) { data in
                TransferTypeSelectionView(
                    trip: data.trip,
                    region: data.region,
                    viewModel: viewModel,
                    isPresented: Binding(
                        get: { transferSelectionData != nil },
                        set: { if !$0 { transferSelectionData = nil } }
                    ),
                    onSelected: { selectedType in
                        if selectedType != nil {
                            showToast("transfer_added")
                        } else {
                            showToast("transfer_cancelled")
                        }
                        isProcessingSwipeAction = false
                    }
                )
                .environmentObject(auth) //     傳遞 auth 服務
                .environmentObject(themeManager) //     傳遞 themeManager
                .presentationDetents([.height(420), .medium])
                .presentationDragIndicator(.visible)
            }
    }
}

struct TripListAlertsModifier: ViewModifier {
    @EnvironmentObject var viewModel: AppViewModel
    @Binding var pendingDeleteDate: String?
    @Binding var showCommuterNamePrompt: Bool
    @Binding var commuterRouteName: String
    @Binding var pendingCommuterTrip: Trip?
    let showToast: (LocalizedStringKey) -> Void
    
    func body(content: Content) -> some View {
        content
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

// MARK: - Preference Keys for Tutorial Position Tracking

struct FavoritesButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct CycleSelectorFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct AddButtonFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct TripRowFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
