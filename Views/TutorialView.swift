import SwiftUI

// MARK: - 教學頁面
struct TutorialView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        ZStack {
            // 背景色
            Rectangle()
                .fill(themeManager.backgroundColor)
                .ignoresSafeArea()
            
            // 教學內容區域
            ScrollView {
                VStack(spacing: 20) {
                    // 教學標題
                    Text(localizationManager.localized("tutorial_trip_history_title"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.primaryTextColor)
                        .padding(.top, 20)
                    
                    // 教學截圖區域
                    VStack(spacing: 30) {
                        // 第一張教學圖
                        tutorialImageCard(imageName: "tutorial_1", title: localizationManager.localized("tutorial_card_add_data"))
                        
                        // 第二張教學圖
                        tutorialImageCard(imageName: "tutorial_2", title: localizationManager.localized("tutorial_card_more_features"))
                        
                        // 第三張教學圖
                        tutorialImageCard(imageName: "tutorial_3", title: localizationManager.localized("tutorial_card_quick_delete"))
                        
                        // 第四張教學圖
                        tutorialImageCard(imageName: "tutorial_4", title: localizationManager.localized("tutorial_card_quick_add"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle(localizationManager.localized("tutorial"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 教學圖片卡片組件
    @ViewBuilder
    func tutorialImageCard(imageName: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.primaryTextColor)
            
            // 圖片容器
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 400)
                
                // 如果圖片存在就顯示，否則顯示佔位符
                if let image = UIImage(named: imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        Text(localizationManager.localizedFormat("tutorial_upload_image", imageName))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

#Preview {
    NavigationView {
        TutorialView()
    }
}
