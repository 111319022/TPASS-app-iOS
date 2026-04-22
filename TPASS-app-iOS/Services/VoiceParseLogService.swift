import Foundation
import CloudKit

/// 語音解析紀錄上傳服務
///
/// 將語音辨識的成功與失敗結果匿名回傳至 CloudKit Public Database，
/// 作為後續優化語音模型的數據來源。
///
/// **隱私原則**：
/// - 不上傳任何 Apple ID、Device ID 等個人可識別資訊
/// - 僅記錄語音轉寫文字、解析結果、最終修正結果
/// - 使用 Public Database（不需要使用者登入 iCloud）
///
/// **Record Type**: `VoiceParseLog`
/// **欄位**:
/// - `status` (String): "success" | "failed" | "abandoned" — 區分成功儲存、辨識失敗、辨識成功但放棄儲存
/// - `failureReason` (String): 失敗原因（僅 status=failed 時有值）
///   可能值: "empty_transcript", "multi_segment", "low_confidence", "missing_fields"
/// - `originalTranscript` (String): 原始語音轉寫文字
/// - `parsedResult` (String): 解析結果 JSON（運具、站點、票價、信心分數）
/// - `finalResult` (String): 使用者最終確認的結果 JSON（僅 status=success 時有值）
/// - `isCorrected` (Int64): 0 = 無修改, 1 = 有修改（僅 status=success 時有意義）
/// - `overallScore` (Double): 解析信心總分
/// - `appVersion` (String): App 版本號
/// - `rulesVersion` (String): VoiceNLP_Rules.json 版本號
final class VoiceParseLogService {
    
