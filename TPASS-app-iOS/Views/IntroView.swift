import SwiftUI

// MARK: - Intro Design Tokens
//
// 對應 Claude Design 的 Onboarding Redesign · Variant A 暖色系。
// 沒有的色彩用 inline RGB 補上，已存在的 IntroAccent / IntroSuccess /
// IntroWarning 沿用 Asset Catalog。
enum IntroDesign {
    static let mainTheme   = Color(red: 175/255, green: 124/255, blue: 97/255) // #AF7C61
    static let bg          = Color(red: 0xF5/255, green: 0xEF/255, blue: 0xE6/255)
    static let bgWarm      = Color(red: 0xEF/255, green: 0xE6/255, blue: 0xD7/255)
    static let card        = Color(red: 0xFA/255, green: 0xF6/255, blue: 0xEF/255)
    static let ink         = Color(red: 0x2A/255, green: 0x1F/255, blue: 0x17/255)
    static let inkSoft     = Color(red: 0x5A/255, green: 0x4A/255, blue: 0x3A/255)
    static let muted       = Color(red: 0x8A/255, green: 0x7A/255, blue: 0x68/255)
    static let hair        = Color.black.opacity(0.08)
    static let hairStrong  = Color.black.opacity(0.14)
    static let brand       = mainTheme
    static let brandDark   = mainTheme.opacity(0.8)
    static let brandSoft   = mainTheme.opacity(0.3)
    static let brandWash   = mainTheme.opacity(0.1)
    static let success     = Color("Colors/Intro/IntroSuccess")
    static let warning     = Color("Colors/Intro/IntroWarning")

    /// IntroView 暫存待寫入 SwiftData 的票卡的 UserDefaults key。
    /// 由 MainTabView / AppViewModel 在登入後讀取並寫入 SwiftData。
    static let pendingCardsKey = "pending_intro_cards"
}

// MARK: - Onboarding Draft 票卡
//
// IntroView 沒有 SwiftData modelContext（modelContainer 只附在 MainTabView），
// 因此先以 Codable 結構暫存到 UserDefaults，等使用者登入完成後再由
// MainTabView/AppViewModel 在啟動時取出並寫入 SwiftData。
struct DraftTransitCard: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: TransitCardType
}

private enum CardEditorMode: Equatable, Hashable {
    case add
    case edit(Int)
}

// MARK: - 新版 Onboarding 主容器（開發預覽用，預設顯示舊版 IntroView）
struct NewIntroView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var step: Int = 0
    @State private var isCheckingDeveloperSkip = false
    @State private var showDeveloperSkipAlert = false

    // Onboarding 收集的資料
    @State private var selectedIdentity: Identity = .adult
    @State private var selectedRegion: TPASSRegion = .north
    @State private var cycleStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var cycleEndDate: Date = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: 29, to: today) ?? today
    }()
    @State private var selectedCitizenCity: TaiwanCity? = nil
    @State private var notificationRequested: Bool = false
    @State private var notificationOptIn: Bool? = nil   // nil / true(已開啟) / false(略過)
    @State private var dailyReminderEnabled: Bool = false
    @State private var dailyReminderTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var cycleReminderEnabled: Bool = false
    @State private var selectedTheme: AppTheme = .muji  // 預設暖色主題
    @State private var pendingCards: [DraftTransitCard] = []
    @State private var cardEditor: CardEditorMode? = nil
    @State private var isGoingForward: Bool = true

    private let totalSteps = 8     // welcome / identity / plan / citizen / notif / theme / cards / done
    private var isFirstStep: Bool { step == 0 }
    private var isLastStep: Bool { step == totalSteps - 1 }

    var body: some View {
        ZStack {
            IntroDesign.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if !isFirstStep && !isLastStep && cardEditor == nil {
                    IntroStepHeader(
                        step: step,
                        total: totalSteps
                    )
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                    .transition(.opacity)
                }

                ZStack {
                    if let editor = cardEditor {
                        IntroCardEditor(
                            initial: editingCard(for: editor),
                            onSave: { card in
                                handleEditorSave(card, mode: editor)
                            },
                            onCancel: {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    cardEditor = nil
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        currentStep
                            .id(step)
                            .transition(.asymmetric(
                                insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
                                removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: step)
                .animation(.easeInOut(duration: 0.22), value: cardEditor)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 3)
                .onEnded { _ in
                    guard isFirstStep else { return }
                    validateDeveloperSkipAccess()
                }
        )
        .alert("開發者快速跳過", isPresented: $showDeveloperSkipAlert) {
            Button("取消", role: .cancel) { }
            Button("跳過 Intro") { skipIntroForDeveloper() }
        } message: {
            Text("已通過開發者驗證，是否直接跳過 Intro？")
        }
    }

    // MARK: 步驟 dispatch
    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case 0:
            IntroStepWelcome(onNext: goNext)
        case 1:
            IntroStepIdentity(selected: $selectedIdentity, onNext: goNext, onBack: goBack)
        case 2:
            IntroStepPlan(
                selectedRegion: $selectedRegion,
                startDate: $cycleStartDate,
                endDate: $cycleEndDate,
                onNext: goNext,
                onBack: goBack
            )
        case 3:
            IntroStepCitizen(selectedCity: $selectedCitizenCity, onNext: goNext, onBack: goBack)
        case 4:
            IntroStepNotification(
                notificationRequested: $notificationRequested,
                notificationOptIn: $notificationOptIn,
                dailyReminderEnabled: $dailyReminderEnabled,
                dailyReminderTime: $dailyReminderTime,
                cycleReminderEnabled: $cycleReminderEnabled,
                onNext: goNext,
                onBack: goBack
            )
        case 5:
            IntroStepTheme(
                selectedTheme: $selectedTheme,
                applyTheme: applyTheme,
                onNext: goNext,
                onBack: goBack
            )
        case 6:
            IntroStepCards(
                cards: $pendingCards,
                onAdd: {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.easeInOut(duration: 0.22)) { cardEditor = .add }
                },
                onEdit: { idx in
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.easeInOut(duration: 0.22)) { cardEditor = .edit(idx) }
                },
                onDelete: { idx in
                    HapticManager.shared.notification(type: .warning)
                    if pendingCards.indices.contains(idx) {
                        pendingCards.remove(at: idx)
                    }
                },
                onNext: goNext,
                onBack: goBack
            )
        case 7:
            IntroStepDone(
                selectedIdentity: selectedIdentity,
                selectedRegion: selectedRegion,
                cycleStartDate: cycleStartDate,
                cycleEndDate: cycleEndDate,
                selectedCitizenCity: selectedCitizenCity,
                notificationOptIn: notificationOptIn,
                selectedTheme: selectedTheme,
                cards: pendingCards,
                onStart: handleStart,
                onBack: goBack
            )
        default:
            EmptyView()
        }
    }

    /// 即時套用使用者選擇的主題到全域 ThemeManager。
    /// SwiftUI 的 view body 與 button action 都在 main actor 上執行，所以
    /// 這裡不需要額外加 @MainActor 修飾，而且未加修飾才能被存成
    /// `let applyTheme: (AppTheme) -> Void` 傳入子 view。
    private func applyTheme(_ theme: AppTheme) {
        themeManager.currentTheme = theme
    }

    // MARK: 導航
    private func goNext() {
        HapticManager.shared.impact(style: .light)
        isGoingForward = true
        withAnimation(.easeInOut(duration: 0.28)) {
            step = min(totalSteps - 1, step + 1)
        }
    }

    private func goBack() {
        HapticManager.shared.impact(style: .soft)
        isGoingForward = false
        withAnimation(.easeInOut(duration: 0.28)) {
            step = max(0, step - 1)
        }
    }

    // MARK: 票卡編輯
    private func editingCard(for mode: CardEditorMode) -> DraftTransitCard? {
        if case .edit(let i) = mode, pendingCards.indices.contains(i) {
            return pendingCards[i]
        }
        return nil
    }

    private func handleEditorSave(_ card: DraftTransitCard, mode: CardEditorMode) {
        switch mode {
        case .add:
            pendingCards.append(card)
            HapticManager.shared.notification(type: .success)
        case .edit(let idx):
            if pendingCards.indices.contains(idx) {
                var updated = card
                updated.id = pendingCards[idx].id
                pendingCards[idx] = updated
            }
            HapticManager.shared.impact(style: .medium)
        }
        withAnimation(.easeInOut(duration: 0.22)) { cardEditor = nil }
    }

    // MARK: 完成 onboarding
    private func handleStart() {
        HapticManager.shared.impact(style: .medium)
        if cycleReminderEnabled {
            let tempCycle = Cycle(id: UUID().uuidString, start: cycleStartDate, end: cycleEndDate)
            NotificationManager.shared.scheduleCycleReminders(enabled: true, currentCycle: tempCycle)
        }
        savePendingCards()
        auth.createAnonymousUser(
            identity: selectedIdentity,
            region: selectedRegion,
            citizenCity: selectedCitizenCity,
            cycleStart: cycleStartDate,
            cycleEnd: cycleEndDate
        )
    }

    /// 將暫存票卡序列化到 UserDefaults，等 MainTabView/AppViewModel 在登入完成
    /// 後讀取並寫入 SwiftData 後再清除（清除動作建議由消費端執行）。
    private func savePendingCards() {
        if pendingCards.isEmpty {
            UserDefaults.standard.removeObject(forKey: IntroDesign.pendingCardsKey)
            return
        }
        if let data = try? JSONEncoder().encode(pendingCards) {
            UserDefaults.standard.set(data, forKey: IntroDesign.pendingCardsKey)
        }
    }

    // MARK: 開發者快速跳過
    private func validateDeveloperSkipAccess() {
        guard !isCheckingDeveloperSkip else { return }
        isCheckingDeveloperSkip = true
        Task {
            let result = await DeveloperAccessService.shared.verifyCurrentUserAccess()
            await MainActor.run {
                isCheckingDeveloperSkip = false
                if case .allowed = result { showDeveloperSkipAlert = true }
            }
        }
    }

    private func skipIntroForDeveloper() {
        if UserDefaults.standard.data(forKey: "local_user") != nil {
            auth.loadLocalUser()
            return
        }
        savePendingCards()
        auth.createAnonymousUser(
            identity: selectedIdentity,
            region: selectedRegion,
            citizenCity: selectedCitizenCity,
            cycleStart: cycleStartDate,
            cycleEnd: cycleEndDate
        )
    }
}

