import SwiftUI
import SwiftData

struct SwiftDataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Trip.createdAt, order: .reverse)]) private var trips: [Trip]
    @Query(sort: [SortDescriptor(\FavoriteRoute.id, order: .forward)]) private var favorites: [FavoriteRoute]
    @Query(sort: [SortDescriptor(\CommuterRoute.name, order: .forward)]) private var commuterRoutes: [CommuterRoute]
    @Query(sort: [SortDescriptor(\UserSettingsModel.userId, order: .forward)]) private var userSettings: [UserSettingsModel]

    @StateObject private var themeManager = ThemeManager.shared

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        List {
            Section("Trip") {
                if trips.isEmpty {
                    emptyRow
                } else {
                    ForEach(trips, id: \.id) { trip in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(trip.type.rawValue) | \(trip.originalPrice) -> \(trip.paidPrice)")
                                .font(.headline)
                            Text("\(trip.startStation) -> \(trip.endStation)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("id: \(trip.id)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("createdAt: \(Self.dateTimeFormatter.string(from: trip.createdAt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteTrip(trip)
                            }
                        }
                    }
                }
            }

            Section("FavoriteRoute") {
                if favorites.isEmpty {
                    emptyRow
                } else {
                    ForEach(favorites, id: \.id) { favorite in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(favorite.type.rawValue) | \(favorite.price)")
                                .font(.headline)
                            Text("\(favorite.startStation) -> \(favorite.endStation)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !favorite.routeId.isEmpty {
                                Text("routeId: \(favorite.routeId)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("id: \(favorite.id.uuidString)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteFavorite(favorite)
                            }
                        }
                    }
                }
            }

            Section("CommuterRoute") {
                if commuterRoutes.isEmpty {
                    emptyRow
                } else {
                    ForEach(commuterRoutes, id: \.id) { route in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(route.name)
                                .font(.headline)
                            Text("templates: \(route.trips.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("id: \(route.id.uuidString)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteCommuterRoute(route)
                            }
                        }
                    }
                }
            }

            Section("UserSettingsModel") {
                if userSettings.isEmpty {
                    emptyRow
                } else {
                    ForEach(userSettings, id: \.userId) { setting in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("userId: \(setting.userId)")
                                .font(.headline)
                            Text("identity: \(setting.identity)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("cloudSync: \(setting.isCloudSyncEnabled ? "on" : "off")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            Button("刪除", role: .destructive) {
                                deleteUserSetting(setting)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("SwiftData 資料管理")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(themeManager.backgroundColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }

    private var emptyRow: some View {
        Text("無資料")
            .foregroundStyle(.secondary)
    }

    private func deleteTrip(_ trip: Trip) {
        modelContext.delete(trip)
    }

    private func deleteFavorite(_ favorite: FavoriteRoute) {
        modelContext.delete(favorite)
    }

    private func deleteCommuterRoute(_ route: CommuterRoute) {
        modelContext.delete(route)
    }

    private func deleteUserSetting(_ setting: UserSettingsModel) {
        modelContext.delete(setting)
    }
}

#Preview {
    NavigationStack {
        SwiftDataManagementView()
    }
}