    static let shared = VoiceParseLogService()
    
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    
    /// 失敗原因列舉
    enum FailureReason: String {
        case emptyTranscript = "empty_transcript"     // 語音辨識無輸出
        case multiSegment    = "multi_segment"         // 偵測到多段行程
        case lowConfidence   = "low_confidence"        // 信心分數過低
        case missingFields   = "missing_fields"        // 必要欄位不完整
    }
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.tpass-app.tpasscalc")
        publicDatabase = container.publicCloudDatabase
    }
    
    // MARK: - 公開 API
    
    /// 上傳成功的語音解析紀錄（使用者確認儲存後呼叫）
    ///
    /// - Parameters:
    ///   - originalTranscript: 原始語音轉寫文字
    ///   - draft: 語音解析產生的 VoiceDraft（解析階段的結果）
    ///   - finalTripData: 使用者最終確認的行程資料
    ///
    /// - Note: 應在背景 Task 呼叫，錯誤時靜默處理
    func logParseResult(
        originalTranscript: String,
        draft: VoiceDraft,
        finalTripData: [String: Any]
    ) async {
        do {
            let record = buildBaseRecord(
                transcript: originalTranscript,
                draft: draft
            )
            
            // 標記為成功
            record["status"] = "success" as CKRecordValue
            record["failureReason"] = "" as CKRecordValue
            
            // 最終結果 JSON
            let sanitizedFinal = sanitizeFinalData(finalTripData)
            if let finalJSON = try? JSONSerialization.data(withJSONObject: sanitizedFinal),
               let finalString = String(data: finalJSON, encoding: .utf8) {
                record["finalResult"] = finalString as CKRecordValue
            }
            
            // 是否有修正
            let corrected = detectCorrection(draft: draft, finalData: finalTripData)
            record["isCorrected"] = (corrected ? 1 : 0) as CKRecordValue
            
            _ = try await publicDatabase.save(record)
        } catch {
            #if DEBUG
            print("[VoiceParseLog] 成功紀錄上傳失敗: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// 上傳失敗的語音解析紀錄（辨識不完整、信心過低、多段行程等）
    ///
    /// - Parameters:
    ///   - originalTranscript: 原始語音轉寫文字（可能為空字串）
    ///   - draft: 語音解析產生的 VoiceDraft（可能為 nil，例如空轉寫時）
    ///   - reason: 失敗原因
    ///
    /// - Note: 應在背景 Task 呼叫，錯誤時靜默處理
    func logFailedParse(
        originalTranscript: String,
        draft: VoiceDraft?,
        reason: FailureReason
    ) async {
        do {
            let record = buildBaseRecord(
                transcript: originalTranscript,
                draft: draft
            )
            
            // 標記為失敗
            record["status"] = "failed" as CKRecordValue
            record["failureReason"] = reason.rawValue as CKRecordValue
            
            // 失敗紀錄無最終結果
            record["finalResult"] = "" as CKRecordValue
            record["isCorrected"] = 0 as CKRecordValue
            
            _ = try await publicDatabase.save(record)
        } catch {
            #if DEBUG
            print("[VoiceParseLog] 失敗紀錄上傳失敗: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// 上傳「已辨識但使用者放棄儲存」的紀錄
    ///
    /// 當使用者成功進入預覽階段（draft 不為 nil）但最終關閉選單未儲存時呼叫。
    /// status = "abandoned"，finalResult 留空。
    ///
    /// - Parameters:
    ///   - originalTranscript: 原始語音轉寫文字
    ///   - draft: 解析產生的 VoiceDraft
    func logAbandonedParse(
        originalTranscript: String,
        draft: VoiceDraft
    ) async {
        do {
            let record = buildBaseRecord(
                transcript: originalTranscript,
                draft: draft
            )
            
            record["status"] = "abandoned" as CKRecordValue
            record["failureReason"] = "" as CKRecordValue
            record["finalResult"] = "" as CKRecordValue
            record["isCorrected"] = 0 as CKRecordValue
            
            _ = try await publicDatabase.save(record)
        } catch {
            #if DEBUG
            print("[VoiceParseLog] 放棄紀錄上傳失敗: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - 內部方法
    
    /// 建構共用的 CKRecord 基礎欄位
    private func buildBaseRecord(transcript: String, draft: VoiceDraft?) -> CKRecord {
        let record = CKRecord(recordType: "VoiceParseLog")
        
        // 原始轉寫（截斷避免過長）
        record["originalTranscript"] = String(transcript.prefix(500)) as CKRecordValue
        
        // 解析結果 JSON
        if let draft {
            let parsedDict = buildParsedResultDict(from: draft)
            if let parsedJSON = try? JSONSerialization.data(withJSONObject: parsedDict),
               let parsedString = String(data: parsedJSON, encoding: .utf8) {
                record["parsedResult"] = parsedString as CKRecordValue
            }
            record["overallScore"] = draft.overallScore as CKRecordValue
        } else {
            record["parsedResult"] = "" as CKRecordValue
            record["overallScore"] = 0.0 as CKRecordValue
        }
        
        // App 版本
        record["appVersion"] = appVersion as CKRecordValue
        
        // 規則版本
        record["rulesVersion"] = rulesVersion as CKRecordValue
        
        return record
    }
    
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
        if let finalTypeRaw = finalData["transportType"] as? String,
           let draftType = draft.transportType,
           finalTypeRaw != draftType.rawValue {
            return true
        }
        
        if let finalStart = finalData["startStation"] as? String,
           finalStart != (draft.startStation ?? "") {
            return true
        }
        
        if let finalEnd = finalData["endStation"] as? String,
           finalEnd != (draft.endStation ?? "") {
            return true
        }
        
        if let finalPrice = finalData["price"] as? Int,
           finalPrice != (draft.price ?? -1) {
            return true
        }
        
        if let finalRoute = finalData["routeId"] as? String,
           finalRoute != (draft.routeId ?? "") {
            return true
        }
        
        return false
    }
    
    /// App 版本號
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
    
    /// VoiceNLP_Rules.json 版本號
    private var rulesVersion: String {
        TripVoiceParser.rules._meta?.version ?? "unknown"
    }
}
