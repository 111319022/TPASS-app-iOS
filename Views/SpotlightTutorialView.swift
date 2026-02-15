import SwiftUI

// 定義聚光燈教學步驟
enum SpotlightTutorialStep: Int, CaseIterable {
    case welcome = 0           // 歡迎畫面
    case cycleSelector = 1     // 週期選擇
    case addButton = 2         // 新增按鈕
    case swipeActions = 3      // 左滑右滑編輯/刪除
    case longPressCommuter = 4 // 長按設定通勤路線
    case favoritesButton = 5   // 右上角星星按鈕（結束 Trip 頁面教學）
    case finish = 6            // 完成
}

// 用來傳遞關鍵位置信息
struct TutorialPositions {
    var addButtonFrame: CGRect = .zero
    var cycleSelectorFrame: CGRect = .zero
    var tripRowFrame: CGRect = .zero
    var favoritesButtonFrame: CGRect = .zero
    var dashboardTabFrame: CGRect = .zero
    var settingsTabFrame: CGRect = .zero
    var cycleButtonFrame: CGRect = .zero
}

struct SpotlightTutorialOverlay: View {
    @Binding var currentStep: SpotlightTutorialStep
    var onFinish: () -> Void
    var positions: TutorialPositions = TutorialPositions()
    @EnvironmentObject var themeManager: ThemeManager
    
