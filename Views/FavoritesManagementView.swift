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
    @State private var toastMessage = ""
    @State private var swipedFavIds: Set<UUID> = []
    @State private var swipedCommuterIds: Set<UUID> = []
    
    private var screenBackground: Color {
        switch themeManager.currentTheme {
        case .muji:
            return Color(hex: "#f5f0eb")
        case .light:
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
        case .muji, .light:
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
                        Text("尚無常用或通勤路線")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        Text("長按行程可加入常用或通勤路線，方便快速新增")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        if !viewModel.favorites.isEmpty {
                            Section(header: sectionHeader("常用路線")) {
                                ForEach(viewModel.favorites) { fav in
                                    Button(action: {
                                        let routeName = fav.displayTitle
                                        viewModel.quickAddTrip(from: fav)
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            onQuickAdd?(routeName)
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            // 圖示
                                            ZStack {
                                                Circle()
                                                    .fill(themeManager.transportColor(fav.type).opacity(0.15))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: fav.type.systemIconName)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(themeManager.transportColor(fav.type))
                                            }
                                            
                                            // 路線資訊
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(fav.displayTitle)
                                                    .font(.system(.body, design: .default))
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(themeManager.primaryTextColor)
                                                
                                                HStack(spacing: 8) {
                                                    Text("$\(fav.price)")
                                                        .font(.caption)
                                                        .foregroundColor(themeManager.secondaryTextColor)
                                                    
                                                    if fav.isFree {
                                                        Text("免費")
                                                            .font(.caption)
                                                            .fontWeight(.semibold)
                                                            .foregroundColor(.green)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.green.opacity(0.15))
                                                            .cornerRadius(4)
                                                    }
                                                    
                                                    if fav.isTransfer {
                                                        Text("轉乘")
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
                                            
                                            // 快速新增按鈕
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
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.removeFavorite(fav)
                                            swipedFavIds.remove(fav.id)
                                        } label: {
                                            Label("刪除", systemImage: "trash.fill")
                                        }
                                    }
                                    // 長按刪除
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.removeFavorite(fav)
                                            swipedFavIds.remove(fav.id)
                                        } label: {
                                            Label("刪除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } else {
                            Section(header: sectionHeader("常用路線")) {
                                Text("長按行程以選擇新增至「常用路線」")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                                    .listRowBackground(themeManager.cardBackgroundColor)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        
                        if !viewModel.commuterRoutes.isEmpty {
                            Section(header: sectionHeader("通勤路線")) {
                                ForEach(viewModel.commuterRoutes) { route in
                                    Button(action: {
                                        let routeName = route.name
                                        viewModel.quickAddCommuterRoute(route)
                                        showToast(message: "已新增通勤：\(routeName)")
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
                                                Text("\(route.tripCount) 筆")
                                                    .font(.caption)
                                                    .foregroundColor(themeManager.secondaryTextColor)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "square.and.pencil")
                                                .font(.system(size: 20))
                                                .foregroundColor(themeManager.secondaryTextColor)
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
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.removeCommuterRoute(route)
                                            swipedCommuterIds.remove(route.id)
                                        } label: {
                                            Label("刪除", systemImage: "trash.fill")
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            editingCommuterRoute = route
                                        } label: {
                                            Label("編輯", systemImage: "square.and.pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            viewModel.removeCommuterRoute(route)
                                            swipedCommuterIds.remove(route.id)
                                        } label: {
                                            Label("刪除通勤路線", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } else {
                            Section(header: sectionHeader("通勤路線")) {
                                Text("長按行程以選擇新增至「通勤路線」")
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
            .navigationTitle("常用路線")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
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
    
    private func showToast(message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundColor(themeManager.secondaryTextColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }
}

struct CommuterRouteDetailView: View {
    @EnvironmentObject var viewModel: AppViewModel
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
        case .light:
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.displayTitle)
                                        .font(.system(.body, design: .default))
                                        .fontWeight(.semibold)
                                        .foregroundColor(themeManager.primaryTextColor)
                                    Text(trip.timeString)
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                                
                                Spacer()
                                
                                Text("$\(trip.price)")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryTextColor)
                            }
                            .padding(.vertical, 4)
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
                                    Label("刪除", systemImage: "trash")
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
                        Text("此通勤路線尚無項目")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(route?.name ?? "通勤路線")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.system(.body, design: .default))
                    .foregroundColor(themeManager.accentColor)
                }
            }
        }
    }
}