// MARK: - Step Header（返回鍵 + 進度條 + 步驟編號）
struct IntroStepHeader: View {
    let step: Int
    let total: Int

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(IntroDesign.hair)
                    Capsule()
                        .fill(IntroDesign.brand)
                        .frame(width: max(8, geo.size.width * CGFloat(step + 1) / CGFloat(total)))
                        .animation(.easeInOut(duration: 0.28), value: step)
                }
            }
            .frame(height: 4)

            Text(String(format: "%02d/%02d", step + 1, total))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(IntroDesign.muted)
                .tracking(0.5)
                .frame(minWidth: 42, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
    }
}

struct IntroBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 54, height: 54)
                .background(IntroDesign.brand)
                .clipShape(Circle())
        }
    }
}

// MARK: - 通用按鈕
struct IntroPrimaryButton: View {
    private let title: Text
    var disabled: Bool = false
    let action: () -> Void

    init(title: LocalizedStringKey, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = Text(title)
        self.disabled = disabled
        self.action = action
    }

    init(verbatim: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = Text(verbatim)
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            title
                .font(.system(size: 17, weight: .bold))
                .tracking(0.2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(disabled ? IntroDesign.brandSoft : IntroDesign.brand)
                .clipShape(Capsule())
        }
        .disabled(disabled)
    }
}

struct IntroGhostButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(IntroDesign.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
    }
}

private struct IntroEyebrow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(IntroDesign.brand)
            .tracking(2)
            .textCase(.uppercase)
    }
}

private struct IntroStepFooter<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: 6) { content }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 12)
    }
}

// MARK: - 1. Welcome
struct IntroStepWelcome: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroWelcome().frame(maxWidth: .infinity).frame(height: 240)

            VStack(alignment: .leading, spacing: 14) {
                IntroEyebrow(text: "WELCOME")
                Text("幾個小設定，\n就能開始記帳")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(IntroDesign.ink)
                    .tracking(-0.5)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Text("跟著 7 個步驟告訴我們你的身份、想用的 TPASS 方案，還有手邊常用的票卡。需要時都可以回上一步調整。")
                    .font(.system(size: 15))
                    .foregroundColor(IntroDesign.inkSoft)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer(minLength: 8)

            IntroStepFooter {
                IntroPrimaryButton(verbatim: "開始設定") { onNext() }
            }
        }
    }
}

