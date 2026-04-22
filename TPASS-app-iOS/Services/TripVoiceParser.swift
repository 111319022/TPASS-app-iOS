import Foundation

/// 語音行程解析器：文字正規化 + 欄位抽取 + 信心分數計算
/// V1 版本：單趟行程解析，不做自動票價反查
struct TripVoiceParser {
    
    // MARK: - 解析結果
    struct ParsedTrip {
        var transportType: TransportType?
        var startStation: String?
        var endStation: String?
        var price: Int?
        var routeId: String?
        var date: Date?
        var time: Date?
        var note: String?
        var isTransfer: Bool = false
        
        // 信心分數
        var stationScore: Double = 0.0
        var transportScore: Double = 0.0
        var priceScore: Double = 0.0
        var timeScore: Double = 0.0
        var consistencyScore: Double = 0.0
        
        /// V1 overallScore = 0.40 * stationScore + 0.25 * transportScore + 0.20 * timeScore + 0.15 * consistencyScore
        var overallScore: Double {
            var score = 0.40 * stationScore + 0.25 * transportScore + 0.20 * timeScore + 0.15 * consistencyScore
            // 若起點或終點任一欄位低於 0.60，整體上限封頂為 0.79
            if stationScore < 0.60 {
                score = min(score, 0.79)
            }
            return score
        }
        
        /// 是否可直接建立（高信心）
        var isHighConfidence: Bool { overallScore >= 0.85 }
        /// 是否需要確認（中信心）
        var isMediumConfidence: Bool { overallScore >= 0.65 && overallScore < 0.85 }
        /// 是否需要手動輸入（低信心）
        var isLowConfidence: Bool { overallScore < 0.65 }
        
        /// 必要欄位是否完整
        var hasRequiredFields: Bool {
            transportType != nil && startStation != nil && endStation != nil
        }
    }
    
    // MARK: - 運具同義詞映射
    private static let transportSynonyms: [(keywords: [String], type: TransportType)] = [
        (["捷運", "地鐵", "mrt", "北捷", "台北捷運"], .mrt),
        (["機捷", "桃捷", "桃園捷運", "機場捷運"], .tymrt),
        (["高鐵", "hsr", "高速鐵路"], .hsr),
        (["台鐵", "火車", "臺鐵", "區間車", "自強號", "莒光號", "普悠瑪", "太魯閣"], .tra),
        (["公車", "巴士", "市公車", "市區公車"], .bus),
        (["客運", "國道客運", "長途客運"], .coach),
        (["中捷", "台中捷運", "臺中捷運"], .tcmrt),
        (["高捷", "高雄捷運"], .kmrt),
        (["腳踏車", "ubike", "youbike", "優拜", "自行車", "單車", "微笑單車"], .bike),
        (["輕軌", "淡海輕軌", "安坑輕軌", "高雄輕軌"], .lrt),
        (["渡輪", "渡船", "ferry"], .ferry),
    ]
    
    // MARK: - 站名別名映射
    private static let stationAliases: [String: String] = [
        "北車": "台北車站",
        "臺北車站": "台北車站",
        "台北火車站": "台北車站",
        "板橋車站": "板橋",
        "桃園高鐵站": "高鐵桃園站",
        "桃園高鐵": "高鐵桃園站",
        "台中高鐵站": "高鐵台中站",
        "台中高鐵": "高鐵台中站",
        "左營高鐵站": "高鐵左營站",
        "左營高鐵": "高鐵左營站",
        "南港高鐵站": "高鐵南港站",
        "南港高鐵": "高鐵南港站",
        "動物園站": "動物園",
        "市政府站": "市政府",
        "西門町": "西門",
        "西門站": "西門",
        "忠孝復興站": "忠孝復興",
        "忠孝敦化站": "忠孝敦化",
        "台北101": "台北101/世貿",
        "世貿站": "台北101/世貿",
        "松山機場": "松山機場",
        "桃園機場": "桃園國際機場",
    ]
    
    // MARK: - 時間口語映射
    private static let relativeTimePatterns: [(pattern: String, dayOffset: Int)] = [
        ("今天", 0),
        ("今日", 0),
        ("昨天", -1),
        ("昨日", -1),
        ("前天", -2),
        ("前日", -2),
        ("大前天", -3),
    ]
    
    private static let timeOfDayPatterns: [(pattern: String, hour: Int, minute: Int)] = [
        ("早上", 8, 0),
        ("上午", 10, 0),
        ("中午", 12, 0),
        ("下午", 14, 0),
        ("傍晚", 17, 0),
        ("晚上", 20, 0),
    ]
    
    // MARK: - 主解析方法
    
