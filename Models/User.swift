import Foundation

// MARK: - 1. 週期 (Cycle)
struct Cycle: Identifiable, Codable, Hashable {
    var id: String
    var start: Date
    var end: Date
    var displayName: String?

    var title: String {
        if let name = displayName, !name.isEmpty { return name }
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return "\(f.string(from: start)) ~ \(f.string(from: end))"
    }

    enum CodingKeys: String, CodingKey {
        case id, start, end, displayName
    }
    
    // 🔥 [關鍵修正] 讀取邏輯 (Decoding)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. 🔥 ID 容錯：如果是數字 (Web版舊資料)，就轉成字串；如果是字串就直接讀
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idInt = try? container.decode(Int64.self, forKey: .id) {
            id = String(idInt) // 把數字轉成字串
        } else {
            id = UUID().uuidString // 真的讀不到就給隨機 ID
        }
        
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        
        // 2. Start 時間容錯：支援 數字(毫秒)
        if let startMs = try? container.decode(Int64.self, forKey: .start) {
            start = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
        } else if let startDouble = try? container.decode(Double.self, forKey: .start) {
            start = Date(timeIntervalSince1970: startDouble / 1000)
        } else {
            start = Date()
        }
        
        // 3. End 時間容錯：支援 數字(毫秒)
        if let endMs = try? container.decode(Int64.self, forKey: .end) {
            end = Date(timeIntervalSince1970: TimeInterval(endMs) / 1000)
        } else if let endDouble = try? container.decode(Double.self, forKey: .end) {
            end = Date(timeIntervalSince1970: endDouble / 1000)
        } else {
            end = Date()
        }
    }
    
    // 寫入 (Encoding)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        // 為了相容 Web，我們寫入時還是轉成毫秒數字
        try container.encode(Int64(start.timeIntervalSince1970 * 1000), forKey: .start)
        try container.encode(Int64(end.timeIntervalSince1970 * 1000), forKey: .end)
    }
    
    // 手動建立用
    init(id: String = UUID().uuidString, start: Date, end: Date, displayName: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.displayName = displayName
    }
}

// MARK: - 2. 使用者 (User)
struct User: Identifiable, Codable, Equatable {
    var id: String
    var email: String
    var cycles: [Cycle]
    var identity: Identity
    var isVIP: Bool = false // 🔥 VIP 用戶才能同步 Firebase
    
    // UI 顯示用 (不存入 Firestore)
    var displayName: String?
    var photoURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id, email, cycles, identity, isVIP
    }
    
    // 讀取
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID 容錯
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else {
            // 如果 User document 裡沒有 id 欄位，給空字串 (AuthService 會補上)
            id = ""
        }
        
        email = (try? container.decode(String.self, forKey: .email)) ?? ""
        
        // Cycles 讀取
        cycles = (try? container.decode([Cycle].self, forKey: .cycles)) ?? []
        
        // Identity 讀取 (預設 adult)
        identity = (try? container.decode(Identity.self, forKey: .identity)) ?? .adult
        
        // isVIP 讀取 (預設 false)
        isVIP = (try? container.decode(Bool.self, forKey: .isVIP)) ?? false
        
        displayName = nil
        photoURL = nil
    }
    
    // 寫入
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(cycles, forKey: .cycles)
        try container.encode(identity, forKey: .identity)
        try container.encode(isVIP, forKey: .isVIP)
    }
    
    // 手動初始化
    init(id: String, email: String, cycles: [Cycle], identity: Identity, isVIP: Bool = false, displayName: String? = nil, photoURL: URL? = nil) {
        self.id = id
        self.email = email
        self.cycles = cycles
        self.identity = identity
        self.isVIP = isVIP
        self.displayName = displayName
        self.photoURL = photoURL
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.cycles == rhs.cycles &&
               lhs.identity == rhs.identity &&
               lhs.isVIP == rhs.isVIP &&
               lhs.photoURL == rhs.photoURL
    }
}