private struct IntroHeroWelcome: View {
    @State private var spin = false
    @State private var bob  = false
    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [IntroDesign.brandWash, IntroDesign.bg]),
                center: UnitPoint(x: 0.5, y: 0.95),
                startRadius: 10, endRadius: 240
            )

            // 三層軌道
            ZStack {
                orbit(diameter: 184,
                      ringColor: IntroDesign.brand.opacity(0.18),
                      dotColor: IntroDesign.brand,
                      dotSize: 7,
                      dotOffsetX: 92,
                      duration: 28,
                      reverse: false)
                orbit(diameter: 120,
                      ringColor: IntroDesign.success.opacity(0.25),
                      dotColor: IntroDesign.success,
                      dotSize: 6,
                      dotOffsetX: 60,
                      duration: 18,
                      reverse: true)
                orbit(diameter: 72,
                      ringColor: IntroDesign.warning.opacity(0.3),
                      dotColor: IntroDesign.warning,
                      dotSize: 5,
                      dotOffsetX: 36,
                      duration: 12,
                      reverse: false)
            }
            .offset(y: 16)

            // 中央品牌標
            Image("icon")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .cornerRadius(18)
                .shadow(color: IntroDesign.brand.opacity(0.35),
                        radius: 14, x: 0, y: 12)
            .offset(y: 16 + (bob ? -6 : 0))
        }
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 0).delay(0)) { spin = true }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { bob = true }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func orbit(diameter: CGFloat,
                       ringColor: Color,
                       dotColor: Color,
                       dotSize: CGFloat,
                       dotOffsetX: CGFloat,
                       duration: Double,
                       reverse: Bool) -> some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let degrees = (t / duration) * 360 * (reverse ? -1 : 1)
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [2, 5]))
                    .foregroundColor(ringColor)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: dotOffsetX)
                    .rotationEffect(.degrees(degrees))
            }
        }
    }
}

// MARK: - 2. Identity
struct IntroStepIdentity: View {
    @Binding var selected: Identity
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroIdentity(selected: selected)
                .frame(maxWidth: .infinity).frame(height: 200)

            VStack(alignment: .leading, spacing: 6) {
                Text("選擇你的身份")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(IntroDesign.ink)
                    .tracking(-0.3)
                Text("會影響票價計算與轉乘優惠的金額")
                    .font(.system(size: 13))
                    .foregroundColor(IntroDesign.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            VStack(spacing: 10) {
                IdentityRow(
                    isSelected: selected == .adult,
                    title: "intro_identity_adult_title",
                    sub: "預設票價、常見轉乘優惠"
                ) { selected = .adult; HapticManager.shared.impact(style: .light) }
                IdentityRow(
                    isSelected: selected == .student,
                    title: "intro_identity_student_title",
                    sub: "校園票價、學生轉乘優惠"
                ) { selected = .student; HapticManager.shared.impact(style: .light) }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 12)

            IntroStepFooter {
                HStack(spacing: 12) {
                    if let onBack = onBack { IntroBackButton(action: onBack) }
                    IntroPrimaryButton(verbatim: "繼續") { onNext() }
                }
            }
        }
    }

    private struct IdentityRow: View {
        let isSelected: Bool
        let title: LocalizedStringKey
        let sub: String
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Color.clear : IntroDesign.hairStrong, lineWidth: 2)
                            .background(
                                Circle().fill(isSelected ? Color.white : Color.clear)
                            )
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle().fill(IntroDesign.brand).frame(width: 10, height: 10)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isSelected ? .white : IntroDesign.ink)
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? Color.white.opacity(0.85) : IntroDesign.muted)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? IntroDesign.brand : IntroDesign.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : IntroDesign.hair, lineWidth: 1)
                )
                .shadow(color: isSelected ? IntroDesign.brand.opacity(0.25) : .clear,
                        radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct IntroHeroIdentity: View {
    let selected: Identity
    var body: some View {
        ZStack {
            IntroDesign.brandWash
            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    // 地面虛線
                    Path { p in
                        p.move(to: CGPoint(x: 20, y: geo.size.height - 30))
                        p.addLine(to: CGPoint(x: w - 20, y: geo.size.height - 30))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                    .foregroundColor(IntroDesign.ink.opacity(0.12))

                    // 一般成人（左）
                    figure(headOffset: CGPoint(x: w * 0.34, y: geo.size.height - 102),
                           bodyOffset: CGPoint(x: w * 0.34, y: geo.size.height - 60),
                           highlighted: selected == .adult)

                    // 學生（右）
                    studentFigure(headOffset: CGPoint(x: w * 0.66, y: geo.size.height - 90),
                                  bodyOffset: CGPoint(x: w * 0.66, y: geo.size.height - 55),
                                  highlighted: selected == .student)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func figure(headOffset: CGPoint,
                        bodyOffset: CGPoint,
                        highlighted: Bool) -> some View {
        let color = highlighted ? IntroDesign.brand : IntroDesign.hairStrong
        ZStack {
            Circle().fill(color).frame(width: 40, height: 40)
                .position(headOffset)
            RoundedRectangle(cornerRadius: 14)
                .fill(color)
                .frame(width: 48, height: 68)
                .position(bodyOffset)
        }
    }

    @ViewBuilder
    private func studentFigure(headOffset: CGPoint,
                               bodyOffset: CGPoint,
                               highlighted: Bool) -> some View {
        let color = highlighted ? IntroDesign.brand : IntroDesign.hairStrong
        let capColor = highlighted ? IntroDesign.brandDark : IntroDesign.muted
        ZStack {
            Circle().fill(color).frame(width: 34, height: 34)
                .position(headOffset)
            // 學士帽
            Rectangle().fill(capColor)
                .frame(width: 40, height: 6)
                .position(x: headOffset.x, y: headOffset.y - 22)
            Rectangle().fill(capColor)
                .frame(width: 30, height: 4)
                .position(x: headOffset.x, y: headOffset.y - 17)
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(width: 40, height: 58)
                .position(bodyOffset)
        }
    }
}

// MARK: - 3. Plan
struct IntroStepPlan: View {
    @Binding var selectedRegion: TPASSRegion
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private let regionGroups: [(title: LocalizedStringKey, regions: [TPASSRegion])] = [
        ("intro_plan_group_flexible", [.flexible]),
        ("intro_plan_group_north", [.north, .keelungOnly, .beiYiMegaPASS, .beiYi]),
        ("intro_plan_group_taoyuan_hsinchu", [.taoZhuZhu, .taoZhuZhuMiao, .zhuZhuMiao]),
        ("intro_plan_group_yilan", [.yilan, .yilan3Days]),
        ("intro_plan_group_central", [.central, .centralCitizen]),
        ("intro_plan_group_south", [.south, .kaohsiung]),
        ("intro_plan_group_tainan", [.tainanNoTRA, .tainanWithTRA, .tainanChiayiTRA, .chiayiTainan])
    ]

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroPlan().frame(maxWidth: .infinity).frame(height: 170)

            VStack(alignment: .leading, spacing: 4) {
                Text("選擇 TPASS 方案")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(IntroDesign.ink)
                Text("這會決定每月的扣款基準和適用區域")
                    .font(.system(size: 13))
                    .foregroundColor(IntroDesign.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(Array(regionGroups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.title)
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.5)
                                .textCase(.uppercase)
                                .foregroundColor(IntroDesign.muted)
                                .padding(.leading, 4)
                            VStack(spacing: 6) {
                                ForEach(group.regions, id: \.self) { region in
                                    planRow(region)
                                }
                            }
                        }
                    }

                    cycleCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }

            IntroStepFooter {
                HStack(spacing: 12) {
                    if let onBack = onBack { IntroBackButton(action: onBack) }
                    IntroPrimaryButton(verbatim: "繼續") { onNext() }
                }
            }
        }
        .onChange(of: selectedRegion) { _, newRegion in
            resetDatesForRegion(newRegion)
        }
        .onChange(of: startDate) { _, newStart in
            if selectedRegion != .flexible {
                let cal = Calendar.current
                endDate = cal.date(byAdding: .day,
                                   value: 29,
                                   to: cal.startOfDay(for: newStart)) ?? newStart
            }
        }
    }

    private func planRow(_ region: TPASSRegion) -> some View {
        let isSelected = selectedRegion == region
        let isFlexible = region == .flexible
        return Button {
            HapticManager.shared.impact(style: .light)
            selectedRegion = region
        } label: {
            HStack(spacing: 8) {
                if isFlexible {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : IntroDesign.success)
                }
                Text(region.displayNameKey)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : IntroDesign.ink)
                Spacer()
                Text(region.monthlyPrice > 0
                     ? "$\(region.monthlyPrice)"
                     : String(localized: "intro_plan_price_free"))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? Color.white.opacity(0.92) : IntroDesign.muted)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? IntroDesign.brand : IntroDesign.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : IntroDesign.hair, lineWidth: 1)
            )
            .shadow(color: isSelected ? IntroDesign.brand.opacity(0.22) : .clear,
                    radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("使用週期")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundColor(IntroDesign.muted)

            HStack(spacing: 10) {
                DatePicker("start_date",
                           selection: $startDate,
                           displayedComponents: .date)
                    .labelsHidden()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(IntroDesign.muted)
                DatePicker("end_date",
                           selection: $endDate,
                           displayedComponents: .date)
                    .labelsHidden()
            }
            .environment(\.locale, Locale(identifier: "zh-Hant_TW"))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(IntroDesign.bgWarm)
        )
    }

    private func resetDatesForRegion(_ region: TPASSRegion) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if region == .flexible {
            if let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: today)),
               let lastDay = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) {
                startDate = firstDay
                endDate = cal.startOfDay(for: lastDay)
            }
        } else {
            startDate = today
            endDate = cal.date(byAdding: .day, value: 29, to: today) ?? today
        }
    }
}

