import Foundation

/// 語音草稿：語音解析結果的中介層，確認後才轉為正式 Trip
struct VoiceDraft: Identifiable {
    let id: UUID
    let createdAt: Date
    
    // 原始資料
    var originalTranscript: String
    
    // 解析後欄位
    var transportType: TransportType?
    var startStation: String?
    var endStation: String?
    var price: Int?
    var routeId: String?
    var tripDate: Date?
    var tripTime: Date?
    var note: String?
    var isTransfer: Bool
    
    // 信心分數
    var stationScore: Double
    var transportScore: Double
    var priceScore: Double
    var timeScore: Double
    var consistencyScore: Double
    var overallScore: Double
    
    // 狀態
    var status: DraftStatus
    
    enum DraftStatus: String {
        case draft          // 草稿，待確認
        case needsReview    // 需要人工檢視
        case readyToSave    // 已確認，可儲存
        case expired        // 過期（7天未處理）
    }
    
    /// 是否可直接建立 Trip
    var canCreateTrip: Bool {
        transportType != nil && startStation != nil && endStation != nil
    }
    
    /// 建立空白 VoiceDraft（用於手動新增段落）
    static func empty() -> VoiceDraft {
        VoiceDraft(
            id: UUID(),
            createdAt: Date(),
            originalTranscript: "",
            transportType: nil,
            startStation: nil,
            endStation: nil,
            price: nil,
            routeId: nil,
            tripDate: nil,
            tripTime: nil,
            note: nil,
            isTransfer: true,
            stationScore: 0,
            transportScore: 0,
            priceScore: 0,
            timeScore: 0,
            consistencyScore: 0,
            overallScore: 0,
            status: .draft
        )
    }
    
    /// 從 ParsedTrip 建立 VoiceDraft
    static func from(parsed: TripVoiceParser.ParsedTrip, transcript: String) -> VoiceDraft {
        let status: DraftStatus
        if parsed.isHighConfidence && parsed.hasRequiredFields {
            status = .readyToSave
        } else if parsed.isMediumConfidence {
            status = .needsReview
        } else {
            status = .draft
        }
        
        return VoiceDraft(
            id: UUID(),
            createdAt: Date(),
            originalTranscript: transcript,
            transportType: parsed.transportType,
            startStation: parsed.startStation,
            endStation: parsed.endStation,
            price: parsed.price,
            routeId: parsed.routeId,
            tripDate: parsed.date,
            tripTime: parsed.time,
            note: parsed.note,
            isTransfer: parsed.isTransfer,
            stationScore: parsed.stationScore,
            transportScore: parsed.transportScore,
            priceScore: parsed.priceScore,
            timeScore: parsed.timeScore,
            consistencyScore: parsed.consistencyScore,
            overallScore: parsed.overallScore,
            status: status
        )
    }
}
