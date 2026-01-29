import SwiftUI

struct IntroView: View {
    @EnvironmentObject var auth: AuthService
    @State private var currentTab = 0
    @State private var selectedIdentity: Identity = .adult
    
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
                    // Page 1: 歡迎頁
                    WelcomeCard()
                        .tag(0)
                    
                    // Page 2~5: 功能介紹
                    FeatureCard(icon: "bus.fill", color: Color(hex: "#d97761"), title: "通勤，也要精打細算", desc: "專為基北北桃通勤族打造。\n1200 買下去，到底有沒有回本？\n讓我們幫你算清楚。").tag(1)
                    FeatureCard(icon: "function", color: Color(hex: "#2ecc71"), title: "智慧轉乘與優惠", desc: "自動扣除轉乘優惠 ($8/$6)。\n支援「常客優惠」階梯回饋\n與「TPASS 2.0」運具補貼計算。").tag(2)
                    FeatureCard(icon: "calendar", color: Color(hex: "#f39c12"), title: "彈性週期設定", desc: "不限於每月 1 號！\n自訂月票啟用日，\n自動計算 30 天效期內的每一筆回饋。").tag(3)
                    FeatureCard(icon: "chart.xyaxis.line", color: Color(hex: "#e17055"), title: "深度數據儀表板", desc: "全新推出「通勤熱力圖」與「回本競速」。\n視覺化分析您的平日/假日貢獻，\n與每一筆支出的詳細結構。").tag(4)
                    
                    // Page 6: 身分選擇後開始使用
                    StartCard(selectedIdentity: $selectedIdentity)
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
                    .opacity(currentTab == 0 ? 0 : 1).disabled(currentTab == 0).foregroundColor(Color(hex: "#2c3e50"))
                    
                    Spacer()
                    // 點點
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule().fill(currentTab == index ? Color(hex: "#d97761") : Color.gray.opacity(0.3)).frame(width: currentTab == index ? 20 : 6, height: 6).animation(.spring(), value: currentTab)
                        }
                    }
                    Spacer()
                    
                    // 下一步 (最後一頁隱藏)
                    Button { withAnimation { currentTab = min(totalPages - 1, currentTab + 1) } } label: {
                        Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).frame(width: 45, height: 45).background(Color.white).clipShape(Circle()).shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
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
                Text("歡迎來到\nTPASS回本計算機")
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
                
                Spacer()
                
                HStack {
                    Text("滑動查看更多")
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

// MARK: - 身分選擇與開始卡片
struct StartCard: View {
    @EnvironmentObject var auth: AuthService
    @Binding var selectedIdentity: Identity
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                // 頂部圖示
                ZStack {
                    Circle().fill(Color(hex: "#2c3e50")).frame(width: 70, height: 70)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundColor(.white)
                }
                
                Text("開始使用")
                    .font(.title2).fontWeight(.bold).foregroundColor(Color(hex: "#2c3e50"))
                
                Text("請選擇您的票種身分\n這將影響轉乘優惠的計算")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundColor(.gray)
                
                // 身分選擇
                HStack(spacing: 12) {
                    IdentityOption(type: .adult, isSelected: selectedIdentity == .adult, icon: "person.fill", title: "全票 (成人)", subtitle: "轉乘折 $8") { selectedIdentity = .adult }
                    IdentityOption(type: .student, isSelected: selectedIdentity == .student, icon: "graduationcap.fill", title: "學生票", subtitle: "轉乘折 $6") { selectedIdentity = .student }
                }
                .frame(height: 100)
                
                Spacer().frame(height: 20)
                
                // 開始使用按鈕
                Button {
                    // 創建匿名用戶並設定身分
                    auth.createAnonymousUser(identity: selectedIdentity)
                } label: {
                    Text("開始使用")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#d97761"))
                        .cornerRadius(12)
                        .shadow(color: Color(hex: "#d97761").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Text("資料將儲存在您的裝置上")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.95))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 8)
        }
        .padding(25)
    }
}

// MARK: - 其他輔助視圖 (FeatureCard & IdentityOption)
struct FeatureCard: View {
    let icon: String; let color: Color; let title: String; let desc: String
    var body: some View {
        VStack {
            VStack {
                ZStack {
                    Circle().fill(color).frame(width: 80, height: 80).shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    Image(systemName: icon).font(.system(size: 32)).foregroundColor(.white)
                }
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
    let type: Identity; let isSelected: Bool; let icon: String; let title: String; let subtitle: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.system(size: 14, weight: .bold))
                Text(subtitle).font(.caption).opacity(0.8)
            }
            .foregroundColor(isSelected ? Color(hex: "#d97761") : .gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? Color(hex: "#eaf2fa") : .clear)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color(hex: "#d97761") : Color.gray.opacity(0.3), lineWidth: 2))
        }
    }
}