private struct IntroHeroPlan: View {
    var body: some View {
        ZStack {
            IntroDesign.brandWash
            // grid
            GeometryReader { geo in
                let cellW: CGFloat = 20
                let cols = Int(geo.size.width / cellW) + 1
                let rows = Int(geo.size.height / cellW) + 1
                Path { p in
                    for c in 0..<cols {
                        let x = CGFloat(c) * cellW
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    for r in 0..<rows {
                        let y = CGFloat(r) * cellW
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(IntroDesign.ink.opacity(0.06), lineWidth: 1)

                // 路線曲線
                Path { p in
                    let h = geo.size.height
                    let w = geo.size.width
                    p.move(to: CGPoint(x: 24, y: h - 24))
                    p.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.55),
                                   control: CGPoint(x: w * 0.18, y: h - 30))
                    p.addQuadCurve(to: CGPoint(x: w * 0.7, y: h * 0.32),
                                   control: CGPoint(x: w * 0.55, y: h * 0.4))
                    p.addQuadCurve(to: CGPoint(x: w - 24, y: 18),
                                   control: CGPoint(x: w * 0.85, y: h * 0.18))
                }
                .stroke(IntroDesign.brand,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // 站點
                stop(x: 24, y: geo.size.height - 24, fill: .white,
                     stroke: IntroDesign.brand, size: 10)
                stop(x: geo.size.width * 0.38, y: geo.size.height * 0.55,
                     fill: IntroDesign.success, stroke: nil, size: 8)
                stop(x: geo.size.width * 0.7, y: geo.size.height * 0.32,
                     fill: IntroDesign.warning, stroke: nil, size: 8)
                stop(x: geo.size.width - 24, y: 18,
                     fill: IntroDesign.brand, stroke: nil, size: 12)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stop(x: CGFloat, y: CGFloat,
                      fill: Color, stroke: Color?, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(fill).frame(width: size, height: size)
            if let s = stroke {
                Circle().stroke(s, lineWidth: 2.5).frame(width: size, height: size)
            }
        }
        .position(x: x, y: y)
    }
}

// MARK: - 4. Citizen
struct IntroStepCitizen: View {
    @Binding var selectedCity: TaiwanCity?
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroCitizen().frame(maxWidth: .infinity).frame(height: 170)

            VStack(alignment: .leading, spacing: 4) {
                Text("市民身份")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(IntroDesign.ink)
                Text("某些縣市有專屬的市民票價，沒有的話選「不指定」")
                    .font(.system(size: 13))
                    .foregroundColor(IntroDesign.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                    spacing: 6
                ) {
                    cityChip(label: "citizen_city_all",
                             isSelected: selectedCity == nil) {
                        selectedCity = nil
                        HapticManager.shared.impact(style: .light)
                    }
                    ForEach(TaiwanCity.allCases) { city in
                        cityChip(label: city.displayName,
                                 isSelected: selectedCity == city) {
                            selectedCity = city
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }

            IntroStepFooter {
                HStack(spacing: 12) {
                    if let onBack = onBack { IntroBackButton(action: onBack) }
                    IntroPrimaryButton(verbatim: "繼續") { onNext() }
                }
            }
        }
    }

    private func cityChip(label: LocalizedStringKey,
                          isSelected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : IntroDesign.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? IntroDesign.brand : IntroDesign.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.clear : IntroDesign.hair, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct IntroHeroCitizen: View {
    @State private var float = false
    var body: some View {
        ZStack {
            IntroDesign.brandWash
            GeometryReader { geo in
                let baseY = geo.size.height - 18
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: 20, y: baseY))
                        p.addLine(to: CGPoint(x: geo.size.width - 20, y: baseY))
                    }
                    .stroke(IntroDesign.ink.opacity(0.1), lineWidth: 1.5)

                    HStack(alignment: .bottom, spacing: 8) {
                        building(width: 28, height: 50, color: IntroDesign.brandSoft, delay: 0)
                        building(width: 32, height: 70, color: IntroDesign.brand, delay: 0.4)
                        building(width: 36, height: 88, color: IntroDesign.brandDark, delay: 0.8)
                        building(width: 30, height: 60, color: IntroDesign.brand, delay: 1.2)
                        building(width: 26, height: 44, color: IntroDesign.brandSoft, delay: 1.6)
                    }
                    .frame(width: geo.size.width)
                    .position(x: geo.size.width / 2, y: baseY - 50)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .onAppear { float = true }
    }

    @ViewBuilder
    private func building(width: CGFloat, height: CGFloat, color: Color, delay: Double) -> some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let lift = sin((t + delay) * .pi * 2 / 3.5) * 4 // ±4pt 浮動
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: width, height: height)
                    // windows
                    let rows = max(1, Int(height) / 14)
                    VStack(spacing: 8) {
                        ForEach(0..<rows, id: \.self) { _ in
                            HStack {
                                Rectangle().fill(Color.white.opacity(0.55))
                                    .frame(width: 4, height: 4)
                                Spacer()
                                Rectangle().fill(Color.white.opacity(0.55))
                                    .frame(width: 4, height: 4)
                            }
                            .padding(.horizontal, 6)
                        }
                    }
                    .padding(.top, 8)
                    .frame(width: width, height: height)
                }
            }
            .offset(y: lift)
        }
    }
}

// MARK: - 5. Notification
struct IntroStepNotification: View {
    @Binding var notificationRequested: Bool
    @Binding var notificationOptIn: Bool?
    @Binding var dailyReminderEnabled: Bool
    @Binding var dailyReminderTime: Date
    @Binding var cycleReminderEnabled: Bool
    let onNext: () -> Void
    let onBack: (() -> Void)?

