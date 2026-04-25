import Foundation

// MARK: - 0. 回家站點 (HomeStation)
struct HomeStation: Identifiable, Codable, Equatable {
    var id: String
    var name: String           // 站點名稱
    var transportType: TransportType  // 運具類型
    var lineCode: String?      // 線路代碼（捷運用）
    var createdAt: Date
    
    init(id: String = UUID().uuidString, name: String, transportType: TransportType, lineCode: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.transportType = transportType
        self.lineCode = lineCode
        self.createdAt = createdAt
    }
}

// MARK: - 0-1. 出門站點 (OutboundStation)
struct OutboundStation: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var transportType: TransportType
    var lineCode: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, transportType: TransportType, lineCode: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.transportType = transportType
        self.lineCode = lineCode
        self.createdAt = createdAt
    }
}

// MARK: - 1. 週期 (Cycle)
struct Cycle: Identifiable, Codable, Hashable {
    var id: String
    var start: Date
    var end: Date
    var displayName: String?
    var region: TPASSRegion = .north  // 綁定該週期的方案
    var selectedModes: [TransportType]?  // 彈性週期：使用者選擇的運具（nil 表示全選）
    var cardId: String?  // 綁定的卡片 ID (TransitCard.id.uuidString)

    var title: String {
        if let name = displayName, !name.isEmpty { return name }
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return "\(f.string(from: start)) ~ \(f.string(from: end))"
    }

    // 根據 selectedModes 或 region 回傳有效的運具列表
    var effectiveSupportedModes: [TransportType] {
        if let modes = selectedModes, !modes.isEmpty {
            return modes
        }
        return region.supportedModes
    }

    enum CodingKeys: String, CodingKey {
        case id, start, end, displayName, region, selectedModes, cardId
    }
    
    //  讀取邏輯 (Decoding)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. ID 容錯：如果是數字 (Web版舊資料)，就轉成字串；如果是字串就直接讀
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
        
        //     新增：讀取該週期綁定的方案，若無則預設為 north
        if let regionRaw = try? container.decode(String.self, forKey: .region),
           let decodedRegion = TPASSRegion(rawValue: regionRaw) {
            region = decodedRegion
        } else {
            region = .north
        }
        
        // 讀取彈性週期的運具選擇（向後相容：舊資料無此欄位時為 nil）
        selectedModes = try? container.decode([TransportType].self, forKey: .selectedModes)
        
        // 讀取綁定的卡片 ID（向後相容：舊資料無此欄位時為 nil）
        cardId = try? container.decode(String.self, forKey: .cardId)
    }
    
    // 寫入 (Encoding)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        // 為了相容 Web，我們寫入時還是轉成毫秒數字
        try container.encode(Int64(start.timeIntervalSince1970 * 1000), forKey: .start)
        try container.encode(Int64(end.timeIntervalSince1970 * 1000), forKey: .end)
        try container.encode(region.rawValue, forKey: .region)
        try container.encodeIfPresent(selectedModes, forKey: .selectedModes)
        try container.encodeIfPresent(cardId, forKey: .cardId)
    }
    
    // 手動建立用
    init(id: String = UUID().uuidString, start: Date, end: Date, displayName: String? = nil, region: TPASSRegion = .north, selectedModes: [TransportType]? = nil, cardId: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.displayName = displayName
        self.region = region
        self.selectedModes = selectedModes
        self.cardId = cardId
    }
}

// MARK: - 2. 使用者 (User)
struct User: Identifiable, Codable, Equatable {
    var id: String
    var email: String
    var cycles: [Cycle]
    var identity: Identity
    var citizenCity: TaiwanCity?  // 市民縣市設定（nil 表示顯示全部）
    var homeStations: [HomeStation] // 回家站點列表
    var outboundStations: [OutboundStation] // 出門站點列表
    
    // UI 顯示用 (不存入 Firestore)
    var displayName: String?
    var photoURL: URL?
    
    enum CodingKeys: String, CodingKey {
        case id, email, cycles, identity, isVIP, citizenCity, homeStations, outboundStations
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
        
        // CitizenCity 讀取 (預設 nil，顯示全部)
        citizenCity = try? container.decode(TaiwanCity.self, forKey: .citizenCity)
        
        // HomeStations 讀取 (預設空陣列)
        homeStations = (try? container.decode([HomeStation].self, forKey: .homeStations)) ?? []

        // OutboundStations 讀取 (預設空陣列)
        outboundStations = (try? container.decode([OutboundStation].self, forKey: .outboundStations)) ?? []
        
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
        try container.encodeIfPresent(citizenCity, forKey: .citizenCity)
        try container.encode(homeStations, forKey: .homeStations)
        try container.encode(outboundStations, forKey: .outboundStations)
    }
    
    // 手動初始化
    init(id: String, email: String, cycles: [Cycle], identity: Identity, isVIP: Bool = false, citizenCity: TaiwanCity? = nil, homeStations: [HomeStation] = [], outboundStations: [OutboundStation] = [], displayName: String? = nil, photoURL: URL? = nil) {
        self.id = id
        self.email = email
        self.cycles = cycles
        self.identity = identity
        self.citizenCity = citizenCity
        self.homeStations = homeStations
        self.outboundStations = outboundStations
        self.displayName = displayName
        self.photoURL = photoURL
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.cycles == rhs.cycles &&
               lhs.identity == rhs.identity &&
               lhs.citizenCity == rhs.citizenCity &&
               lhs.homeStations == rhs.homeStations &&
               lhs.outboundStations == rhs.outboundStations &&
               lhs.photoURL == rhs.photoURL
    }
}
