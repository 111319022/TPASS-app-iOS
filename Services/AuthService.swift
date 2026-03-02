import Foundation
import Combine

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User? = nil
    @Published var isRestoringSession: Bool = true
    @Published var currentRegion: TPASSRegion = .north
    var isSignedIn: Bool { currentUser != nil }

    override private init() {
        super.init()
        loadLocalUser()
        loadCurrentRegion()
    }
    
    // MARK: - 本地用戶管理
    func loadLocalUser() {
        print("🔐 [Auth] Restoring local session...")
        isRestoringSession = true
        defer { isRestoringSession = false }

        guard let data = UserDefaults.standard.data(forKey: "local_user") else {
            currentUser = nil
            return
        }

        guard let user = try? JSONDecoder().decode(User.self, from: data) else {
            currentUser = nil
            return
        }

        currentUser = user
        print("🔐 [Auth] Local session restored: signedIn=\(isSignedIn)")
    }
    
    func saveLocalUser() {
        if let user = currentUser,
           let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "local_user")
        }
    }
    
    func createAnonymousUser(identity: Identity) {
        let calendar = Calendar.current
        let now = Date()
        
        // 自動創建當月的彈性週期（從1號到月底）
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            // 如果日期計算失敗，創建不含週期的用戶
            let user = User(
                id: UUID().uuidString,
                email: "",
                cycles: [],
                identity: identity
            )
            currentUser = user
            saveLocalUser()
            isRestoringSession = false
            return
        }
        
        let idVal = Int64(Date().timeIntervalSince1970 * 1000)
        let startAtMidnight = calendar.startOfDay(for: startOfMonth)
        let endAtMidnight = calendar.startOfDay(for: endOfMonth)
        
        let initialCycle = Cycle(
            id: String(idVal),
            start: startAtMidnight,
            end: endAtMidnight,
            region: .flexible
        )
        
        let user = User(
            id: UUID().uuidString,
            email: "",
            cycles: [initialCycle],
            identity: identity
        )
        currentUser = user
        saveLocalUser()
        isRestoringSession = false
        
        print("🎉 [Auth] Created first-time user with flexible cycle: \(startOfMonth.formatted(date: .abbreviated, time: .omitted)) - \(endOfMonth.formatted(date: .abbreviated, time: .omitted))")
    }
    
    // MARK: - 用戶設定更新（本地保存）
    
    func updateIdentity(_ identity: Identity) {
        guard var user = currentUser else { return }
        user.identity = identity
        currentUser = user
        saveLocalUser()
    }
    
    func updateCitizenCity(_ city: TaiwanCity?) {
        guard var user = currentUser else { return }
        user.citizenCity = city
        currentUser = user
        saveLocalUser()
    }
    
    // MARK: - 回家站點管理
    
    func addHomeStation(name: String, transportType: TransportType, lineCode: String? = nil) {
        guard var user = currentUser else { return }
        let newStation = HomeStation(name: name, transportType: transportType, lineCode: lineCode)
        user.homeStations.append(newStation)
        currentUser = user
        saveLocalUser()
    }
    
    func deleteHomeStation(_ station: HomeStation) {
        guard var user = currentUser else { return }
        user.homeStations.removeAll { $0.id == station.id }
        currentUser = user
        saveLocalUser()
    }
    
    func updateHomeStation(_ station: HomeStation, name: String, transportType: TransportType, lineCode: String? = nil) {
        guard var user = currentUser else { return }
        if let index = user.homeStations.firstIndex(where: { $0.id == station.id }) {
            user.homeStations[index].name = name
            user.homeStations[index].transportType = transportType
            user.homeStations[index].lineCode = lineCode
            currentUser = user
            saveLocalUser()
        }
    }
    
    func addCycle(start: Date, end: Date, region: TPASSRegion = .north) {
        guard var user = currentUser else { return }
        
        let idVal = Int64(Date().timeIntervalSince1970 * 1000)
        
        // 🔧 確保日期是午夜時間
        let calendar = Calendar.current
        let startAtMidnight = calendar.startOfDay(for: start)
        let endAtMidnight = calendar.startOfDay(for: end)
        
        let newCycle = Cycle(id: String(idVal), start: startAtMidnight, end: endAtMidnight, region: region)
        
        user.cycles.insert(newCycle, at: 0)
        currentUser = user
        saveLocalUser()
    }
    
    func deleteCycle(_ cycle: Cycle) {
        guard var user = currentUser else { return }
        user.cycles.removeAll { $0.id == cycle.id }
        currentUser = user
        saveLocalUser()
    }
    
    func updateCycle(_ cycle: Cycle, start: Date, end: Date, region: TPASSRegion) {
        guard var user = currentUser else { return }
        if let index = user.cycles.firstIndex(where: { $0.id == cycle.id }) {
            // 🔧 確保日期是午夜時間
            let calendar = Calendar.current
            let startAtMidnight = calendar.startOfDay(for: start)
            let endAtMidnight = calendar.startOfDay(for: end)
            
            user.cycles[index].start = startAtMidnight
            user.cycles[index].end = endAtMidnight
            user.cycles[index].region = region
            currentUser = user
            saveLocalUser()
        }
    }
    
    // MARK: - 地區設定
    
    private func loadCurrentRegion() {
        if let regionRawValue = UserDefaults.standard.string(forKey: "current_region"),
           let region = TPASSRegion(rawValue: regionRawValue) {
            currentRegion = region
        } else {
            currentRegion = .north
        }
    }
    
    func updateRegion(_ region: TPASSRegion) {
        currentRegion = region
        UserDefaults.standard.set(region.rawValue, forKey: "current_region")
        print("🌍 [Auth] Region updated to: \(region.displayName)")
    }
}
