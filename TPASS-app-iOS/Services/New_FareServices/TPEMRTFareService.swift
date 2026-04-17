import Foundation

final class TPEMRTFareService {
    @MainActor static let shared = TPEMRTFareService()

    // 儲存票價的字典，key 為排序後的站名組合，例如 "台北車站-橋和"
    private let fareLookup: [String: Int]

    private init() {
        var fares: [String: Int] = [:]
        
        // 讀取由 Python 工具產生的全新 TPEMRT_Fare.json
        guard let url = Bundle.main.url(forResource: "TPEMRT_Fare", withExtension: "json") else {
            print("TPEMRTFareService: could not find TPEMRT_Fare.json in bundle")
            self.fareLookup = [:]
            return
        }

        do {
            let data = try Data(contentsOf: url)
            
            // 直接將 JSON 解析成巢狀字典 [起站: [訖站: 票價]]
            let nestedDict = try JSONDecoder().decode([String: [String: Int]].self, from: data)

            // 將巢狀資料扁平化存入 fareLookup 字典，以利快速查詢
            for (origin, destinations) in nestedDict {
                let originZH = Self.canonicalStationName(origin)
                
                for (destination, price) in destinations {
                    let destinationZH = Self.canonicalStationName(destination)
                    guard !originZH.isEmpty, !destinationZH.isEmpty else { continue }

                    // 產生不分方向性的唯一 Key
                    let key = Self.pairKey(originZH, destinationZH)
                    fares[key] = price
                }
            }
            print("✅ 成功載入捷運全網票價大表，共 \(fares.count) 組路徑")
        } catch {
            print("TPEMRTFareService: failed to decode JSON - \(error)")
        }

        self.fareLookup = fares
    }

    /// 取得兩站間的票價
    @MainActor
    func getFare(from start: String, to end: String) -> Int? {
        if start.isEmpty || end.isEmpty { return nil }

        // 透過 StationData 正規化站名（處理中英文與別名）
        let startZH = Self.canonicalStationName(StationData.shared.normalizeStationNameToZH(start))
        let endZH = Self.canonicalStationName(StationData.shared.normalizeStationNameToZH(end))
        
        if startZH.isEmpty || endZH.isEmpty { return nil }
        if startZH == endZH { return 0 }

        // 查詢雙向 Key
        let key = Self.pairKey(startZH, endZH)
        return fareLookup[key]
    }

    /// 統一站名格式，去除空白
    private static func canonicalStationName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
    }

    /// 產生唯一的雙向查詢 Key
    private static func pairKey(_ lhs: String, _ rhs: String) -> String {
        // 確保不論是 A->B 或 B->A，產生的 Key 順序都一致
        lhs <= rhs ? "\(lhs)-\(rhs)" : "\(rhs)-\(lhs)"
    }
}