    private var permissionGranted: Bool {
        NotificationManager.shared.isAuthorized || notificationRequested
    }

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroNotification().frame(maxWidth: .infinity).frame(height: 200)

            if permissionGranted {
                // 已授權 → 顯示雙開關
                VStack(alignment: .leading, spacing: 6) {
                    Text("通知設定")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(IntroDesign.ink)
                        .tracking(-0.3)
                    Text("選擇想接收哪些提醒，隨時可在設定裡調整。")
                        .font(.system(size: 13))
                        .foregroundColor(IntroDesign.muted)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 18)

                VStack(spacing: 12) {
                    // 每日提醒
                    VStack(alignment: .leading, spacing: 0) {
                        Toggle(isOn: $dailyReminderEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("notification_daily_toggle")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(IntroDesign.ink)
                                Text("notification_daily_section_footer")
                                    .font(.system(size: 12))
                                    .foregroundColor(IntroDesign.muted)
                                    .lineSpacing(2)
                            }
                        }
                        .tint(IntroDesign.brand)
                        .padding(16)

                        if dailyReminderEnabled {
                            Divider()
                                .background(IntroDesign.hair)
                                .padding(.horizontal, 16)
                            DatePicker(
                                String(localized: "notification_daily_time"),
                                selection: $dailyReminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .environment(\.locale, Locale(identifier: "zh-Hant_TW"))
                            .font(.system(size: 14))
                            .foregroundColor(IntroDesign.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 14).fill(IntroDesign.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(IntroDesign.hair, lineWidth: 1))

                    // 月票到期提醒
                    Toggle(isOn: $cycleReminderEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("notification_cycle_toggle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(IntroDesign.ink)
                            Text("notification_cycle_section_footer")
                                .font(.system(size: 12))
                                .foregroundColor(IntroDesign.muted)
                                .lineSpacing(2)
                        }
                    }
                    .tint(IntroDesign.brand)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(IntroDesign.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(IntroDesign.hair, lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .onChange(of: dailyReminderEnabled) { _, enabled in
                    NotificationManager.shared.scheduleDailyReminder(enabled: enabled, time: dailyReminderTime)
                }
                .onChange(of: dailyReminderTime) { _, newTime in
                    if dailyReminderEnabled {
                        NotificationManager.shared.scheduleDailyReminder(enabled: true, time: newTime)
                    }
                }

                Spacer(minLength: 12)

                HStack(alignment: .bottom, spacing: 12) {
                    if let onBack = onBack { IntroBackButton(action: onBack) }
                    IntroPrimaryButton(verbatim: "繼續") {
                        notificationOptIn = (dailyReminderEnabled || cycleReminderEnabled) ? true : notificationOptIn
                        onNext()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            } else {
                // 尚未授權 → 詢問是否開啟
                VStack(alignment: .leading, spacing: 12) {
                    Text("要在月票快結束時提醒你嗎？")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(IntroDesign.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("只在週期最後一天前一晚提醒，不會做別的事。也可以之後到設定再開。")
                        .font(.system(size: 14))
                        .foregroundColor(IntroDesign.inkSoft)
                        .lineSpacing(3)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(IntroDesign.muted)
                            .padding(.top, 1)
                        Text("iOS 系統會跳出一次權限要求，你可以隨時關閉。")
                            .font(.system(size: 12))
                            .foregroundColor(IntroDesign.inkSoft)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(IntroDesign.bgWarm))
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)

                // 開啟通知：畫面中間，全寬膠囊
                IntroPrimaryButton(title: "intro_notification_enable_button") {
                    NotificationManager.shared.requestAuthorization()
                    notificationRequested = true
                    notificationOptIn = true
                    UserDefaults.standard.set(true, forKey: "didPromptNotificationPermission")
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)

                Spacer(minLength: 12)

                // 底部：返回 + 略過，等寬膠囊
                HStack(spacing: 12) {
                    if let onBack = onBack {
                        IntroBackButton(action: onBack)
                    }

                    Button {
                        notificationRequested = true
                        notificationOptIn = false
                        onNext()
                    } label: {
                        Text("略過")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(IntroDesign.brand)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(IntroDesign.brand, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct IntroHeroNotification: View {
    var body: some View {
        ZStack {
            IntroDesign.brandWash
            // 鈴鐺 + ping
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    PingCircle(delay: Double(i) * 0.6)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(IntroDesign.brand)
                        .frame(width: 80, height: 80)
                        .shadow(color: IntroDesign.brand.opacity(0.35),
                                radius: 14, x: 0, y: 12)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private struct PingCircle: View {
        let delay: Double
        var body: some View {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate + delay
                let cycle = 1.8
                let phase = (t.truncatingRemainder(dividingBy: cycle)) / cycle
                let scale = 0.6 + phase * 0.8
                let opacity = (1 - phase) * 0.7
                Circle()
                    .stroke(IntroDesign.brand, lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
    }
}

// MARK: - 6. Theme（主題選擇）
//
// 對應 ThemeManager.AppTheme：system / light / dark / muji（暖色，預設）/ purple。
// 使用者一進入此頁就立即套用暖色主題，後續切換時也會即時更新 ThemeManager。
struct IntroStepTheme: View {
    @Binding var selectedTheme: AppTheme
    let applyTheme: (AppTheme) -> Void
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroTheme(theme: selectedTheme)
                .frame(maxWidth: .infinity).frame(height: 200)

            VStack(alignment: .leading, spacing: 6) {
                Text("選擇外觀主題")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(IntroDesign.ink)
                    .tracking(-0.3)
                Text("會影響整個 App 的色系；隨時可在設定裡更換。")
                    .font(.system(size: 13))
                    .foregroundColor(IntroDesign.muted)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        themeRow(theme: theme, isSelected: selectedTheme == theme) {
                            HapticManager.shared.impact(style: .light)
                            selectedTheme = theme
                            applyTheme(theme)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }

            HStack(alignment: .bottom, spacing: 12) {
                if let onBack = onBack { IntroBackButton(action: onBack) }
                IntroPrimaryButton(verbatim: "繼續") { onNext() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            // 第一次進入此頁就把預設的暖色主題套上去，
            // 讓使用者馬上看到選擇結果。
            applyTheme(selectedTheme)
        }
    }

    private func themeRow(theme: AppTheme,
                          isSelected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ThemeSwatch(theme: theme).frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.localizedDisplayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : IntroDesign.ink)
                    Text(themeSubtitle(theme))
                        .font(.system(size: 12))
                        .foregroundColor(isSelected
                                         ? Color.white.opacity(0.85)
                                         : IntroDesign.muted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? IntroDesign.brand : IntroDesign.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.clear : IntroDesign.hair, lineWidth: 1)
            )
            .shadow(color: isSelected ? IntroDesign.brand.opacity(0.22) : .clear,
                    radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func themeSubtitle(_ theme: AppTheme) -> String {
        switch theme {
        case .system:  return "跟著裝置切換深淺色"
        case .light:   return "明亮乾淨的白色介面"
        case .dark:    return "夜間舒適的深色介面"
        case .muji:    return "推薦：紙感暖色系"
        case .purple:  return "柔和的紫色基調"
        }
    }
}

// 主題色塊：用代表色塊預覽各主題的氛圍。
private struct ThemeSwatch: View {
    let theme: AppTheme
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.bg)
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.accent)
                    .frame(width: 28, height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.text.opacity(0.7))
                    .frame(width: 36, height: 4)
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.text.opacity(0.4))
                    .frame(width: 22, height: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var palette: (bg: Color, accent: Color, text: Color) {
        switch theme {
        case .system:
            return (
                bg: Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255),
                accent: Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255),
                text: Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255)
            )
        case .light:
            return (
                bg: Color.white,
                accent: Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255),
                text: Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255)
            )
        case .dark:
            return (
                bg: Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255),
                accent: Color(red: 0x4F/255, green: 0xA8/255, blue: 0xFF/255),
                text: Color.white
            )
        case .muji:
            return (
                bg: IntroDesign.bg,
                accent: IntroDesign.brand,
                text: IntroDesign.ink
            )
        case .purple:
            return (
                bg: Color(red: 0xF3/255, green: 0xEE/255, blue: 0xFA/255),
                accent: Color(red: 0x7C/255, green: 0x5C/255, blue: 0xC8/255),
                text: Color(red: 0x32/255, green: 0x21/255, blue: 0x5C/255)
            )
        }
    }
}

private struct IntroHeroTheme: View {
    let theme: AppTheme
    var body: some View {
        ZStack {
            IntroDesign.brandWash
            HStack(spacing: 16) {
                ForEach(AppTheme.allCases) { t in
                    miniMockup(theme: t, highlighted: t == theme)
                }
            }
            .padding(.horizontal, 24)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func miniMockup(theme: AppTheme, highlighted: Bool) -> some View {
        let p = swatchPalette(theme)
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(p.bg)
                .frame(width: 50, height: 88)
                .overlay(
                    VStack(spacing: 5) {
                        Capsule().fill(p.accent).frame(width: 26, height: 4)
                        Capsule().fill(p.text.opacity(0.5)).frame(width: 32, height: 3)
                        Capsule().fill(p.text.opacity(0.3)).frame(width: 20, height: 3)
                    }
                    .padding(.top, 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(highlighted ? IntroDesign.brand : Color.black.opacity(0.08),
                                lineWidth: highlighted ? 2 : 1)
                )
                .shadow(color: highlighted ? IntroDesign.brand.opacity(0.25) : .clear,
                        radius: 8, x: 0, y: 6)
                .scaleEffect(highlighted ? 1.06 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: highlighted)
        }
    }

    private func swatchPalette(_ theme: AppTheme) -> (bg: Color, accent: Color, text: Color) {
        switch theme {
        case .system:
            return (Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255),
                    Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255),
                    Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255))
        case .light:
            return (.white,
                    Color(red: 0x00/255, green: 0x7A/255, blue: 0xFF/255),
                    Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255))
        case .dark:
            return (Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255),
                    Color(red: 0x4F/255, green: 0xA8/255, blue: 0xFF/255),
                    .white)
        case .muji:
            return (IntroDesign.bg, IntroDesign.brand, IntroDesign.ink)
        case .purple:
            return (Color(red: 0xF3/255, green: 0xEE/255, blue: 0xFA/255),
                    Color(red: 0x7C/255, green: 0x5C/255, blue: 0xC8/255),
                    Color(red: 0x32/255, green: 0x21/255, blue: 0x5C/255))
        }
    }
}

// MARK: - 7. Cards
struct IntroStepCards: View {
    @Binding var cards: [DraftTransitCard]
    let onAdd: () -> Void
    let onEdit: (Int) -> Void
    let onDelete: (Int) -> Void
    let onNext: () -> Void
    let onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroCards().frame(maxWidth: .infinity).frame(height: 200)

            VStack(alignment: .leading, spacing: 6) {
                Text("加入你的票卡")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(IntroDesign.ink)
                    .tracking(-0.3)
                Text("想記哪幾張就記哪幾張；自己取名字、選擇 TPASS 專用或自訂卡片，記帳時就能指定卡別。")
                    .font(.system(size: 13))
                    .foregroundColor(IntroDesign.muted)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { (idx, card) in
                        IntroCardChip(
                            card: card,
                            onEdit: { onEdit(idx) },
                            onDelete: { onDelete(idx) }
                        )
                    }

                    Button(action: onAdd) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text(cards.isEmpty ? "新增第一張卡片" : "再加一張")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(IntroDesign.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                                )
                                .foregroundColor(IntroDesign.brand)
                        )
                    }
                    .buttonStyle(.plain)

                    if cards.isEmpty {
                        Text("之後可在「設定 → 票卡管理」新增或調整。")
                            .font(.system(size: 12))
                            .foregroundColor(IntroDesign.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }

            HStack(alignment: .bottom, spacing: 12) {
                if let onBack = onBack { IntroBackButton(action: onBack) }
                Group {
                    if cards.isEmpty {
                        IntroPrimaryButton(verbatim: "先不綁定，直接開始") { onNext() }
                    } else {
                        IntroPrimaryButton(verbatim: "繼續（已加 \(cards.count) 張）") { onNext() }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: 票卡縮圖 chip（時間軸列表用）
struct IntroCardChip: View {
    let card: DraftTransitCard
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var paletteColor: Color {
        card.type == .tpass ? IntroDesign.brand : IntroDesign.brandDark
    }
    private var paletteTone: Color {
        card.type == .tpass ? Color(red: 0xC9/255, green: 0x9B/255, blue: 0x7C/255)
                            : Color(red: 0x6B/255, green: 0x5C/255, blue: 0x4D/255)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(card.type == .tpass ? "TPASS" : "CUSTOM")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                Text(card.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .accessibilityLabel(Text("編輯"))
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .accessibilityLabel(Text("刪除"))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [paletteColor, paletteTone],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

private struct IntroHeroCards: View {
    @State private var fanned = false
    var body: some View {
        ZStack {
            IntroDesign.brandWash
            ZStack {
                miniCard(color: IntroDesign.brandDark, tone: Color(red: 0x6B/255, green: 0x5C/255, blue: 0x4D/255), rotation: -12, zIndex: 1)
                miniCard(color: IntroDesign.brand, tone: Color(red: 0xC9/255, green: 0x9B/255, blue: 0x7C/255), rotation: 0, zIndex: 2)
                miniCard(color: IntroDesign.success, tone: Color(red: 0x9F/255, green: 0xAE/255, blue: 0x7E/255), rotation: 12, zIndex: 1)
            }
            .offset(y: 6)
        }
        .clipped()
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.05)) {
                fanned = true
            }
        }
    }

    @ViewBuilder
    private func miniCard(color: Color, tone: Color, rotation: Double, zIndex: Double) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [color, tone],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(width: 130, height: 84)
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text("TPASS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.85))
                Text("月票")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundColor(.white)
            }
            .padding(12)
            // 模擬 IC 晶片
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.3))
                .frame(width: 22, height: 14)
                .offset(x: 130 - 14 - 22, y: 84 - 14 - 12)
        }
        .frame(width: 130, height: 84)
        .rotationEffect(.degrees(fanned ? rotation : 0))
        .zIndex(zIndex)
    }
}

// MARK: - 票卡編輯 sheet
//
// 與 IntroStepCards 同層覆蓋，呈現 LIVE 預覽 + 名稱欄 + TPASS/Custom 切換。
// 沒有「用途註記」chip——對應現有 TransitCard 模型只有 name + type。
struct IntroCardEditor: View {
    let initial: DraftTransitCard?
    let onSave: (DraftTransitCard) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var type: TransitCardType
    @FocusState private var nameFocused: Bool

    init(initial: DraftTransitCard?,
         onSave: @escaping (DraftTransitCard) -> Void,
         onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial?.name ?? "")
        _type = State(initialValue: initial?.type ?? .custom)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty }

    private var placeholder: String {
        type == .tpass ? "我的 TPASS 月票" : "例：阿嬤的悠遊卡"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            HStack {
                IntroEyebrow(text: initial == nil ? "NEW CARD" : "EDIT CARD")
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(IntroDesign.ink)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(IntroDesign.card))
                        .overlay(Circle().stroke(IntroDesign.hair, lineWidth: 1))
                }
                .accessibilityLabel(Text("關閉"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(initial == nil ? "新增卡片" : "編輯卡片")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(IntroDesign.ink)
                        .padding(.top, 4)

                    livePreview

                    fieldGroup(title: "卡片名稱") {
                        TextField(placeholder, text: $name)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 20 {
                                    name = String(newValue.prefix(20))
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12).fill(IntroDesign.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(IntroDesign.hair, lineWidth: 1)
                            )
                            .font(.system(size: 15))
                            .foregroundColor(IntroDesign.ink)
                    }

                    fieldGroup(title: "使用類別") {
                        HStack(spacing: 8) {
                            kindOption(
                                kind: .tpass,
                                title: "TPASS 專用卡",
                                sub: "綁定月票方案的主卡",
                                color: IntroDesign.brand,
                                tone: Color(red: 0xC9/255, green: 0x9B/255, blue: 0x7C/255)
                            )
                            kindOption(
                                kind: .custom,
                                title: "自訂卡片",
                                sub: "其他悠遊卡、加值卡、家人卡…",
                                color: IntroDesign.brandDark,
                                tone: Color(red: 0x6B/255, green: 0x5C/255, blue: 0x4D/255)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            // 底部 CTA
            VStack(spacing: 6) {
                IntroPrimaryButton(
                    verbatim: initial == nil ? "加入卡片" : "儲存修改",
                    disabled: !canSave
                ) {
                    let card = DraftTransitCard(name: trimmed, type: type)
                    onSave(card)
                }
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(IntroDesign.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                nameFocused = true
            }
        }
    }

    @ViewBuilder
    private func fieldGroup<Inner: View>(title: String,
                                         @ViewBuilder content: () -> Inner) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundColor(IntroDesign.muted)
                .padding(.leading, 2)
            content()
        }
    }

    @ViewBuilder
    private func kindOption(kind: TransitCardType,
                            title: String,
                            sub: String,
                            color: Color,
                            tone: Color) -> some View {
        let selected = type == kind
        Button {
            HapticManager.shared.impact(style: .light)
            type = kind
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [color, tone],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(width: 28, height: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(IntroDesign.ink)
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(IntroDesign.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? IntroDesign.brandWash : IntroDesign.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? IntroDesign.brand : IntroDesign.hair,
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var livePreview: some View {
        let color = (type == .tpass) ? IntroDesign.brand : IntroDesign.brandDark
        let tone: Color = (type == .tpass)
            ? Color(red: 0xC9/255, green: 0x9B/255, blue: 0x7C/255)
            : Color(red: 0x6B/255, green: 0x5C/255, blue: 0x4D/255)
        let displayName = trimmed.isEmpty ? placeholder : trimmed
        let suffix = mockCardSuffix(displayName)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [color, tone],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(height: 124)
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(type == .tpass ? "TPASS" : "CUSTOM")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }
                Text(displayName)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(16)

            VStack { Spacer(); HStack {
                Text("**** \(suffix)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 32, height: 22)
            }.padding(16) }
        }
    }

    private func mockCardSuffix(_ source: String) -> String {
        let sum = source.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let suffix = 1000 + (abs(sum) % 9000)
        return String(format: "%04d", suffix)
    }
}

// MARK: - 8. Done
struct IntroStepDone: View {
    let selectedIdentity: Identity
    let selectedRegion: TPASSRegion
    let cycleStartDate: Date
    let cycleEndDate: Date
    let selectedCitizenCity: TaiwanCity?
    let notificationOptIn: Bool?
    let selectedTheme: AppTheme
    let cards: [DraftTransitCard]
    let onStart: () -> Void
    let onBack: (() -> Void)?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            IntroHeroDone().frame(maxWidth: .infinity).frame(height: 200)

            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        IntroEyebrow(text: "ALL SET")
                        Text("準備好了，開始記帳吧")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundColor(IntroDesign.ink)
                            .multilineTextAlignment(.center)
                        Text("所有設定都儲存在你的裝置上，可隨時到設定調整。")
                            .font(.system(size: 13))
                            .foregroundColor(IntroDesign.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 4)

                    // Summary 卡片
                    VStack(spacing: 0) {
                        summaryRow(label: "intro_summary_identity",
                                   value: Text(selectedIdentity.label))
                        Divider().background(IntroDesign.hair).padding(.horizontal, 16)
                        summaryRow(label: "intro_summary_plan",
                                   value: Text(selectedRegion.displayNameKey))
                        Divider().background(IntroDesign.hair).padding(.horizontal, 16)
                        summaryRow(
                            label: "intro_summary_dates",
                            value: Text("\(Self.dateFormatter.string(from: cycleStartDate)) → \(Self.dateFormatter.string(from: cycleEndDate))")
                        )
                        Divider().background(IntroDesign.hair).padding(.horizontal, 16)
                        summaryRow(label: "intro_summary_citizen",
                                   value: Text(selectedCitizenCity?.displayName ?? "citizen_city_all"))
                        Divider().background(IntroDesign.hair).padding(.horizontal, 16)
                        summaryRow(
                            label: LocalizedStringKey("通知"),
                            value: Text(notificationOptIn == true ? "已開啟" : "已略過")
                        )
                        Divider().background(IntroDesign.hair).padding(.horizontal, 16)
                        summaryRow(
                            label: LocalizedStringKey("主題"),
                            value: Text(selectedTheme.localizedDisplayName)
                        )
                        Divider().background(IntroDesign.hair).padding(.horizontal, 16)
                        summaryRow(
                            label: LocalizedStringKey("票卡"),
                            value: Text(cards.isEmpty ? "未綁定" : "\(cards.count) 張")
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16).fill(IntroDesign.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16).stroke(IntroDesign.hair, lineWidth: 1)
                    )

                    if cards.isEmpty {
                        emptyCardHint
                    } else {
                        cardsStrip
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)
            }

            IntroStepFooter {
                HStack(spacing: 12) {
                    if let onBack = onBack { IntroBackButton(action: onBack) }
                    IntroPrimaryButton(title: "intro_start_button") { onStart() }
                }
            }
        }
    }

    private func summaryRow(label: LocalizedStringKey, value: Text) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(IntroDesign.muted)
            Spacer()
            value
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(IntroDesign.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyCardHint: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(IntroDesign.brandSoft)
                    .frame(width: 32, height: 32)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(IntroDesign.brand)
            }
            Text("還沒綁定卡片。之後可在「設定 → 票卡管理」隨時加入。")
                .font(.system(size: 12))
                .foregroundColor(IntroDesign.inkSoft)
                .lineSpacing(2)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(IntroDesign.bgWarm))
    }

    private var cardsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已加入的卡片")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundColor(IntroDesign.muted)
                .padding(.leading, 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cards) { c in
                        miniCardPreview(c)
                    }
                }
            }
        }
    }

    private func miniCardPreview(_ card: DraftTransitCard) -> some View {
        let color = card.type == .tpass ? IntroDesign.brand : IntroDesign.brandDark
        let tone: Color = card.type == .tpass
            ? Color(red: 0xC9/255, green: 0x9B/255, blue: 0x7C/255)
            : Color(red: 0x6B/255, green: 0x5C/255, blue: 0x4D/255)
        return VStack(alignment: .leading, spacing: 6) {
            Text(card.type == .tpass ? "TPASS" : "CUSTOM")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.2)))
            Spacer()
            Text(card.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(width: 150, height: 86, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [color, tone],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
        )
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}

private struct IntroHeroDone: View {
    @State private var pop = false
    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [IntroDesign.brandWash, IntroDesign.bg]),
                center: UnitPoint(x: 0.5, y: 1),
                startRadius: 10, endRadius: 240
            )

