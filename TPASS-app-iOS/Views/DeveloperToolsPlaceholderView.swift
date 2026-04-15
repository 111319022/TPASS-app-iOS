import SwiftUI

struct DeveloperToolsPlaceholderView: View {
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            Rectangle()
                .fill(themeManager.backgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "hammer.circle")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(themeManager.accentColor)

                Text("開發者頁面")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("此頁面預留中")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("開發者")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        DeveloperToolsPlaceholderView()
    }
}
