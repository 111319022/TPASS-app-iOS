import Foundation
import Combine

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
        if let data = UserDefaults.standard.data(forKey: "local_user"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            DispatchQueue.main.async {
                self.currentUser = user
                self.isRestoringSession = false
            }
        } else {
            DispatchQueue.main.async {
                self.isRestoringSession = false
            }
        }
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
        DispatchQueue.main.async {
            self.currentUser = user
            self.saveLocalUser()
        }
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