    static func parse(_ rawText: String) -> ParsedTrip {
        var result = ParsedTrip()
        
        // 1. 文字正規化
        let normalized = normalizeText(rawText)
        
        // 2. 多段行程偵測（V1 不支援轉乘）
        if detectMultiSegment(normalized) {
            result.note = rawText
            result.stationScore = 0.0
            return result
        }
        
        // 3. 運具抽取
        let (transport, transportConfidence) = extractTransport(normalized)
        result.transportType = transport
        result.transportScore = transportConfidence
        
        // 4. 路線抽取（公車/客運）
        result.routeId = extractRouteId(normalized)
        
        // 5. 價格抽取
        let (price, priceConfidence) = extractPrice(normalized)
        result.price = price
        result.priceScore = priceConfidence
        
        // 6. 起迄站抽取
        let (start, end, stationConfidence) = extractStations(normalized, transport: transport)
        result.startStation = start
        result.endStation = end
        result.stationScore = stationConfidence
        
        // 7. 時間抽取
        let (date, time, timeConfidence) = extractDateTime(normalized)
        result.date = date
        result.time = time
        result.timeScore = timeConfidence
        
        // 8. 一致性分數
        result.consistencyScore = calculateConsistency(result)
        
        // 9. 剩餘文字放入備註
        result.note = rawText
        
        return result
    }
    
    // MARK: - 文字正規化
    
    static func normalizeText(_ text: String) -> String {
        var result = text
        
        // 移除頭尾空白
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 統一全半形
        result = result.replacingOccurrences(of: "：", with: ":")
        result = result.replacingOccurrences(of: "，", with: ",")
        result = result.replacingOccurrences(of: "。", with: ".")
        result = result.replacingOccurrences(of: "－", with: "-")
        result = result.replacingOccurrences(of: "　", with: " ")
        
        // 連續空格合併
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        // 中文數字轉阿拉伯數字（常見場景）
        result = convertChineseNumbers(result)
        
        return result
    }
    
    // MARK: - 中文數字轉換
    
    private static let chineseDigits: [Character: Int] = [
        "零": 0, "〇": 0, "一": 1, "二": 2, "兩": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
    ]
    
    private static let chineseMultipliers: [Character: Int] = [
        "十": 10, "百": 100, "千": 1000,
    ]
    
