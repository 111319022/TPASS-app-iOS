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
    let pmKeywords: [String]?
    
    enum CodingKeys: String, CodingKey {
        case relativeDays = "relative_days"
        case timeOfDay = "time_of_day"
        case pmKeywords = "pm_keywords"
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
        var startLineCode: String?
        var endLineCode: String?
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
                    guard let type = transportType else { return false }
                    let isStationlessAllowed = type == .bus || type == .coach || type == .bike || type == .ferry
                    
                    if isStationlessAllowed {
                        // 💡 嚴格條件：必須要有「路線號碼」或「金額」或「真實站名」，才能被判定為完整可儲存
                        let hasRouteOrPrice = routeId != nil || price != nil
                        // 將判斷條件改為空白字元 " "
                        let hasRealStation = (startStation != nil && startStation != " ") || (endStation != nil && endStation != " ")
                        
                        // 若已經被系統合法補上空白 " "，也算完整
                        let isSystemFilled = startStation == " " && endStation == " "
                        
                        return hasRouteOrPrice || hasRealStation || isSystemFilled
                    } else {
                        // 軌道運輸等必須同時有真實起訖站，且不能是系統代填的 " "
                        return startStation != nil && endStation != nil && startStation != " " && endStation != " "
                    }
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
    
    /// V2：解析語音文字，支援多段行程（轉乘）
    /// 回傳 `[ParsedTrip]`，單段行程時陣列長度為 1
    static func parse(_ rawText: String) -> [ParsedTrip] {
        // 1. 文字正規化
        let normalized = normalizeText(rawText)
        
        // 2. 切割多段行程
        let segmentTexts = splitIntoSegments(normalized)
        
        // 3. 逐段獨立解析
        var results = segmentTexts.map { parseSingleSegment($0) }
        
        // 4. 原始文字放入第一段備註
        if !results.isEmpty {
            results[0].note = rawText
        }
        
        // 5. 上下文推論與轉乘標記（從 index 1 開始）
        for i in 1..<results.count {
            // 起點推論：若缺乏起點，帶入上一段終點
            if results[i].startStation == nil, let prevEnd = results[i - 1].endStation {
                var inheritedStart = prevEnd

                // 跨運具補全：前段軌道 -> 本段公車/客運時，自動加上「捷運」前綴與「站」後綴
                let prevTransport = results[i - 1].transportType
                let currTransport = results[i].transportType ?? inferTransportFromRouteId(results[i].routeId ?? "")
                let isPrevRail = prevTransport == .mrt || prevTransport == .tymrt || prevTransport == .tcmrt || prevTransport == .kmrt
                let isCurrBus = currTransport == .bus || currTransport == .coach

                if isPrevRail && isCurrBus {
                    if !inheritedStart.hasPrefix("捷運") { inheritedStart = "捷運" + inheritedStart }
                    if !inheritedStart.hasSuffix("站") { inheritedStart += "站" }
                }

                // 跨運具清理：前段公車/客運 -> 本段軌道時，清除冗餘前後綴，避免站名分數下降
                let isPrevBus = prevTransport == .bus || prevTransport == .coach
                let isCurrRail = currTransport == .mrt || currTransport == .tymrt || currTransport == .tcmrt || currTransport == .kmrt || currTransport == .tra || currTransport == .hsr || currTransport == .lrt

                if isPrevBus && isCurrRail {
                    inheritedStart = removeTransportKeywords(inheritedStart)
                    inheritedStart = resolveStationAlias(inheritedStart)
                    inheritedStart = normalizeStationByTransport(inheritedStart, transport: currTransport)
                }

                results[i].startStation = inheritedStart
                // 線路代碼推論：若有上一段終點線路，帶入本段起點線路
                if results[i].startLineCode == nil {
                    results[i].startLineCode = results[i - 1].endLineCode ?? results[i - 1].startLineCode
                }
                // 補上站名信心（繼承上一段的部分信心）
                if results[i].stationScore < 0.3 {
                    results[i].stationScore = max(results[i].stationScore, results[i - 1].stationScore * 0.7)
                }
            }
            
            // 運具推論：若缺乏運具但有路線號，預設為公車
            if results[i].transportType == nil,
               let routeId = results[i].routeId,
               let inferred = inferTransportFromRouteId(routeId) {
                results[i].transportType = inferred
                results[i].transportScore = max(results[i].transportScore, 0.8)
            }
            
            // 時間推論：若缺乏時間，帶入上一段的時間
            if results[i].date == nil {
                results[i].date = results[i - 1].date
            }
            if results[i].time == nil {
                results[i].time = results[i - 1].time
            }
            
            // 轉乘標記
            results[i].isTransfer = true
            
            // 原始文字備註
                        results[i].note = rawText
                        
                        // 重新計算一致性
                        results[i].consistencyScore = calculateConsistency(results[i])
                    }
                    
        // 💡 6. 最終防呆處理：針對允許無起訖站的運具，審核是否滿足「免站名儲存條件」
                for i in 0..<results.count {
                    let type = results[i].transportType
                    let isStationlessAllowed = type == .bus || type == .coach || type == .bike || type == .ferry
                    
                    if isStationlessAllowed {
                        // 條件：檢查是否有「路線號碼」或「金額」，或者至少講了一個「站名」
                        let hasRouteOrPrice = results[i].routeId != nil || results[i].price != nil
                        let hasAnyStation = results[i].startStation != nil || results[i].endStation != nil
                        
                        // 必須滿足上述條件，才幫他補上一個空白字元 " " 繞過 UI 的 isEmpty 阻擋
                        if hasRouteOrPrice || hasAnyStation {
                            if results[i].startStation == nil {
                                results[i].startStation = " " // 改成一個空白
                            }
                            if results[i].endStation == nil {
                                results[i].endStation = " " // 改成一個空白
                            }
                        }
                        // ⚠️ 若什麼條件都沒滿足（例如只說了「搭公車」），則保持 nil。
                        // 這樣 UI 發現是 nil，就會正常觸發「點擊填寫補完才能儲存」！
                    }
                }
                
                return results
            }
    
    // MARK: - 句子切割
    
    /// 利用轉乘關鍵字將長句切割為多段行程文字
    private static func splitIntoSegments(_ text: String) -> [String] {
        // 💡 隱式轉乘預處理：當「站、樓」等字尾後直接接新運具/路線時，自動插入「轉乘」
        let implicitPattern = "([站樓院區市心])(\\s*)(\\d{1,4}[A-Za-z]?(?:公車|市公車|客運|巴士)|捷運|台鐵|高鐵|輕軌)"
        var processedText = text
        if let regex = try? NSRegularExpression(pattern: implicitPattern, options: []) {
            let nsRange = NSRange(text.startIndex..., in: text)
            processedText = regex.stringByReplacingMatches(in: text, options: [], range: nsRange, withTemplate: "$1轉乘$3")
        }

        let transferKeywords = rules.multiSegmentKeywords.transferKeywords
        
        // 建構正則：用轉乘關鍵字作為分割點
        // 按長度降序排列，避免短詞先匹配
        let sortedKeywords = transferKeywords.sorted { $0.count > $1.count }
        let escapedKeywords = sortedKeywords.map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "(" + escapedKeywords.joined(separator: "|") + ")"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [processedText]
        }
        
        let nsRange = NSRange(processedText.startIndex..., in: processedText)
        let matches = regex.matches(in: processedText, options: [], range: nsRange)
        
        guard !matches.isEmpty else {
            return [processedText]
        }
        
        var segments: [String] = []
        var lastEnd = processedText.startIndex
        
        for match in matches {
            guard let range = Range(match.range, in: processedText) else { continue }
            let segment = String(processedText[lastEnd..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty {
                segments.append(segment)
            }
            lastEnd = range.upperBound
        }
        
        // 最後一段
        let lastSegment = String(processedText[lastEnd...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastSegment.isEmpty {
            segments.append(lastSegment)
        }
        
        // 若切割結果為空，回傳原文
        return segments.isEmpty ? [processedText] : segments
    }
    
    // MARK: - 單段解析
    
    /// 解析單一段落文字，抽取運具、路線、價格、站名、時間
    private static func parseSingleSegment(_ normalized: String) -> ParsedTrip {
        var result = ParsedTrip()
        
        // 運具抽取
        let (transport, transportConfidence) = extractTransport(normalized)
        result.transportType = transport
        result.transportScore = transportConfidence
        
        // 路線抽取（先抽取，避免後續站名清理影響）
        result.routeId = extractRouteId(normalized, transport: transport)

        // 運具反向推論：若未辨識運具但有路線號，依數字長度推論公車/客運
        if result.transportType == nil,
           let routeId = result.routeId,
           let inferred = inferTransportFromRouteId(routeId) {
            result.transportType = inferred
            result.transportScore = max(result.transportScore, 0.8)
        }
        
        // 價格抽取
        let (price, priceConfidence) = extractPrice(normalized)
        result.price = price
        result.priceScore = priceConfidence
        
        // 起迄站抽取
                let resolvedTransport = result.transportType
                let (start, end, stationConfidence) = extractStations(normalized, transport: resolvedTransport)
                result.startStation = start
                result.endStation = end
                
            // 💡 新增：特例處理，公車、客運、腳踏車、渡輪可以沒有起訖站
            let isStationlessAllowed = resolvedTransport == .bus || resolvedTransport == .coach || resolvedTransport == .bike || resolvedTransport == .ferry
                
            if isStationlessAllowed {
                if start == nil && end == nil {
                    // 如果完全沒有站名：有路線號碼給 1.0 滿分，什麼都沒有給 0.8
                    result.stationScore = result.routeId != nil ? 1.0 : 0.8
                } else {
                    // 如果有提供單邊或雙邊站名，分數拉高保障及格
                    result.stationScore = max(stationConfidence, 0.9)
                }
            } else {
                result.stationScore = stationConfidence
            }

            // 線路代碼推論（捷運轉乘上下文可用）
        if let startStation = result.startStation {
            result.startLineCode = resolveLineCode(for: startStation, transport: resolvedTransport)
        }
        if let endStation = result.endStation {
            result.endLineCode = resolveLineCode(for: endStation, transport: resolvedTransport)
        }
        
        // 時間抽取
        let (date, time, timeConfidence) = extractDateTime(normalized)
        result.date = date
        result.time = time
        result.timeScore = timeConfidence
        
        // 一致性分數
        result.consistencyScore = calculateConsistency(result)
        
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

        // 處理時間格式：「X點」「X分」
        let timePattern = try? NSRegularExpression(pattern: "([\(digitChars)]+)(點|分)", options: [])
        if let timePattern {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = timePattern.matches(in: result, options: [], range: nsRange)
            for match in matches.reversed() {
                guard let numRange = Range(match.range(at: 1), in: result) else { continue }
                let chineseNum = String(result[numRange])
                if let arabicNum = chineseToArabic(chineseNum),
                   let suffixRange = Range(match.range(at: 2), in: result) {
                    let fullRange = Range(match.range, in: result)!
                    let suffix = String(result[suffixRange])
                    result.replaceSubrange(fullRange, with: "\(arabicNum)\(suffix)")
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

    private static func parseTransportType(from text: String, rules: VoiceNLPRules) -> TransportType? {
        let lowercasedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // --- 0. 數字開頭自動判定 (最高優先級) ---
        // 規則：3碼(含)以下為公車，4碼(含)以上為客運
        let numberPattern = "^([0-9]{1,})"
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           let match = regex.firstMatch(in: lowercasedText, range: NSRange(lowercasedText.startIndex..., in: lowercasedText)),
           let range = Range(match.range(at: 1), in: lowercasedText) {
            let numStr = String(lowercasedText[range])
            if numStr.count >= 4 { return .coach }
            return .bus
        }

        // --- 1. 強綁定 (Explicit Intent) ---

        // A. 動詞強綁定 (有明確動詞)
        let verbs = ["搭", "坐", "轉", "搭乘", "換"]
        for rule in rules.transports {
            guard let type = TransportType(rawValue: rule.id) else { continue }
            for keyword in rule.keywords {
                for verb in verbs {
                    if lowercasedText.contains("\(verb)\(keyword.lowercased())") {
                        return type
                    }
                }
            }
        }

        // B. 路線號碼強綁定 (針對「284公車」、「綠1客運」這種沒有動詞的直述句)
        if lowercasedText.range(of: "[0-9]+[a-zA-Z]*(路|號)?\\s*(公車|市公車|客運|巴士)", options: .regularExpression) != nil {
            if lowercasedText.contains("客運") { return .coach }
            return .bus
        }

        // C. 特別保留：口語中常直接說「機捷」作為開頭
        if lowercasedText.contains("機捷") || lowercasedText.contains("機場捷運") {
            return .tymrt
        }

        // --- 2. 關鍵字比對與地標降權 (Landmark Penalty) ---
        var candidates: [(TransportType, Int)] = []

        for rule in rules.transports {
            guard let type = TransportType(rawValue: rule.id) else { continue }
            for keyword in rule.keywords {
                let lowerKeyword = keyword.lowercased()
                if lowercasedText.contains(lowerKeyword) {
                    var currentPriority = rule.priority

                    // 【精準降權邏輯】限制最多往後找 8 個字，且「絕對不能」跨越「到、至、往、->」等方向詞。
                    // 這樣「公車...到...捷運站」中的公車就絕對不會被誤降權。
                    let pattern = "\(lowerKeyword)[^到至往→]{0,8}站"
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       regex.firstMatch(in: lowercasedText, range: NSRange(lowercasedText.startIndex..., in: lowercasedText)) != nil {
                        currentPriority += 10
                    }

                    candidates.append((type, currentPriority))
                    break // 該運具只要中一個 keyword 就記下來並計算優先級
                }
            }
        }

        // 優先權排序 (數字越小越優先)
        candidates.sort { $0.1 < $1.1 }
        return candidates.first?.0
    }
    
    private static func extractTransport(_ text: String) -> (TransportType?, Double) {
        if let type = parseTransportType(from: text, rules: rules) {
            return (type, 1.0)
        }
        return (nil, 0.0)
    }
    
    // MARK: - 路線抽取

    private static func inferTransportFromRouteId(_ routeId: String) -> TransportType? {
        let cleaned = routeId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard !cleaned.isEmpty,
              cleaned.allSatisfy({ $0.isNumber }) else {
            return nil
        }

        if cleaned.count <= 3 { return .bus }
        return .coach
    }
    
    private static func extractRouteId(_ text: String, transport: TransportType?) -> String? {
        // 針對輕軌的專屬處理
        if transport == .lrt || transport == nil {
            let lrtPattern = try? NSRegularExpression(pattern: "(淡海輕軌|安坑輕軌|高雄輕軌|環狀輕軌)", options: [])
            if let match = lrtPattern?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return String(text[range])
            }
            if transport == .lrt {
                return nil
            }
        }

        guard transport == nil || transport == .bus || transport == .coach else { return nil }
        
        // 先移除時間格式，避免誤抓
                // 修正：加入 \. 支援以及 (?!\d) 負向先行斷言，確保不會把 307 的 30 誤刪
            let timeRegex = try? NSRegularExpression(
                pattern: "\\d{1,2}\\s*(?:點|:|\\.)\\s*(?:\\d{1,2}(?!\\d))?\\s*(?:分)?",
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

                // 基本清理（移除從/到、時間前綴、路線號碼等）
                startName = sanitizeStationCandidate(startName, transport: transport)
                endName = sanitizeStationCandidate(endName, transport: transport)

                // 公車/客運保留完整站名，不做侵入性清理
                if transport != .bus && transport != .coach {
                    // 只有軌道交通才移除「捷運」等運具關鍵字
                    startName = removeTransportKeywords(startName)
                    endName = removeTransportKeywords(endName)

                    // 只有軌道交通才套用別名映射（可能包含去尾字）
                    startName = resolveStationAlias(startName)
                    endName = resolveStationAlias(endName)

                    // 只有軌道交通才做運具專屬站名補全
                    startName = normalizeStationByTransport(startName, transport: transport)
                    endName = normalizeStationByTransport(endName, transport: transport)
                }
                
                // 台鐵站名統一格式
                if transport == .tra {
                    startName = normalizeTRAStationName(startName)
                    endName = normalizeTRAStationName(endName)
                }

                // 模糊容錯後回填為資料庫標準站名（台/臺、站字等）
                startName = normalizeStationForValidation(startName, transport: transport)
                endName = normalizeStationForValidation(endName, transport: transport)
                
                // 至少要有一個站名
                guard !startName.isEmpty || !endName.isEmpty else { continue }
                
                let finalStart: String? = startName.isEmpty ? nil : startName
                let finalEnd: String? = endName.isEmpty ? nil : endName
                
                // 驗證站名
                let startValid = finalStart.map { validateStation($0, transport: transport) } ?? false
                let endValid = finalEnd.map { validateStation($0, transport: transport) } ?? false
                
                let score: Double
                if startValid && endValid {
                    score = 1.0
                } else if startValid || endValid {
                    score = 0.7
                } else if finalStart != nil && finalEnd != nil {
                    score = 0.4
                } else {
                    score = 0.3
                }
                
                return (finalStart, finalEnd, score)
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

            var previousResult = ""
            let digitChars = chineseDigitMap.keys.map { String($0) }.joined()

            // 建立所有要移除的噪音正則表達式
                var prefixPatterns: [String] = [
                    // 1. 標點符號與空白 (解決 ASR 產生的 ".3" 或逗號等殘留)
                    "^[.,:;?!。，：；？！\\s]+",

                    // 2. 日期前綴
                    "^(?:昨天|今天|明天|後天|今年|去年|明年|本週|下週|上週|\\d{1,2}月\\d{1,2}日)",

                    // 3. 時間前綴 (💡 修正：加入 \. 支援以及 (?!\d) 邊界檢查)
                    "^(?:昨天|今天|明天|後天|前天|大前天)?\\s*(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)\\s*\\d{1,2}\\s*(?:點|:|\\.)\\s*(?:\\d{1,2}(?!\\d))?\\s*(?:分)?",
                    "^(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)",
                    "^\\d{1,2}\\s*(?:點|:|\\.)\\s*(?:\\d{1,2}(?!\\d))?\\s*(?:分)?",

                    // 4. 語音常見引導詞
                    "^(?:從|由|在|自|搭|坐)"
                ]

            // 5. 路線號碼前綴 (僅限公車/客運)
            if transport == .bus || transport == .coach {
                prefixPatterns.append("^[A-Za-z0-9]{1,6}(?:路|號)?")
                prefixPatterns.append("^[\(digitChars)0-9]{1,6}\\s*(?:號|路)?")
            }

            // 6. 運具前綴
            if transport == .bus || transport == .coach {
                // 💡 公車/客運模式：只移除公車客運相關前綴，【嚴格保留】捷運、火車、高鐵等轉乘地標字眼
                prefixPatterns.append("^(?:公車|市公車|客運|巴士|國道客運)+")
            } else {
                // 軌道運具模式：移除所有運具類別字眼
                prefixPatterns.append("^(?:淡海輕軌|安坑輕軌|高雄輕軌|環狀輕軌|輕軌|公車|市公車|客運|巴士|國道客運|捷運|火車|台鐵|高鐵)+")
            }

            // 💡 核心修復：循環移除，直到沒有匹配項目為止（解決「公車307」與「307公車」交錯出現的問題）
            while result != previousResult {
                previousResult = result

                for pattern in prefixPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let nsRange = NSRange(result.startIndex..., in: result)
                        if let match = regex.firstMatch(in: result, options: [], range: nsRange),
                           let range = Range(match.range, in: result) {
                            result.removeSubrange(range)
                            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
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
        let candidates = stationValidationCandidates(for: name)

        func matchesAny(_ stationList: [String]) -> Bool {
            for candidate in candidates where stationList.contains(candidate) {
                return true
            }
            return false
        }

        switch transport {
        case .mrt:
            return StationData.shared.lines.contains(where: { matchesAny($0.stations) })
        case .tymrt:
            return matchesAny(TYMRTStationData.shared.line.stations)
        case .tcmrt:
            return TCMRTStationData.shared.lines.contains(where: { matchesAny($0.stations) })
        case .kmrt:
            return KMRTStationData.shared.lines.contains(where: { matchesAny($0.stations) })
        case .bus, .coach:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tra:
            return candidates.contains(where: { TRAStationData.shared.resolveStationID(normalizeTRAStationName($0)) != nil })
        case .hsr:
            return matchesAny(HSRStationData.shared.line.stations)
        default:
            if StationData.shared.lines.contains(where: { matchesAny($0.stations) }) { return true }
            if matchesAny(TYMRTStationData.shared.line.stations) { return true }
            if TCMRTStationData.shared.lines.contains(where: { matchesAny($0.stations) }) { return true }
            if KMRTStationData.shared.lines.contains(where: { matchesAny($0.stations) }) { return true }
            if candidates.contains(where: { TRAStationData.shared.resolveStationID(normalizeTRAStationName($0)) != nil }) { return true }
            if matchesAny(HSRStationData.shared.line.stations) { return true }
            return false
        }
    }

    @MainActor
    private static func normalizeStationForValidation(_ name: String, transport: TransportType?) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let candidates = stationValidationCandidates(for: trimmed)

        func firstMatchedStation(in stationList: [String]) -> String? {
            for candidate in candidates {
                if let exact = stationList.first(where: { $0 == candidate }) {
                    return exact
                }
            }
            return nil
        }

        switch transport {
        case .mrt:
            for line in StationData.shared.lines {
                if let matched = firstMatchedStation(in: line.stations) { return matched }
            }
            return trimmed
        case .tymrt:
            return firstMatchedStation(in: TYMRTStationData.shared.line.stations) ?? trimmed
        case .tcmrt:
            for line in TCMRTStationData.shared.lines {
                if let matched = firstMatchedStation(in: line.stations) { return matched }
            }
            return trimmed
        case .kmrt:
            for line in KMRTStationData.shared.lines {
                if let matched = firstMatchedStation(in: line.stations) { return matched }
            }
            return trimmed
        case .hsr:
            return firstMatchedStation(in: HSRStationData.shared.line.stations) ?? trimmed
        case .tra:
            for candidate in candidates {
                let normalized = normalizeTRAStationName(candidate)
                if TRAStationData.shared.resolveStationID(normalized) != nil {
                    return normalized
                }
            }
            return normalizeTRAStationName(trimmed)
        case .bus, .coach:
            return trimmed
        default:
            for line in StationData.shared.lines {
                if let matched = firstMatchedStation(in: line.stations) { return matched }
            }
            if let matched = firstMatchedStation(in: TYMRTStationData.shared.line.stations) { return matched }
            for line in TCMRTStationData.shared.lines {
                if let matched = firstMatchedStation(in: line.stations) { return matched }
            }
            for line in KMRTStationData.shared.lines {
                if let matched = firstMatchedStation(in: line.stations) { return matched }
            }
            if let matched = firstMatchedStation(in: HSRStationData.shared.line.stations) { return matched }

            for candidate in candidates {
                let normalized = normalizeTRAStationName(candidate)
                if TRAStationData.shared.resolveStationID(normalized) != nil {
                    return normalized
                }
            }

            return trimmed
        }
    }

    private static func stationValidationCandidates(for name: String) -> [String] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates = Set<String>()

        func addVariants(_ value: String) {
            let base = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !base.isEmpty else { return }
            candidates.insert(base)

            if base.hasSuffix("站"), base.count > 1 {
                candidates.insert(String(base.dropLast()))
            } else {
                candidates.insert(base + "站")
            }

            let toTai = base.replacingOccurrences(of: "臺", with: "台")
            let toTaiwan = base.replacingOccurrences(of: "台", with: "臺")
            candidates.insert(toTai)
            candidates.insert(toTaiwan)

            if toTai.hasSuffix("站"), toTai.count > 1 {
                candidates.insert(String(toTai.dropLast()))
            } else {
                candidates.insert(toTai + "站")
            }

            if toTaiwan.hasSuffix("站"), toTaiwan.count > 1 {
                candidates.insert(String(toTaiwan.dropLast()))
            } else {
                candidates.insert(toTaiwan + "站")
            }
        }

        addVariants(trimmed)
        return Array(candidates)
    }

    @MainActor
    private static func resolveLineCode(for station: String, transport: TransportType?) -> String? {
        let canonicalStation = normalizeStationForValidation(station, transport: transport)

        switch transport {
        case .mrt:
            return StationData.shared.lines.first(where: { $0.stations.contains(canonicalStation) })?.code
        case .tymrt:
            return TYMRTStationData.shared.line.stations.contains(canonicalStation) ? TYMRTStationData.shared.line.code : nil
        case .tcmrt:
            return TCMRTStationData.shared.lines.first(where: { $0.stations.contains(canonicalStation) })?.code
        case .kmrt:
            return KMRTStationData.shared.lines.first(where: { $0.stations.contains(canonicalStation) })?.code
        default:
            return nil
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
                    // 相對日期 + 時段 + 時間（把 (?!\d) 移入分鐘的括號內）
                    "(?:昨天|今天|明天|後天|前天|大前天)?\\s*(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)\\s*\\d{1,2}\\s*(?:點|:|\\.)\\s*(?:\\d{1,2}(?!\\d))?\\s*(?:分)?",
                    
                    // 相對日期 + 時段（無時間數字）
                    "(?:昨天|今天|明天|後天|前天|大前天)\\s*(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)",
                    
                    // 時段 + 時間（無日期，把 (?!\d) 移入分鐘的括號內）
                    "(?:凌晨|清晨|早上|上午|中午|下午|傍晚|晚上)\\s*\\d{1,2}\\s*(?:點|:|\\.)\\s*(?:\\d{1,2}(?!\\d))?\\s*(?:分)?",
                    
                    // ISO 格式日期 + 時間（結尾增加邊界檢查）
                    "\\d{4}年\\d{1,2}月\\d{1,2}日\\s*\\d{1,2}\\s*(?::|點|\\.)\\s*\\d{1,2}(?!\\d)",
                    
                    // 純時間格式（把 (?!\d) 移入分鐘的括號內）
                    "\\d{1,2}\\s*(?:點|:|\\.)\\s*(?:\\d{1,2}(?!\\d))?\\s*(?:分)?",
                    
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

        // 1. 判斷是否含有 PM 修飾詞（從 JSON 動態讀取）
        let pmWords = rules.timeSemantics.pmKeywords ?? ["下午", "晚上", "pm"]
        let lowerText = text.lowercased()
        let isPM = pmWords
            .map { $0.lowercased() }
            .contains(where: { lowerText.contains($0) })

        // 2. 解析相對日期
        for entry in rules.timeSemantics.relativeDays {
            if text.contains(entry.keyword) {
                dateResult = calendar.date(byAdding: .day, value: entry.dayOffset, to: Date())
                confidence = max(confidence, 0.9)
                break
            }
        }

        // 3. 解析精確時間：「X點Y分」「X:Y」
            let timeRegex = try? NSRegularExpression(
                // 關鍵修復：將分鐘部分改為 (?:(\\d{1,2})(?!\\d))?
                // 這樣如果遇到 3.307，分鐘抓不到沒關係，它會快樂地把 "3." 當作小時抓下來，留下 307
                pattern: "(\\d{1,2})\\s*(?:點|:|\\.)\\s*(?:(\\d{1,2})(?!\\d))?\\s*(?:分)?",
                options: []
                )

        if let timeRegex {
            let nsRange = NSRange(text.startIndex..., in: text)
            if let match = timeRegex.firstMatch(in: text, options: [], range: nsRange),
               let hourRange = Range(match.range(at: 1), in: text),
               var hour = Int(text[hourRange]), hour >= 0, hour < 24 {

                // 關鍵修復：PM 偏移邏輯
                if isPM && hour < 12 {
                    hour += 12
                }

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

        // 4. 若無精確時間，才解析概略時段
        if timeResult == nil {
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
        }
        
        // 都沒偵測到 → 使用預設時間（現在），不扣分
        if dateResult == nil && timeResult == nil {
            confidence = 1.0
        }
        
        return (dateResult, timeResult, confidence)
    }
    
    // MARK: - 一致性分數
        
        private static func calculateConsistency(_ parsed: ParsedTrip) -> Double {
            var score = 0.5
            
            let isStationlessAllowed = parsed.transportType == .bus || parsed.transportType == .coach || parsed.transportType == .bike || parsed.transportType == .ferry
            
            if parsed.transportType != nil {
                if parsed.startStation != nil && parsed.endStation != nil {
                    // 一般情況：有起訖站給予完整一致性加分
                    score += 0.3
                } else if isStationlessAllowed {
                    // 特例運具：如果只有單邊站名，或是只有路線號碼（例如"284公車"），一樣給予完整加分
                    if parsed.routeId != nil || parsed.startStation != nil || parsed.endStation != nil {
                        score += 0.3
                    } else {
                        // 只有「公車」兩個字什麼都沒講，給一半加分
                        score += 0.15
                    }
                }
            }
            
            if let price = parsed.price, price >= 0, price <= 5000 {
                score += 0.2
            }
            
            return min(score, 1.0)
        }
}
