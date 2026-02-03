import Foundation

class KMRTFareService {
    static let shared = KMRTFareService()
    
    // 高雄捷運票價表 (簡化版 - 實際應使用官方票價)
    // 紅線、橘線和輕軌票價
    private let fareMatrix: [String: [String: Int]] = [
        // 紅線票價示意 (實際應使用官方資料)
        "小港": [
            "高雄國際航空站": 30
        ],
        // ... 其他站點 (為簡潔起見，此處省略)
        
        // 橘線票價示意
        "西子灣": [
            "前金": 20
        ],
    ]
    
    /// 取得高雄捷運或輕軌票價
    func getFare(from startStation: String, to endStation: String) -> Int? {
        // 中文化處理
        let start = KMRTStationData.shared.normalizeStationNameToZH(startStation)
        let end = KMRTStationData.shared.normalizeStationNameToZH(endStation)
        
        // 避免始終站相同
        if start == end { return nil }
        
        // 查票價表
        if let startFares = fareMatrix[start] {
            if let fare = startFares[end] {
                return fare
            }
        }
        
        // 反向查詢（捷運雙向票價相同）
        if let endFares = fareMatrix[end] {
            if let fare = endFares[start] {
                return fare
            }
        }
        
        // 預設最短距離票價
        return 25
    }
}