    static func convertChineseNumbers(_ text: String) -> String {
        var result = text
        
        // 處理「X塊」「X元」格式
        let pricePatterns = [
            // 匹配中文數字 + 塊/元
            try? NSRegularExpression(pattern: "([零〇一二兩三四五六七八九十百千]+)(塊|元|塊錢)", options: []),
        ].compactMap { $0 }
        
        for regex in pricePatterns {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: nsRange)
            
            // 從後往前替換，避免 range 錯位
            for match in matches.reversed() {
                guard let numRange = Range(match.range(at: 1), in: result) else { continue }
                let chineseNum = String(result[numRange])
                if let arabicNum = chineseToArabic(chineseNum) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: "\(arabicNum)元")
                }
            }
        }
        
        // 處理路線號碼：「三零七」->「307」、「三零七路」->「307路」
        let routePattern = try? NSRegularExpression(pattern: "([零〇一二兩三四五六七八九]{2,})(路|號)?", options: [])
        if let routePattern {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = routePattern.matches(in: result, options: [], range: nsRange)
            for match in matches.reversed() {
                guard let numRange = Range(match.range(at: 1), in: result) else { continue }
                let chineseNum = String(result[numRange])
                // 逐字轉換（適用於路線號碼）
                let digits = chineseNum.compactMap { chineseDigits[$0] }
                if digits.count == chineseNum.count {
                    let arabicStr = digits.map { String($0) }.joined()
                    let fullRange = Range(match.range, in: result)!
                    let suffix = match.range(at: 2).location != NSNotFound ? "路" : ""
                    result.replaceSubrange(fullRange, with: arabicStr + suffix)
                }
            }
        }
        
        return result
    }
    
    private static func chineseToArabic(_ text: String) -> Int? {
        // 簡單處理：十位以下和百位數字
        var total = 0
        var current = 0
        
        for char in text {
            if let digit = chineseDigits[char] {
                current = digit
            } else if let mult = chineseMultipliers[char] {
                if current == 0 && mult == 10 {
                    current = 1 // 「十」= 10
                }
                total += current * mult
                current = 0
            }
        }
        total += current
        
        return total > 0 ? total : nil
    }
    
    // MARK: - 多段行程偵測
    
    private static func detectMultiSegment(_ text: String) -> Bool {
        // 計算「到」「至」「往」的出現次數
        let toPatterns = ["到", "至", "往", "去", "→", "->"]
        var count = 0
        for pattern in toPatterns {
            count += text.components(separatedBy: pattern).count - 1
        }
        // 如果出現兩次以上方向詞，可能是多段行程
        // 同時檢查「轉」「換」「再搭」等轉乘詞彙
        let transferKeywords = ["轉", "換乘", "再搭", "然後搭", "接著搭", "再坐", "然後坐"]
        let hasTransferKeyword = transferKeywords.contains(where: { text.contains($0) })
        
        return count >= 2 || hasTransferKeyword
    }
    
    // MARK: - 運具抽取
    
    private static func extractTransport(_ text: String) -> (TransportType?, Double) {
        let lowered = text.lowercased()
        
        for entry in transportSynonyms {
            for keyword in entry.keywords {
                if lowered.contains(keyword.lowercased()) {
                    return (entry.type, 1.0) // 精準匹配
                }
            }
        }
        
        return (nil, 0.0)
    }
    
    // MARK: - 路線抽取
    
    private static func extractRouteId(_ text: String) -> String? {
        // 匹配數字路線（3位數常見公車號碼）
        let routeRegex = try? NSRegularExpression(pattern: "(\\d{1,4})(路|號)?", options: [])
        guard let routeRegex else { return nil }
        
        let nsRange = NSRange(text.startIndex..., in: text)
        if let match = routeRegex.firstMatch(in: text, options: [], range: nsRange),
           let numRange = Range(match.range(at: 1), in: text) {
            let routeNum = String(text[numRange])
            // 排除可能是價格的數字（通常 <= 200 元的金額容易混淆）
            // 如果文字中同時出現「元」「塊」等字，這個數字可能不是路線
            if let numVal = Int(routeNum), numVal > 0, numVal < 10000 {
                // 檢查這個數字後面是否接「元」「塊」
                let afterMatch = text.suffix(from: text.index(text.startIndex, offsetBy: match.range.location + match.range.length))
                if afterMatch.hasPrefix("元") || afterMatch.hasPrefix("塊") {
                    return nil // 這是價格，不是路線
                }
                return routeNum
            }
        }
        
        return nil
    }
    
    // MARK: - 價格抽取
    
    private static func extractPrice(_ text: String) -> (Int?, Double) {
        // 匹配「XX元」「XX塊」「XX塊錢」「$XX」
        let pricePatterns = [
            try? NSRegularExpression(pattern: "(\\d+)\\s*(元|塊錢|塊)", options: []),
            try? NSRegularExpression(pattern: "\\$\\s*(\\d+)", options: []),
            try? NSRegularExpression(pattern: "票價\\s*(\\d+)", options: []),
            try? NSRegularExpression(pattern: "花了?\\s*(\\d+)", options: []),
        ].compactMap { $0 }
        
        for regex in pricePatterns {
            let nsRange = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange),
               let numRange = Range(match.range(at: 1), in: text),
               let price = Int(text[numRange]) {
                return (price, 0.9)
            }
        }
        
        return (nil, 0.0)
    }
    
    // MARK: - 起迄站抽取
    
    private static func extractStations(_ text: String, transport: TransportType?) -> (String?, String?, Double) {
        // 嘗試匹配「從 X 到 Y」「X 到 Y」「X 至 Y」等模式
        let stationPatterns = [
            try? NSRegularExpression(pattern: "從\\s*(.+?)\\s*(?:到|至|往|去)\\s*(.+?)(?:\\s|$|,|。|搭|坐|花|票價|\\d+元)", options: []),
            try? NSRegularExpression(pattern: "(.+?)\\s*(?:到|至|→|->)\\s*(.+?)(?:\\s|$|,|。|搭|坐|花|票價|\\d+元)", options: []),
        ].compactMap { $0 }
        
        for regex in stationPatterns {
            let nsRange = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange),
               let startRange = Range(match.range(at: 1), in: text),
               let endRange = Range(match.range(at: 2), in: text) {
                var startName = String(text[startRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                var endName = String(text[endRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 移除運具關鍵字（如果站名包含運具名稱）
                startName = removeTransportKeywords(startName)
                endName = removeTransportKeywords(endName)
                
                // 套用站名別名
                startName = resolveStationAlias(startName)
                endName = resolveStationAlias(endName)
                
                // 驗證站名（嘗試在站名資料庫中找到）
                guard !startName.isEmpty, !endName.isEmpty else { continue }
                
                let startValid = validateStation(startName, transport: transport)
                let endValid = validateStation(endName, transport: transport)
                
                let score: Double
                if startValid && endValid {
                    score = 1.0 // 雙站精準匹配
                } else if startValid || endValid {
                    score = 0.7 // 單站匹配
                } else {
                    score = 0.4 // 都沒匹配到但有抽取到名稱
                }
                
                return (startName, endName, score)
            }
        }
        
        return (nil, nil, 0.0)
    }
    
    private static func removeTransportKeywords(_ text: String) -> String {
        var result = text
        let keywords = ["搭", "坐", "搭乘", "坐了", "搭了", "捷運", "公車", "火車", "高鐵", "台鐵", "客運", "輕軌"]
        for keyword in keywords {
            result = result.replacingOccurrences(of: keyword, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func resolveStationAlias(_ name: String) -> String {
        // 移除尾部的「站」字（很多人會說「台北車站站」）
        var cleaned = name
        if cleaned.hasSuffix("站") && cleaned.count > 2 {
            // 保留像「市政府站」這類本身就包含「站」的站名
            let withoutStation = String(cleaned.dropLast())
            // 先查別名表
            if let alias = stationAliases[withoutStation] {
                return alias
            }
            // 如果去掉「站」後還能在資料庫找到，就去掉
            cleaned = withoutStation
        }
        
        return stationAliases[cleaned] ?? cleaned
    }
    
    /// 驗證站名是否存在於已知站名資料庫
    @MainActor
    private static func validateStation(_ name: String, transport: TransportType?) -> Bool {
        // 根據運具類型選擇對應的站名資料庫
        switch transport {
        case .mrt:
            return StationData.shared.lines.contains(where: { $0.stations.contains(name) })
        case .tymrt:
            return TYMRTStationData.shared.line.stations.contains(name)
        case .tcmrt:
            return TCMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) })
        case .kmrt:
            return KMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) })
        case .hsr:
            return HSRStationData.shared.line.stations.contains(name)
        default:
            // 嘗試所有資料庫
            if StationData.shared.lines.contains(where: { $0.stations.contains(name) }) { return true }
            if TYMRTStationData.shared.line.stations.contains(name) { return true }
            if TCMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) }) { return true }
            if KMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) }) { return true }
            if HSRStationData.shared.line.stations.contains(name) { return true }
            return false
        }
    }
    
    // MARK: - 時間抽取
    
    private static func extractDateTime(_ text: String) -> (Date?, Date?, Double) {
        let calendar = Calendar.current
        var dateResult: Date?
        var timeResult: Date?
        var confidence: Double = 0.0
        
        // 相對日期
        for entry in relativeTimePatterns {
            if text.contains(entry.pattern) {
                dateResult = calendar.date(byAdding: .day, value: entry.dayOffset, to: Date())
                confidence = max(confidence, 0.9)
                break
            }
        }
        
        // 時間段
        for entry in timeOfDayPatterns {
            if text.contains(entry.pattern) {
                var components = DateComponents()
                components.hour = entry.hour
                components.minute = entry.minute
                timeResult = calendar.date(from: components)
                confidence = max(confidence, 0.6) // 時間段信心較低
                break
            }
        }
        
        // 精確時間：「X點Y分」「X:Y」
        let timeRegex = try? NSRegularExpression(pattern: "(\\d{1,2})\\s*(?:點|:)\\s*(\\d{1,2})?\\s*(?:分)?", options: [])
        if let timeRegex {
            let nsRange = NSRange(text.startIndex..., in: text)
            if let match = timeRegex.firstMatch(in: text, options: [], range: nsRange),
               let hourRange = Range(match.range(at: 1), in: text),
               let hour = Int(text[hourRange]), hour >= 0, hour < 24 {
                var components = DateComponents()
                components.hour = hour
                if match.range(at: 2).location != NSNotFound,
                   let minRange = Range(match.range(at: 2), in: text),
                   let minute = Int(text[minRange]) {
                    components.minute = minute
                } else {
                    components.minute = 0
                }
                timeResult = calendar.date(from: components)
                confidence = 0.9
            }
        }
        
        // 如果都沒偵測到，預設使用當前時間（但信心分數為低）
        if dateResult == nil && timeResult == nil {
            confidence = 0.3 // 使用預設時間，信心低
        }
        
        return (dateResult, timeResult, confidence)
    }
    
    // MARK: - 一致性分數
    
    private static func calculateConsistency(_ parsed: ParsedTrip) -> Double {
        var score = 0.5 // 基準
        
        // 如果有運具且有站名，加分
        if parsed.transportType != nil && parsed.startStation != nil && parsed.endStation != nil {
            score += 0.3
        }
        
        // 如果有價格且合理範圍（0~5000），加分
        if let price = parsed.price, price >= 0, price <= 5000 {
            score += 0.2
        }
        
        return min(score, 1.0)
    }
}