    // 取得螢幕尺寸以計算位置
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        GeometryReader { proxy in
            let safeAreaTop = proxy.safeAreaInsets.top
            let backgroundColor = themeManager.currentTheme == .dark
                ? Color.black.opacity(0.90)
                : Color.black.opacity(0.75)
            
            ZStack {
                // 1. 半透明背景 (根據主題深淺調整)
                backgroundColor
                    .mask(
                        ZStack {
                            Rectangle().fill(Color.white) // 滿版白色 (代表不透明)
                            
                            // 這裡定義「挖洞」的區域 (黑色代表透明)
                            spotlightShape(safeAreaTop: safeAreaTop)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
                    .ignoresSafeArea()
                    .onTapGesture {
                        nextStep()
                    }
                
                // 2. 文字說明與引導 - 置中顯示
                VStack {
                    Spacer(minLength: 0)
                    
                    VStack(spacing: 12) {
                        Text(titleForStep)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(descriptionForStep)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                        
                        Button(action: nextStep) {
                            Text(currentStep == .finish ? "tutorial_start" : "tutorial_next")
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.white)
                                .cornerRadius(18)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.55))
                    )
                    .padding(.horizontal, 16)
                    .offset(y: textBoxOffset)
                    
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 16)
            }
        }
    }
    
    // 定義每個步驟的「挖洞」形狀與位置
    @ViewBuilder
    func spotlightShape(safeAreaTop: CGFloat) -> some View {
        switch currentStep {
        case .welcome, .finish:
            // 歡迎畫面不需要聚光燈
            EmptyView()
            
        case .cycleSelector:
            // 週期選擇器 (上方)
            if positions.cycleSelectorFrame != .zero {
                RoundedRectangle(cornerRadius: 14)
                    .frame(
                        width: min(positions.cycleSelectorFrame.width + 24, screenWidth - 32),
                        height: positions.cycleSelectorFrame.height + 16
                    )
                    .position(
                        x: positions.cycleSelectorFrame.midX,
                        y: positions.cycleSelectorFrame.midY
                    )
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .frame(width: screenWidth - 40, height: 60)
                    .position(x: screenWidth / 2, y: safeAreaTop + 100)
            }
            
        case .addButton:
            // 右下角新增按鈕
            if positions.addButtonFrame != .zero {
                RoundedRectangle(cornerRadius: 22)
                    .frame(
                        // 寬高稍微加大一點點，讓聚光燈不要切得太剛好，留點呼吸空間
                        width: positions.addButtonFrame.width + 10,
                        height: positions.addButtonFrame.height + 10
                    )
                    .position(
                        // 直接使用抓到的中心點座標，不需要再猜測 -16 了
                        x: positions.addButtonFrame.midX,
                        y: positions.addButtonFrame.midY
                    )
            } else {
                // (備案) 如果沒抓到座標，才使用原本的猜測邏輯
                RoundedRectangle(cornerRadius: 22)
                    .frame(width: 140, height: 90)
                    .position(x: screenWidth - 70, y: screenHeight - 160)
            }
            
        case .swipeActions:
            // 列表項目 (中間)
            if positions.tripRowFrame != .zero {
                RoundedRectangle(cornerRadius: 12)
                    .frame(
                        width: min(positions.tripRowFrame.width + 20, screenWidth - 32),
                        height: min(positions.tripRowFrame.height + 16, 100)
                    )
                    .position(
                        x: positions.tripRowFrame.midX,
                        y: min(positions.tripRowFrame.midY, screenHeight * 0.58)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .frame(width: screenWidth - 40, height: 90)
                    .position(x: screenWidth / 2, y: screenHeight * 0.45)
            }
            
        case .longPressCommuter:
            // 同樣是列表項目 (中間)
            if positions.tripRowFrame != .zero {
                RoundedRectangle(cornerRadius: 12)
                    .frame(
                        width: min(positions.tripRowFrame.width + 20, screenWidth - 32),
                        height: min(positions.tripRowFrame.height + 16, 100)
                    )
                    .position(
                        x: positions.tripRowFrame.midX,
                        y: min(positions.tripRowFrame.midY, screenHeight * 0.58)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .frame(width: screenWidth - 40, height: 90)
                    .position(x: screenWidth / 2, y: screenHeight * 0.45)
            }
            
        case .favoritesButton:
            // 右上角星星按鈕
            if positions.favoritesButtonFrame != .zero {
                Circle()
                    .frame(width: 40, height: 40)
                    .position(
                        x: positions.favoritesButtonFrame.midX,
                        y: positions.favoritesButtonFrame.midY
                    )
            } else {
                Circle()
                    .frame(width: 40, height: 40)
                    .position(x: screenWidth - 50, y: safeAreaTop + 50)
            }
        }
    }
    
    var titleForStep: LocalizedStringKey {
        switch currentStep {
        case .welcome:
            return "tutorial_welcome_title"
        case .cycleSelector:
            return "tutorial_cycle_title"
        case .addButton:
            return "tutorial_addButton_title"
        case .swipeActions:
            return "tutorial_swipe_title"
        case .longPressCommuter:
            return "tutorial_longPress_title"
        case .favoritesButton:
            return "tutorial_favorites_title"
        case .finish:
            return "tutorial_trips_finish_title"
        }
    }
    
    var descriptionForStep: LocalizedStringKey {
        switch currentStep {
        case .welcome:
            return "tutorial_welcome_desc"
        case .cycleSelector:
            return "tutorial_cycle_desc"
        case .addButton:
            return "tutorial_addButton_desc"
        case .swipeActions:
            return "tutorial_swipe_desc"
        case .longPressCommuter:
            return "tutorial_longPress_desc"
        case .favoritesButton:
            return "tutorial_favorites_desc"
        case .finish:
            return "tutorial_trips_finish_desc"
        }
    }
    
    var textBoxOffset: CGFloat {
        switch currentStep {
        case .swipeActions, .longPressCommuter:
            return 120
        case .addButton:
            return -70
        default:
            return 0
        }
    }
    
    func nextStep() {
        if let next = SpotlightTutorialStep(rawValue: currentStep.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = next
            }
        } else {
            onFinish()
        }
    }
}

#Preview {
    @Previewable @State var currentStep: SpotlightTutorialStep = .welcome
    @Previewable @State var positions = TutorialPositions()
    @Previewable @StateObject var themeManager = ThemeManager.shared
    
    return ZStack {
        Color.gray.ignoresSafeArea()
        
        SpotlightTutorialOverlay(currentStep: $currentStep, onFinish: {
            print("Tutorial finished")
        }, positions: positions)
        .environmentObject(themeManager)
    }
}
