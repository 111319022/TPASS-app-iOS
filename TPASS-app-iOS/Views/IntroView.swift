import SwiftUI

struct IntroView: View {
    @EnvironmentObject var auth: AuthService
    @State private var currentTab = 0
    
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
    
    let totalPages = 6
    
    var body: some View {
        ZStack {
            // 背景漸層
            LinearGradient(
                colors: [Color(hex: "#faf9f8"), Color(hex: "#f3ebe3"), Color(hex: "#ede3d9")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            VStack {
                // 滑動卡片區
                TabView(selection: $currentTab) {
                    WelcomeCard()
                        .tag(0)
                    
                    IdentityCard(selectedIdentity: $selectedIdentity)
                        .tag(1)
                    
                    PlanCycleCard(
                        selectedRegion: $selectedRegion,
                        startDate: $cycleStartDate,
                        endDate: $cycleEndDate
                    )
                    .tag(2)
                    
                    CitizenCityCard(selectedCity: $selectedCitizenCity)
                        .tag(3)
                    
                    NotificationCard(notificationRequested: $notificationRequested)
                        .tag(4)
                    
                    SummaryStartCard(
                        selectedIdentity: selectedIdentity,
                        selectedRegion: selectedRegion,
                        cycleStartDate: cycleStartDate,
                        cycleEndDate: cycleEndDate,
                        selectedCitizenCity: selectedCitizenCity
                    )
                    .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentTab)
                
                // 底部控制區
                HStack {
                    // 上一步
                    Button { withAnimation { currentTab = max(0, currentTab - 1) } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).frame(width: 45, height: 45).background(Color.white).clipShape(Circle()).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .accessibilityLabel(Text("a11y_prev_page"))
                    .accessibilityHint(Text("a11y_prev_page_hint"))
                    .opacity(currentTab == 0 ? 0 : 1).disabled(currentTab == 0).foregroundColor(Color(hex: "#2c3e50"))
                    
                    Spacer()
                    // 進度點
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule().fill(currentTab == index ? Color(hex: "#d97761") : Color.gray.opacity(0.3)).frame(width: currentTab == index ? 20 : 6, height: 6).animation(.spring(), value: currentTab)
                        }
                    }
                    .accessibilityHidden(true)
                    Spacer()
                    
                    // 下一步 (最後一頁隱藏)
                    Button { withAnimation { currentTab = min(totalPages - 1, currentTab + 1) } } label: {
                        Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).frame(width: 45, height: 45).background(Color.white).clipShape(Circle()).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .accessibilityLabel(Text("a11y_next_page"))
                    .accessibilityHint(Text("a11y_next_page_hint"))
                    .opacity(currentTab == totalPages - 1 ? 0 : 1).disabled(currentTab == totalPages - 1).foregroundColor(Color(hex: "#2c3e50"))
                }
                .padding(.horizontal, 30).padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 1. 歡迎卡片
struct WelcomeCard: View {
    var body: some View {
        VStack {
            VStack(spacing: 10) {
                Spacer()
                Text("intro_welcome_title")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#2c3e50"))
                
                Text("By Raaay")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#d97761"))
                
                Spacer().frame(height: 20)
                
                Image("icon")
                    .resizable().scaledToFit()
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .accessibilityHidden(true)
                
                Spacer()
                
                HStack {
                    Text("intro_swipe_more")
                    Image(systemName: "arrow.right")
                }
                .font(.caption).foregroundColor(Color(hex: "#7f8c8d")).opacity(0.8)
            }
            .padding(.vertical, 30).padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
    }
}

// MARK: - 2. 身份選擇卡片
struct IdentityCard: View {
    @Binding var selectedIdentity: Identity
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Spacer()
                
                ZStack {
                    Circle().fill(Color(hex: "#d97761")).frame(width: 70, height: 70)
                    Image(systemName: "person.2.fill").font(.system(size: 32)).foregroundColor(.white)
                }
                .accessibilityHidden(true)
                
                Text("intro_identity_title")
                    .font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#2c3e50"))
                
                Text("intro_choose_identity_desc")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundColor(.gray)
                    .padding(.horizontal, 10)
                
                HStack(spacing: 12) {
                    IdentityOption(type: .adult, isSelected: selectedIdentity == .adult, icon: "person.fill", title: "intro_identity_adult_title", subtitle: "intro_identity_transfer_discount \(Identity.adult.transferDiscount)") { selectedIdentity = .adult }
                    IdentityOption(type: .student, isSelected: selectedIdentity == .student, icon: "graduationcap.fill", title: "intro_identity_student_title", subtitle: "intro_identity_transfer_discount \(Identity.student.transferDiscount)") { selectedIdentity = .student }
                }
                .frame(height: 100)
                
                Spacer()
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
    }
}

// MARK: - 3. 方案選擇卡片
struct PlanCycleCard: View {
    @Binding var selectedRegion: TPASSRegion
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    private let regionGroups: [(title: LocalizedStringKey, regions: [TPASSRegion])] = [
        ("intro_plan_group_flexible", [.flexible]),
        ("intro_plan_group_north", [.north, .beiYiMegaPASS, .beiYi]),
        ("intro_plan_group_taoyuan_hsinchu", [.taoZhuZhu, .taoZhuZhuMiao, .zhuZhuMiao]),
        ("intro_plan_group_yilan", [.yilan, .yilan3Days]),
        ("intro_plan_group_central", [.central, .centralCitizen]),
        ("intro_plan_group_south", [.south, .kaohsiung]),
        ("intro_plan_group_tainan", [.tainanNoTRA, .tainanWithTRA, .tainanChiayiTRA, .chiayiTainan])
    ]
    
    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Text("intro_plan_title")
                    .font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#2c3e50"))
                    .padding(.top, 20)
                
                // 方案分組列表
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Array(regionGroups.enumerated()), id: \.offset) { _, group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.title)
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "#7f8c8d"))
                                    .padding(.leading, 4)
                                
                                ForEach(group.regions, id: \.self) { region in
                                    planRow(region)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Divider().padding(.horizontal, 4)
                
                // 日期選擇
                VStack(spacing: 8) {
                    DatePicker("start_date", selection: $startDate, displayedComponents: .date)
                        .font(.subheadline)
                    DatePicker("end_date", selection: $endDate, displayedComponents: .date)
                        .font(.subheadline)
                }
                .environment(\.locale, Locale(identifier: "zh-Hant_TW"))
                .padding(.horizontal, 4)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
        .onChange(of: selectedRegion) { _, newRegion in
            resetDatesForRegion(newRegion)
        }
        .onChange(of: startDate) { _, newStart in
            if selectedRegion != .flexible {
                let cal = Calendar.current
                endDate = cal.date(byAdding: .day, value: 29, to: cal.startOfDay(for: newStart)) ?? newStart
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
            HStack {
                if isFlexible {
                    Image(systemName: "calendar.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white : Color(hex: "#2ecc71"))
                }
                
                Text(region.displayNameKey)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .white : Color(hex: "#2c3e50"))
                
                Spacer()
                
                Text(region.monthlyPrice > 0 ? "$\(region.monthlyPrice)" : String(localized: "intro_plan_price_free"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : Color(hex: "#7f8c8d"))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: "#d97761") : (isFlexible ? Color(hex: "#2ecc71").opacity(0.06) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(hex: "#d97761") : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func resetDatesForRegion(_ region: TPASSRegion) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if region == .flexible {
            // 彈性：當月 1 號到月底
            if let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: today)),
               let lastDay = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay) {
                startDate = firstDay
                endDate = cal.startOfDay(for: lastDay)
            }
        } else {
            // 非彈性：今天起算 30 天（含當日）
            startDate = today
            endDate = cal.date(byAdding: .day, value: 29, to: today) ?? today
        }
    }
}

// MARK: - 4. 市民縣市卡片
struct CitizenCityCard: View {
    @Binding var selectedCity: TaiwanCity?
    
    var body: some View {
        VStack {
            VStack(spacing: 16) {
                Spacer().frame(height: 8)
                
                ZStack {
                    Circle().fill(Color(hex: "#2ecc71")).frame(width: 70, height: 70)
                    Image(systemName: "building.2.fill").font(.system(size: 32)).foregroundColor(.white)
                }
                .accessibilityHidden(true)
                
                Text("intro_citizen_title")
                    .font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#2c3e50"))
                
                Text("intro_citizen_desc")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundColor(.gray)
                    .padding(.horizontal, 10)
                
                ScrollView {
                    VStack(spacing: 6) {
                        // 不設定選項
                        citizenRow(city: nil, isSelected: selectedCity == nil)
                        
                        ForEach(TaiwanCity.allCases) { city in
                            citizenRow(city: city, isSelected: selectedCity == city)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
    }
    
    private func citizenRow(city: TaiwanCity?, isSelected: Bool) -> some View {
        Button {
            HapticManager.shared.impact(style: .light)
            selectedCity = city
        } label: {
            HStack {
                Text(city?.displayName ?? "citizen_city_all")
                    .font(.subheadline)
                    .foregroundColor(isSelected ? Color(hex: "#d97761") : Color(hex: "#2c3e50"))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#d97761"))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: "#d97761").opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(hex: "#d97761") : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 5. 通知權限卡片
struct NotificationCard: View {
    @Binding var notificationRequested: Bool
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Spacer()
                
                ZStack {
                    Circle().fill(Color(hex: "#f39c12")).frame(width: 70, height: 70)
                    Image(systemName: "bell.badge.fill").font(.system(size: 32)).foregroundColor(.white)
                }
                .accessibilityHidden(true)
                
                Text("intro_notification_title")
                    .font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#2c3e50"))
                
                Text("intro_notification_desc")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundColor(.gray)
                    .padding(.horizontal, 10)
                
                Spacer().frame(height: 10)
                
                if NotificationManager.shared.isAuthorized || notificationRequested {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("intro_notification_enabled")
                            .foregroundColor(.green).fontWeight(.semibold)
                    }
                    .padding(.vertical, 10)
                } else {
                    Button {
                        NotificationManager.shared.requestAuthorization()
                        notificationRequested = true
                        UserDefaults.standard.set(true, forKey: "didPromptNotificationPermission")
                    } label: {
                        Text("intro_notification_enable_button")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#f39c12"))
                            .cornerRadius(12)
                            .shadow(color: Color(hex: "#f39c12").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    Button {
                        notificationRequested = true
                        UserDefaults.standard.set(true, forKey: "didPromptNotificationPermission")
                    } label: {
                        Text("intro_notification_skip")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Text("intro_notification_footer")
                    .font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
    }
}

// MARK: - 6. 摘要與開始卡片
struct SummaryStartCard: View {
    @EnvironmentObject var auth: AuthService
    
    let selectedIdentity: Identity
    let selectedRegion: TPASSRegion
    let cycleStartDate: Date
    let cycleEndDate: Date
    let selectedCitizenCity: TaiwanCity?
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Spacer()
                
                ZStack {
                    Circle().fill(Color(hex: "#2c3e50")).frame(width: 70, height: 70)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundColor(.white)
                }
                .accessibilityHidden(true)
                
                Text("intro_summary_title")
                    .font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#2c3e50"))
                
                // 摘要列表
                VStack(spacing: 0) {
                    summaryRow(icon: "person.fill", label: "intro_summary_identity", value: Text(selectedIdentity.label))
                    Divider().padding(.leading, 44)
                    summaryRow(icon: "map.fill", label: "intro_summary_plan", value: Text(selectedRegion.displayNameKey))
                    Divider().padding(.leading, 44)
                    summaryRow(icon: "calendar", label: "intro_summary_dates", value: Text("\(Self.dateFormatter.string(from: cycleStartDate)) ~ \(Self.dateFormatter.string(from: cycleEndDate))"))
                    Divider().padding(.leading, 44)
                    summaryRow(icon: "building.2.fill", label: "intro_summary_citizen", value: Text(selectedCitizenCity?.displayName ?? "citizen_city_all"))
                }
                .background(Color.gray.opacity(0.06))
                .cornerRadius(12)
                
                Spacer().frame(height: 10)
                
                // 開始使用按鈕
                Button {
                    HapticManager.shared.impact(style: .medium)
                    auth.createAnonymousUser(
                        identity: selectedIdentity,
                        region: selectedRegion,
                        citizenCity: selectedCitizenCity,
                        cycleStart: cycleStartDate,
                        cycleEnd: cycleEndDate
                    )
                } label: {
                    Text("intro_start_button")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#d97761"))
                        .cornerRadius(12)
                        .shadow(color: Color(hex: "#d97761").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Text("intro_data_stored_local")
                    .font(.caption).foregroundColor(.gray)
                
                Spacer()
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
    }
    
    private func summaryRow(icon: String, label: LocalizedStringKey, value: some View) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#d97761"))
                .frame(width: 32)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#7f8c8d"))
            
            Spacer()
            
            value
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "#2c3e50"))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - 輔助視圖
struct FeatureCard: View {
    let icon: String; let color: Color; let title: String; let desc: String
    var body: some View {
        VStack {
            VStack {
                ZStack {
                    Circle().fill(color).frame(width: 80, height: 80).shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    Image(systemName: icon).font(.system(size: 32)).foregroundColor(.white)
                }
                .accessibilityHidden(true)
                .padding(.bottom, 20)
                Text(title).font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#2c3e50")).padding(.bottom, 10)
                Text(desc).font(.body).multilineTextAlignment(.center).lineSpacing(6).foregroundColor(Color(hex: "#666666"))
            }
            .padding(30).frame(maxWidth: .infinity).background(Color.white.opacity(0.95)).cornerRadius(24).shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
    }
}

struct IdentityOption: View {
    let type: Identity
    let isSelected: Bool
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.system(size: 14, weight: .bold))
                Text(subtitle).font(.caption).opacity(0.8)
            }
            .accessibilityElement(children: .combine)
            .foregroundColor(isSelected ? Color(hex: "#d97761") : .gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? Color(hex: "#eaf2fa") : .clear)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color(hex: "#d97761") : Color.gray.opacity(0.3), lineWidth: 2))
        }
    }
}
