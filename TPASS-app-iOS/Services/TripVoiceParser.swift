import Foundation

// MARK: - JSON 規則資料模型

/// VoiceNLP_Rules.json 的頂層結構
struct VoiceNLPRules: Codable {
    let _meta: Meta?
    let noiseFilters: [String]
    let transports: [TransportRule]
    let stationAliases: [String: String]
    let pricePatterns: [PatternRule]
    let timeSemantics: TimeSemantics
    let chineseNumbers: ChineseNumbers
    let multiSegmentKeywords: MultiSegmentKeywords
    let stationPatterns: [PatternRule]
    let transportRemoveKeywords: [String]
    let routePatterns: [PatternRule]
    let confidence: ConfidenceConfig
    
    /// JSON 元資料
    struct Meta: Codable {
        let version: String
        let description: String?
        let lastUpdated: String?
        
        enum CodingKeys: String, CodingKey {
            case version, description
            case lastUpdated = "last_updated"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case _meta
        case noiseFilters = "noise_filters"
        case transports
        case stationAliases = "station_aliases"
        case pricePatterns = "price_patterns"
        case timeSemantics = "time_semantics"
        case chineseNumbers = "chinese_numbers"
        case multiSegmentKeywords = "multi_segment_keywords"
        case stationPatterns = "station_patterns"
        case transportRemoveKeywords = "transport_remove_keywords"
        case routePatterns = "route_patterns"
        case confidence
    }
    
    /// 自訂 decoder：跳過 _comment 開頭的 key
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _meta = try container.decodeIfPresent(Meta.self, forKey: ._meta)
        noiseFilters = try container.decode([String].self, forKey: .noiseFilters)
        transports = try container.decode([TransportRule].self, forKey: .transports)
        pricePatterns = try container.decode([PatternRule].self, forKey: .pricePatterns)
        timeSemantics = try container.decode(TimeSemantics.self, forKey: .timeSemantics)
        chineseNumbers = try container.decode(ChineseNumbers.self, forKey: .chineseNumbers)
        multiSegmentKeywords = try container.decode(MultiSegmentKeywords.self, forKey: .multiSegmentKeywords)
        stationPatterns = try container.decode([PatternRule].self, forKey: .stationPatterns)
        transportRemoveKeywords = try container.decode([String].self, forKey: .transportRemoveKeywords)
        routePatterns = try container.decode([PatternRule].self, forKey: .routePatterns)
        confidence = try container.decode(ConfidenceConfig.self, forKey: .confidence)
        
        // station_aliases：過濾掉 _comment 開頭的 key
        let rawAliases = try container.decode([String: String].self, forKey: .stationAliases)
        stationAliases = rawAliases.filter { !$0.key.hasPrefix("_comment") }
    }
}

/// 運具辨識規則
struct TransportRule: Codable {
    let id: String
    let canonicalName: String
    let priority: Int
    let keywords: [String]
    let asrErrors: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case canonicalName = "canonical_name"
        case priority
        case keywords
        case asrErrors = "asr_errors"
    }
    
    /// 將 JSON id 轉為 App 內的 TransportType enum
    var transportType: TransportType? {
        switch id {
        case "mrt":   return .mrt
        case "bus":   return .bus
        case "coach": return .coach
        case "tra":   return .tra
        case "tymrt": return .tymrt
        case "lrt":   return .lrt
        case "bike":  return .bike
        case "ferry": return .ferry
        case "tcmrt": return .tcmrt
        case "kmrt":  return .kmrt
        case "hsr":   return .hsr
        default:      return nil
        }
    }
    
    /// 所有可能命中的關鍵字（正式 + ASR 誤聽）
    var allKeywords: [String] { keywords + asrErrors }
}

/// 正則規則（票價 / 站點 / 路線共用）
struct PatternRule: Codable {
    let regex: String
    let description: String
}

/// 時間語意
struct TimeSemantics: Codable {
    let relativeDays: [RelativeDay]
    let timeOfDay: [TimeOfDay]
    
    enum CodingKeys: String, CodingKey {
        case relativeDays = "relative_days"
        case timeOfDay = "time_of_day"
    }
    
    struct RelativeDay: Codable {
        let keyword: String
        let dayOffset: Int
        enum CodingKeys: String, CodingKey {
            case keyword
            case dayOffset = "day_offset"
        }
    }
    
