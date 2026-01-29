import Foundation
import Combine

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User? = nil
    @Published var isRestoringSession: Bool = true
    var isSignedIn: Bool { currentUser != nil }

    override private init() {
        super.init()
        loadLocalUser()
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
        let user = User(
            id: UUID().uuidString,
            email: "",
            cycles: [],
            identity: identity
        )
        currentUser = user
        saveLocalUser()
        isRestoringSession = false
    }
    
    // MARK: - 用戶設定更新（本地保存）
    
    func updateIdentity(_ identity: Identity) {
        guard var user = currentUser else { return }
        user.identity = identity
        currentUser = user
        saveLocalUser()
    }
    
    func addCycle(start: Date, end: Date) {
        guard var user = currentUser else { return }
        
        let idVal = Int64(Date().timeIntervalSince1970 * 1000)
        let newCycle = Cycle(id: String(idVal), start: start, end: end)
        
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
}
