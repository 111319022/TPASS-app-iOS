import Foundation
import CloudKit

/// 語音解析修正紀錄上傳服務
///
/// 將使用者對語音辨識結果的修正匿名回傳至 CloudKit Public Database，
/// 作為後續優化語音模型的數據來源。
///
/// **隱私原則**：
/// - 不上傳任何 Apple ID、Device ID 等個人可識別資訊
/// - 僅記錄語音轉寫文字、解析結果、最終修正結果
/// - 使用 Public Database（不需要使用者登入 iCloud）
///
/// **Record Type**: `VoiceParseLog`
/// **欄位**:
/// - `originalTranscript` (String): 原始語音轉寫文字
/// - `parsedResult` (String): 解析結果 JSON（運具、站點、票價、信心分數）
/// - `finalResult` (String): 使用者最終確認的結果 JSON
/// - `isCorrected` (Int64): 0 = 使用者未修改解析結果，1 = 有修改
/// - `overallScore` (Double): 解析信心總分
/// - `appVersion` (String): App 版本號
/// - `rulesVersion` (String): VoiceNLP_Rules.json 版本號
final class VoiceParseLogService {
    
    static let shared = VoiceParseLogService()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.tpass-app.tpasscalc")
        publicDatabase = container.publicCloudDatabase
    }
    
    // MARK: - 公開 API
    
    /// 上傳語音解析紀錄
    ///
    /// - Parameters:
    ///   - originalTranscript: 原始語音轉寫文字
    ///   - draft: 語音解析產生的 VoiceDraft（解析階段的結果）
    ///   - finalTripData: 使用者最終確認的行程資料
    ///
    /// - Note: 此方法應在背景呼叫，錯誤時靜默處理
    func logParseResult(
        originalTranscript: String,
        draft: VoiceDraft,
        finalTripData: [String: Any]
    ) async {
        do {
            let record = CKRecord(recordType: "VoiceParseLog")
            
            // 原始轉寫（截斷過長的文字，避免佔用過多空間）
            record["originalTranscript"] = String(originalTranscript.prefix(500)) as CKRecordValue
            
            // 解析結果 JSON
            let parsedDict = buildParsedResultDict(from: draft)
            if let parsedJSON = try? JSONSerialization.data(withJSONObject: parsedDict),
               let parsedString = String(data: parsedJSON, encoding: .utf8) {
                record["parsedResult"] = parsedString as CKRecordValue
            }
            
            // 最終結果 JSON（移除可能包含的個人資訊 key）
            let sanitizedFinal = sanitizeFinalData(finalTripData)
            if let finalJSON = try? JSONSerialization.data(withJSONObject: sanitizedFinal),
               let finalString = String(data: finalJSON, encoding: .utf8) {
                record["finalResult"] = finalString as CKRecordValue
            }
            
            // 是否有修正
            let corrected = detectCorrection(draft: draft, finalData: finalTripData)
            record["isCorrected"] = (corrected ? 1 : 0) as CKRecordValue
            
            // 信心分數
            record["overallScore"] = draft.overallScore as CKRecordValue
            
            // App 版本
            record["appVersion"] = appVersion as CKRecordValue
            
            // 規則版本
            record["rulesVersion"] = (TripVoiceParser.rules as Any is VoiceNLPRules ? "1.0.0" : "unknown") as CKRecordValue
            
            _ = try await publicDatabase.save(record)
        } catch {
            // 靜默處理：僅在 debug 模式輸出
            #if DEBUG
            print("[VoiceParseLog] 上傳失敗: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - 內部方法
    
    /// 將 VoiceDraft 的關鍵欄位轉為字典
    private func buildParsedResultDict(from draft: VoiceDraft) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let type = draft.transportType {
            dict["transportType"] = type.rawValue
        }
        if let start = draft.startStation {
            dict["startStation"] = start
        }
        if let end = draft.endStation {
            dict["endStation"] = end
        }
        if let price = draft.price {
            dict["price"] = price
        }
        if let routeId = draft.routeId {
            dict["routeId"] = routeId
        }
        
        // 信心分數
        dict["stationScore"] = draft.stationScore
        dict["transportScore"] = draft.transportScore
        dict["priceScore"] = draft.priceScore
        dict["timeScore"] = draft.timeScore
        dict["consistencyScore"] = draft.consistencyScore
        dict["overallScore"] = draft.overallScore
        
        return dict
    }
    
    /// 移除可能包含的個人資訊 key
    private func sanitizeFinalData(_ data: [String: Any]) -> [String: Any] {
        let sensitiveKeys = ["userId", "user_id", "appleId", "deviceId", "email", "name"]
        return data.filter { !sensitiveKeys.contains($0.key) }
    }
    
    /// 偵測使用者是否修正了解析結果
    private func detectCorrection(draft: VoiceDraft, finalData: [String: Any]) -> Bool {
        // 比對運具
        if let finalTypeRaw = finalData["transportType"] as? String,
           let draftType = draft.transportType,
           finalTypeRaw != draftType.rawValue {
            return true
        }
        
        // 比對起站
        if let finalStart = finalData["startStation"] as? String,
           finalStart != (draft.startStation ?? "") {
            return true
        }
        
        // 比對終站
        if let finalEnd = finalData["endStation"] as? String,
           finalEnd != (draft.endStation ?? "") {
            return true
        }
        
        // 比對票價
        if let finalPrice = finalData["price"] as? Int,
           finalPrice != (draft.price ?? -1) {
            return true
        }
        
        // 比對路線
        if let finalRoute = finalData["routeId"] as? String,
           finalRoute != (draft.routeId ?? "") {
            return true
        }
        
        return false
    }
    
    /// 取得 App 版本號
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