    struct TimeOfDay: Codable {
        let keyword: String
        let hour: Int
        let minute: Int
    }
}

/// 中文數字對照
struct ChineseNumbers: Codable {
    let digits: [String: Int]
    let multipliers: [String: Int]
}

/// 多段行程偵測
struct MultiSegmentKeywords: Codable {
    let directionWords: [String]
    let transferKeywords: [String]
    let directionThreshold: Int
    
    enum CodingKeys: String, CodingKey {
        case directionWords = "direction_words"
        case transferKeywords = "transfer_keywords"
        case directionThreshold = "direction_threshold"
    }
}

/// 信心分數設定
struct ConfidenceConfig: Codable {
    let weights: Weights
    let thresholds: Thresholds
    
    struct Weights: Codable {
        let station: Double
        let transport: Double
        let time: Double
        let consistency: Double
    }
    
    struct Thresholds: Codable {
        let high: Double
        let medium: Double
        let stationCapTrigger: Double
        let stationCapValue: Double
        
        enum CodingKeys: String, CodingKey {
            case high, medium
            case stationCapTrigger = "station_cap_trigger"
            case stationCapValue = "station_cap_value"
        }
    }
}

// MARK: - 語音行程解析器

/// 語音行程解析器：文字正規化 + 欄位抽取 + 信心分數計算
/// 所有靜態規則皆從 VoiceNLP_Rules.json 載入，方便後續無程式碼更新
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
        
        // 信心分數（0.0 ~ 1.0）
        var stationScore: Double = 0.0
        var transportScore: Double = 0.0
        var priceScore: Double = 0.0
        var timeScore: Double = 0.0
        var consistencyScore: Double = 0.0
        
        /// 加權信心總分（由 JSON confidence.weights 定義權重）
        var overallScore: Double {
            let w = TripVoiceParser.rules.confidence.weights
            let t = TripVoiceParser.rules.confidence.thresholds
            var score = w.station * stationScore
                      + w.transport * transportScore
                      + w.time * timeScore
                      + w.consistency * consistencyScore
            // 若站名信心低於門檻，整體封頂
            if stationScore < t.stationCapTrigger {
                score = min(score, t.stationCapValue)
            }
            return score
        }
        
        var isHighConfidence: Bool {
            overallScore >= TripVoiceParser.rules.confidence.thresholds.high
        }
        var isMediumConfidence: Bool {
            let t = TripVoiceParser.rules.confidence.thresholds
            return overallScore >= t.medium && overallScore < t.high
        }
        var isLowConfidence: Bool {
            overallScore < TripVoiceParser.rules.confidence.thresholds.medium
        }
        
        /// 必要欄位是否完整
        var hasRequiredFields: Bool {
            transportType != nil && startStation != nil && endStation != nil
        }
    }
    
    // MARK: - 規則載入（懶載入，整個 App 生命週期只讀一次）
    
    /// 從 Bundle 載入 VoiceNLP_Rules.json
    static let rules: VoiceNLPRules = {
        guard let url = Bundle.main.url(forResource: "VoiceNLP_Rules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("[VoiceNLPRules] 找不到 VoiceNLP_Rules.json，請確認已加入 App Target")
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(VoiceNLPRules.self, from: data)
        } catch {
            fatalError("[VoiceNLPRules] JSON 解碼失敗: \(error)")
        }
    }()
    
    // MARK: - 衍生快取（從 JSON 產生，避免重複建構）
    
    /// 運具同義詞映射：按 priority 排序（priority 小 = 優先）
    private static let sortedTransportRules: [TransportRule] = {
        rules.transports.sorted { $0.priority < $1.priority }
    }()
    
    /// 中文數字 → Int 快查（Character key）
    private static let chineseDigitMap: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (key, value) in rules.chineseNumbers.digits {
            if let char = key.first { map[char] = value }
        }
        return map
    }()
    
    private static let chineseMultiplierMap: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (key, value) in rules.chineseNumbers.multipliers {
            if let char = key.first { map[char] = value }
        }
        return map
    }()
    
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
        result.routeId = extractRouteId(normalized, transport: transport)
        
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
        
        // 9. 原始文字放入備註
        result.note = rawText
        
        return result
    }
    
    // MARK: - 文字正規化
    
    static func normalizeText(_ text: String) -> String {
        var result = text
        
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 統一全半形標點
        result = result.replacingOccurrences(of: "：", with: ":")
        result = result.replacingOccurrences(of: "，", with: ",")
        result = result.replacingOccurrences(of: "。", with: ".")
        result = result.replacingOccurrences(of: "－", with: "-")
        result = result.replacingOccurrences(of: "　", with: " ")
        
        // 連續空格合併
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        // 中文數字轉阿拉伯數字
        result = convertChineseNumbers(result)
        
        return result
    }
    
    // MARK: - 中文數字轉換
    
    static func convertChineseNumbers(_ text: String) -> String {
        var result = text
        
        // 產生中文數字字元集合（從 JSON 載入）
        let digitChars = chineseDigitMap.keys.map { String($0) }.joined()
        
        // 處理「X塊」「X元」格式
        let pricePattern = try? NSRegularExpression(
            pattern: "([\(digitChars)]+)(塊|元|塊錢)",
            options: []
        )
        
        if let pricePattern {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = pricePattern.matches(in: result, options: [], range: nsRange)
            
            for match in matches.reversed() {
                guard let numRange = Range(match.range(at: 1), in: result) else { continue }
                let chineseNum = String(result[numRange])
                if let arabicNum = chineseToArabic(chineseNum) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: "\(arabicNum)元")
                }
            }
        }
        
        // 路線號碼逐字轉換：「三零七」→「307」
        let routePattern = try? NSRegularExpression(
            pattern: "([\(digitChars)]{2,})(路|號)?",
            options: []
        )
        if let routePattern {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = routePattern.matches(in: result, options: [], range: nsRange)
            for match in matches.reversed() {
                guard let numRange = Range(match.range(at: 1), in: result) else { continue }
                let chineseNum = String(result[numRange])
                let digits = chineseNum.compactMap { chineseDigitMap[$0] }
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
        var total = 0
        var current = 0
        
        for char in text {
            if let digit = chineseDigitMap[char] {
                current = digit
            } else if let mult = chineseMultiplierMap[char] {
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
        let msRules = rules.multiSegmentKeywords
        
        // 計算方向詞出現次數
        var directionCount = 0
        for word in msRules.directionWords {
            directionCount += text.components(separatedBy: word).count - 1
        }
        
        // 檢查轉乘詞彙
        let hasTransferKeyword = msRules.transferKeywords.contains(where: { text.contains($0) })
        
        return directionCount >= msRules.directionThreshold || hasTransferKeyword
    }
    
    // MARK: - 運具抽取
    
    private static func extractTransport(_ text: String) -> (TransportType?, Double) {
        let lowered = text.lowercased()
        var bestMatch: (type: TransportType, keywordLength: Int, priority: Int)?
        
        for rule in sortedTransportRules {
            guard let type = rule.transportType else { continue }
            for keyword in rule.allKeywords {
                if lowered.contains(keyword.lowercased()) {
                    let length = keyword.count
                    if let current = bestMatch {
                        // 更長的關鍵字優先；同長度則 priority 小的優先
                        if length > current.keywordLength ||
                           (length == current.keywordLength && rule.priority < current.priority) {
                            bestMatch = (type, length, rule.priority)
                        }
                    } else {
                        bestMatch = (type, length, rule.priority)
                    }
                }
            }
        }
        
        if let bestMatch {
            return (bestMatch.type, 1.0)
        }
        return (nil, 0.0)
    }
    
    // MARK: - 路線抽取
    
    private static func extractRouteId(_ text: String, transport: TransportType?) -> String? {
        guard transport == .bus || transport == .coach else { return nil }
        
        // 先移除時間格式，避免誤抓
        let timeRegex = try? NSRegularExpression(
            pattern: "\\d{1,2}\\s*(?:點|:)\\s*\\d{1,2}\\s*(?:分)?",
            options: []
        )
        let textWithoutTime: String
        if let timeRegex {
            textWithoutTime = timeRegex.stringByReplacingMatches(
                in: text, options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: " "
            )
        } else {
            textWithoutTime = text
        }
        
        // 使用 JSON 定義的路線正則
        for rule in rules.routePatterns {
            guard let regex = try? NSRegularExpression(pattern: rule.regex, options: [.caseInsensitive]) else { continue }
            let nsRange = NSRange(textWithoutTime.startIndex..., in: textWithoutTime)
            if let match = regex.firstMatch(in: textWithoutTime, options: [], range: nsRange),
               let routeRange = Range(match.range(at: 1), in: textWithoutTime) {
                let route = String(textWithoutTime[routeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !route.isEmpty {
                    return route.uppercased()
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 價格抽取
    
    private static func extractPrice(_ text: String) -> (Int?, Double) {
        for rule in rules.pricePatterns {
            guard let regex = try? NSRegularExpression(pattern: rule.regex, options: []) else { continue }
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
        // 先從文字中移除時間詞彙，避免時間被誤認為站名
        let textWithoutTime = removeTimeExpressions(text)
        
        for rule in rules.stationPatterns {
            guard let regex = try? NSRegularExpression(pattern: rule.regex, options: []) else { continue }
            let nsRange = NSRange(textWithoutTime.startIndex..., in: textWithoutTime)
            if let match = regex.firstMatch(in: textWithoutTime, options: [], range: nsRange),
               let startRange = Range(match.range(at: 1), in: textWithoutTime),
               let endRange = Range(match.range(at: 2), in: textWithoutTime) {
                var startName = String(textWithoutTime[startRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                var endName = String(textWithoutTime[endRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 移除運具關鍵字
                startName = removeTransportKeywords(startName)
                endName = removeTransportKeywords(endName)
                
                // 清理噪音詞與路線號碼
                startName = sanitizeStationCandidate(startName, transport: transport)
                endName = sanitizeStationCandidate(endName, transport: transport)
                
                // 套用別名
                startName = resolveStationAlias(startName)
                endName = resolveStationAlias(endName)
                
                // 依運具做站名補全
                startName = normalizeStationByTransport(startName, transport: transport)
                endName = normalizeStationByTransport(endName, transport: transport)
                
                // 台鐵站名統一格式
                if transport == .tra {
                    startName = normalizeTRAStationName(startName)
                    endName = normalizeTRAStationName(endName)
                }
                
                guard !startName.isEmpty, !endName.isEmpty else { continue }
                
                // 驗證站名
                let startValid = validateStation(startName, transport: transport)
                let endValid = validateStation(endName, transport: transport)
                
                let score: Double
                if startValid && endValid {
                    score = 1.0
                } else if startValid || endValid {
                    score = 0.7
                } else {
                    score = 0.4
                }
                
                return (startName, endName, score)
            }
        }
        
        return (nil, nil, 0.0)
    }
    
    /// 從站名候選中移除運具關鍵字（使用 JSON transport_remove_keywords）
    private static func removeTransportKeywords(_ text: String) -> String {
        var result = text
        for keyword in rules.transportRemoveKeywords {
            result = result.replacingOccurrences(of: keyword, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 清理站名候選中的噪音（日期、時間前綴、路線號碼等）
    private static func sanitizeStationCandidate(_ text: String, transport: TransportType?) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }
        
        // 移除日期前綴
        let datePatterns = [
            "昨天", "今天", "明天", "後天",
            "今年", "去年", "明年",
            "本週", "下週", "上週",
            "\\d{1,2}月\\d{1,2}日",
        ]
        for pattern in datePatterns {
            if result.hasPrefix(pattern) || result.starts(with: NSRegularExpression.escapedPattern(for: pattern)) {
                if let regex = try? NSRegularExpression(pattern: "^\(pattern)", options: []) {
                    let nsRange = NSRange(result.startIndex..., in: result)
                    if let match = regex.firstMatch(in: result, options: [], range: nsRange),
                       let range = Range(match.range, in: result) {
                        result.removeSubrange(range)
                        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        
        // 移除時間前綴
        let timePrefixPatterns = [
            "^(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)\\s*",
            "^(?:今天|昨日|昨天|明天|後天|前天|大前天)?\\s*(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)\\s*\\d{1,2}\\s*(?:點|:)\\s*(?:\\d{1,2})?\\s*(?:分)?\\s*",
            "^(\\d{1,2})\\s*(?:點|:)\\s*(\\d{1,2})?\\s*(?:分)?\\s*"
        ]
        for pattern in timePrefixPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsRange = NSRange(result.startIndex..., in: result)
            if let match = regex.firstMatch(in: result, options: [], range: nsRange),
               let range = Range(match.range, in: result) {
                result.removeSubrange(range)
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 常見前綴詞去除（使用 noise_filters 的子集）
        let leadingWords = ["從", "由", "在", "自", "搭", "坐"]
        for word in leadingWords where result.hasPrefix(word) {
            result.removeFirst(word.count)
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 公車/客運：移除路線號碼前綴
        if transport == .bus || transport == .coach {
            let englishRoutePattern = try? NSRegularExpression(pattern: "^[A-Za-z0-9]{1,6}(路|號)?", options: [])
            if let englishRoutePattern {
                let nsRange = NSRange(result.startIndex..., in: result)
                if let match = englishRoutePattern.firstMatch(in: result, options: [], range: nsRange),
                   let range = Range(match.range, in: result) {
                    result.removeSubrange(range)
                    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            let digitChars = chineseDigitMap.keys.map { String($0) }.joined()
            let chineseRoutePattern = try? NSRegularExpression(
                pattern: "^[\(digitChars)0-9]{1,6}\\s*(?:號|路)?",
                options: []
            )
            if let chineseRoutePattern {
                let nsRange = NSRange(result.startIndex..., in: result)
                if let match = chineseRoutePattern.firstMatch(in: result, options: [], range: nsRange),
                   let range = Range(match.range, in: result) {
                    result.removeSubrange(range)
                    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return result
    }
    
    /// 依運具做站名補全（如機捷「第一航廈」→「機場第一航廈」）
    @MainActor
    private static func normalizeStationByTransport(_ name: String, transport: TransportType?) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        
        switch transport {
        case .tymrt:
            let normalized = TYMRTStationData.shared.normalizeStationNameToZH(trimmed)
            if TYMRTStationData.shared.line.stations.contains(normalized) {
                return normalized
            }
            
            let stationList = TYMRTStationData.shared.line.stations
            let exactMatches = stationList.filter { $0 == trimmed }
            if let exact = exactMatches.first {
                return exact
            }
            
            let fuzzyMatches = stationList.filter { station in
                station.contains(trimmed) || station.hasSuffix(trimmed)
            }
            if fuzzyMatches.count == 1, let only = fuzzyMatches.first {
                return only
            }
            
            // 常見航廈口語補全（JSON station_aliases 也有，但這裡做 fallback）
            if trimmed == "第一航廈" { return "機場第一航廈" }
            if trimmed == "第二航廈" { return "機場第二航廈" }
            if trimmed == "第三航廈" { return "機場第三航廈" }
            
            return normalized
        default:
            return trimmed
        }
    }
    
    /// 站名別名解析（使用 JSON station_aliases）
    private static func resolveStationAlias(_ name: String) -> String {
        if let exactAlias = rules.stationAliases[name] {
            return exactAlias
        }
        
        // 移除尾部的「站」字
        var cleaned = name
        if cleaned.hasSuffix("站") && cleaned.count > 2 {
            let withoutStation = String(cleaned.dropLast())
            if let alias = rules.stationAliases[withoutStation] {
                return alias
            }
            cleaned = withoutStation
        }
        
        return rules.stationAliases[cleaned] ?? cleaned
    }
    
    /// 台鐵站名正規化（「台」→「臺」，移除尾部「站」）
    private static func normalizeTRAStationName(_ name: String) -> String {
        var normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasSuffix("站") && normalized.count > 1 {
            normalized = String(normalized.dropLast())
        }
        normalized = normalized.replacingOccurrences(of: "台", with: "臺")
        return normalized
    }
    
    /// 驗證站名是否存在於已知站名資料庫
    @MainActor
    private static func validateStation(_ name: String, transport: TransportType?) -> Bool {
        switch transport {
        case .mrt:
            return StationData.shared.lines.contains(where: { $0.stations.contains(name) })
        case .tymrt:
            return TYMRTStationData.shared.line.stations.contains(name)
        case .tcmrt:
            return TCMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) })
        case .kmrt:
            return KMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) })
        case .bus, .coach:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tra:
            return TRAStationData.shared.resolveStationID(normalizeTRAStationName(name)) != nil
        case .hsr:
            return HSRStationData.shared.line.stations.contains(name)
        default:
            if StationData.shared.lines.contains(where: { $0.stations.contains(name) }) { return true }
            if TYMRTStationData.shared.line.stations.contains(name) { return true }
            if TCMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) }) { return true }
            if KMRTStationData.shared.lines.contains(where: { $0.stations.contains(name) }) { return true }
            if TRAStationData.shared.resolveStationID(normalizeTRAStationName(name)) != nil { return true }
            if HSRStationData.shared.line.stations.contains(name) { return true }
            return false
        }
    }
    
    // MARK: - 時間表達式移除
    
    /// 從文字中移除所有時間相關表達式（日期+時間）
    /// 避免「到科技大樓今天下午3:30」中的時間被誤認為站名
    private static func removeTimeExpressions(_ text: String) -> String {
        var result = text
        
        // 移除「日期+時段+時間」組合
        // 例如：「今天下午 3:30」「明天中午 12:30」「2026年4月22日 03:30」
        let timeExpressionPatterns = [
            // 相對日期 + 時段 + 時間
            "(?:昨天|今天|明天|後天|前天|大前天)?\\s*(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)\\s*\\d{1,2}\\s*(?:點|:)\\s*\\d{1,2}\\s*(?:分)?",
            // 相對日期 + 時段（無時間數字）
            "(?:昨天|今天|明天|後天|前天|大前天)\\s*(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)",
            // 時段 + 時間（無日期）
            "(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)\\s*\\d{1,2}\\s*(?:點|:)\\s*\\d{1,2}\\s*(?:分)?",
            // ISO 格式日期 + 時間
            "\\d{4}年\\d{1,2}月\\d{1,2}日\\s*\\d{1,2}\\s*(?::|點)\\s*\\d{1,2}",
            // 純時間格式（HH:MM 或 HH點MM分）
            "\\d{1,2}\\s*(?:點|:)\\s*\\d{1,2}\\s*(?:分)?",
            // 相對日期單獨出現
            "(?:昨天|今天|明天|後天|前天|大前天)",
            // 月日格式
            "\\d{1,2}月\\d{1,2}日"
        ]
        
        for pattern in timeExpressionPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsRange = NSRange(result.startIndex..., in: result)
            
            // 迭代移除所有匹配（從後往前，避免位置偏移）
            let matches = regex.matches(in: result, options: [], range: nsRange).reversed()
            for match in matches {
                if let range = Range(match.range, in: result) {
                    result.removeSubrange(range)
                }
            }
        }
        
        // 連續空格合併
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 時間抽取
    
    private static func extractDateTime(_ text: String) -> (Date?, Date?, Double) {
        let calendar = Calendar.current
        var dateResult: Date?
        var timeResult: Date?
        var confidence: Double = 0.0
        
        // 相對日期（從 JSON 載入）
        for entry in rules.timeSemantics.relativeDays {
            if text.contains(entry.keyword) {
                dateResult = calendar.date(byAdding: .day, value: entry.dayOffset, to: Date())
                confidence = max(confidence, 0.9)
                break
            }
        }
        
        // 時間段（從 JSON 載入）
        for entry in rules.timeSemantics.timeOfDay {
            if text.contains(entry.keyword) {
                var components = DateComponents()
                components.hour = entry.hour
                components.minute = entry.minute
                timeResult = calendar.date(from: components)
                confidence = max(confidence, 0.6)
                break
            }
        }
        
        // 精確時間：「X點Y分」「X:Y」
        let timeRegex = try? NSRegularExpression(
            pattern: "(\\d{1,2})\\s*(?:點|:)\\s*(\\d{1,2})?\\s*(?:分)?",
            options: []
        )
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
        
        // 都沒偵測到 → 使用預設時間，信心低
        if dateResult == nil && timeResult == nil {
            confidence = 0.3
        }
        
        return (dateResult, timeResult, confidence)
    }
    
    // MARK: - 一致性分數
    
    private static func calculateConsistency(_ parsed: ParsedTrip) -> Double {
        var score = 0.5
        
        if parsed.transportType != nil && parsed.startStation != nil && parsed.endStation != nil {
            score += 0.3
        }
        
        if let price = parsed.price, price >= 0, price <= 5000 {
            score += 0.2
        }
        
        return min(score, 1.0)
    }
}
