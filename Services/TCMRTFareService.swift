import Foundation

class TCMRTFareService {
    static let shared = TCMRTFareService()
    
    // 台中捷運票價表 (簡化版 - 實際應使用官方票價)
    // 紅線和綠線統一票價制度
    private let fareMatrix: [String: [String: Int]] = [
        // 紅線票價示意 (實際應使用官方資料)
        "北屯總站": [
            "舊社": 20
        ]
        // ... 其他站點 (為簡潔起見，此處省略)
    ]
    
    /// 取得台中捷運票價
    func getFare(from startStation: String, to endStation: String) -> Int? {
        // 中文化處理
        let start = TCMRTStationData.shared.normalizeStationNameToZH(startStation)
        let end = TCMRTStationData.shared.normalizeStationNameToZH(endStation)
        
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
        return 20
    }
}
