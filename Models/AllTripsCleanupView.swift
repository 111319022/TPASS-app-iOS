import SwiftUI
import SwiftData

struct AllTripsCleanupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Trip.createdAt, order: .reverse)])
    private var trips: [Trip]

    @EnvironmentObject var appVM: AppViewModel
    @State private var showDeleteAllConfirm = false

    var body: some View {
        List {
            if trips.isEmpty {
                ContentUnavailableView("沒有行程", systemImage: "tram.fill", description: Text("目前沒有可清理的行程"))
            } else {
                ForEach(trips) { trip in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.type.displayName)
                                .font(.headline)
                            Text(dateString(trip.createdAt))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !trip.startStation.isEmpty || !trip.endStation.isEmpty {
                                Text("\(trip.startStation) → \(trip.endStation)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("$\(trip.paidPrice)")
                                .monospacedDigit()
                            if trip.isTransfer {
                                Text("轉乘")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        Button(role: .destructive) {
                            delete(trip)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete(perform: deleteOffsets)
            }
        }
        .navigationTitle("清理行程")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !trips.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAllConfirm = true
                    } label: {
                        Label("全部刪除", systemImage: "trash.slash")
                    }
                }
            }
        }
        .confirmationDialog("確定要刪除所有行程嗎？此操作無法復原。", isPresented: $showDeleteAllConfirm, titleVisibility: .visible) {
            Button("刪除所有行程", role: .destructive) {
                deleteAll()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func delete(_ trip: Trip) {
        // Prefer deleting directly from SwiftData for reliability in cleanup
        modelContext.delete(trip)
        try? modelContext.save()
        // Also update AppViewModel in-memory cache if available
        appVM.trips.removeAll { $0.id == trip.id }
    }

    private func deleteOffsets(at offsets: IndexSet) {
        for index in offsets {
            let trip = trips[index]
            delete(trip)
        }
    }

    private func deleteAll() {
        for trip in trips {
            modelContext.delete(trip)
        }
        try? modelContext.save()
        appVM.clearInMemoryData()
        appVM.fetchAllData()
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        AllTripsCleanupView()
            .environmentObject(AppViewModel())
            .modelContainer(for: Trip.self, inMemory: true)
    }
}
