import Foundation
import CoreNFC
import Combine

// 掃描結果的資料模型
struct NFCResult: Identifiable {
    let id = UUID()
    let uid: String      // 卡片唯一碼
    let type: String     // 卡片類型
    let info: String     // 技術細節
}

// 1. 標記 @MainActor，確保所有屬性更新都在主執行緒安全進行
@MainActor
class NFCReader: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    
    @Published var scanResult: String = "準備就緒"
    @Published var scannedCard: NFCResult?
    @Published var isScanning = false
    
    var session: NFCTagReaderSession?
    
    func startScanning() {
        guard NFCTagReaderSession.readingAvailable else {
            self.scanResult = "此裝置不支援 NFC"
            return
        }
        
        // 建立 Session
        // 修正：FeliCa 的正確參數是 .iso18092
        session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        session?.alertMessage = "請將卡片靠近手機背面頂端..."
        session?.begin()
        self.isScanning = true
    }
    
    // MARK: - NFCTagReaderSessionDelegate
    // 這些方法由系統在背景 Queue 呼叫，必須標記 nonisolated 以避開 Actor 隔離檢查
    
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session 已啟動，通常不需要做什麼
    }
    
    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // 發生錯誤或取消時，使用 Task 回到主執行緒更新 UI
        Task { @MainActor in
            self.isScanning = false
            // 忽略用戶手動取消的錯誤
            if let readerError = error as? NFCReaderError, readerError.code != .readerSessionInvalidationErrorUserCanceled {
                self.scanResult = "錯誤: \(error.localizedDescription)"
            }
        }
    }
    
    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        
        if tags.count > 1 {
            // 注意：這裡是背景執行緒，不能直接存取 self.session，要用傳進來的 session 參數
            session.alertMessage = "偵測到多張卡片，請保留一張再試一次。"
            session.restartPolling()
            return
        }
        
        guard let tag = tags.first else { return }
        
        // 連線到卡片 (這是一個非同步操作)
        session.connect(to: tag) { [weak self] (error: Error?) in
            if let error = error {
                session.invalidate(errorMessage: "連線失敗: \(error.localizedDescription)")
                return
            }
            
            // 讀取成功後，啟動一個 Task 回到主執行緒進行解析與 UI 更新
            Task { @MainActor in
                self?.readTagUID(tag, session: session)
            }
        }
    }
    
    // 這個方法已經在 @MainActor 環境下，可以安全更新 UI
    private func readTagUID(_ tag: NFCTag, session: NFCTagReaderSession) {
        var cardType = ""
        var cardUID = ""
        var extraInfo = ""
        
        switch tag {
        case .miFare(let tagData):
                    cardType = "MiFare (悠遊卡/一卡通)"
                    // 將 UID 加上空格，例如 "22 D2 D8 12"，看起來更像卡號
                    cardUID = tagData.identifier.map { String(format: "%02hhX", $0) }.joined(separator: " ")
                    
                    // 解析晶片家族
                    let familyName: String
                    switch tagData.mifareFamily {
                    case .unknown: familyName = "未知的 MiFare"
                    case .ultralight: familyName = "Ultralight (單程票常見)"
                    case .plus: familyName = "Plus"
                    case .desfire: familyName = "DESFire (悠遊卡/一卡通常見)"
                    @unknown default: familyName = "其他規格"
                    }
                    extraInfo = "規格: \(familyName)"
            
        case .feliCa(let tagData):
            cardType = "FeliCa (Suica)"
            cardUID = tagData.currentIDm.map { String(format: "%02hhX", $0) }.joined()
            // 這裡修正了 Optional Chaining 的括號問題
            let systemCode = tagData.currentSystemCode.map { String(format: "%02hhX", $0) }.joined()
            extraInfo = "System Code: \(systemCode)"
            
        case .iso7816(let tagData):
            cardType = "ISO 7816"
            cardUID = tagData.identifier.map { String(format: "%02hhX", $0) }.joined()
            
        case .iso15693(let tagData):
            cardType = "ISO 15693"
            cardUID = tagData.identifier.map { String(format: "%02hhX", $0) }.joined()
            
        @unknown default:
            cardType = "未知類型"
            cardUID = "讀取失敗"
        }
        
        // 更新 UI
        self.scannedCard = NFCResult(uid: cardUID.uppercased(), type: cardType, info: extraInfo)
        self.scanResult = "讀取成功"
        self.isScanning = false
        
        session.alertMessage = "讀取成功！"
        session.invalidate()
    }
}