            // 太陽光 rays
            TimelineView(.animation) { ctx in
                let degrees = (ctx.date.timeIntervalSinceReferenceDate / 40) * 360
                ZStack {
                    ForEach(0..<12, id: \.self) { i in
                        Capsule()
                            .fill(IntroDesign.brand.opacity(0.22))
                            .frame(width: 2, height: 40)
                            .offset(y: -58)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                }
                .rotationEffect(.degrees(degrees))
            }

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(IntroDesign.brand)
                    .frame(width: 84, height: 84)
                    .shadow(color: IntroDesign.brand.opacity(0.38),
                            radius: 18, x: 0, y: 14)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundColor(.white)
            }
            .scaleEffect(pop ? 1 : 0)
            .opacity(pop ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.1)) {
                    pop = true
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - 待消費的暫存票卡讀取輔助
//
// 提供給 MainTabView / AppViewModel 在登入後呼叫，將 IntroView 在 onboarding
// 期間蒐集到的票卡寫入 SwiftData，並清除 UserDefaults 暫存區。
//
// 範例（建議放在 AppViewModel.start 內）：
// ```swift
// for draft in PendingIntroCards.load() {
//     let new = TransitCard(id: draft.id, name: draft.name, type: draft.type)
//     modelContext.insert(new)
// }
// PendingIntroCards.clear()
// ```
enum PendingIntroCards {
    static func load() -> [DraftTransitCard] {
        guard let data = UserDefaults.standard.data(forKey: IntroDesign.pendingCardsKey),
              let cards = try? JSONDecoder().decode([DraftTransitCard].self, from: data)
        else { return [] }
        return cards
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: IntroDesign.pendingCardsKey)
    }
}
