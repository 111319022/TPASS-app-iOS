import Foundation
import Speech
import AVFoundation
import Combine

/// 語音輸入服務：負責 iOS 語音權限管理、錄音控制、ASR 轉寫
/// 僅負責聽寫，不做業務判斷
@MainActor
final class VoiceInputService: ObservableObject {
    
    // MARK: - 狀態
    enum RecordingState: Equatable {
        case idle
        case requesting     // 正在請求權限
        case recording      // 錄音中
        case processing     // 解析中（停止錄音後短暫狀態）
        case denied         // 權限被拒絕
        case unavailable    // 裝置不支援
        case error(String)  // 錯誤
        
        static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.requesting, .requesting),
                 (.recording, .recording), (.processing, .processing),
                 (.denied, .denied), (.unavailable, .unavailable):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }
    
    @Published var state: RecordingState = .idle
    @Published var transcript: String = ""
    @Published var elapsedSeconds: Int = 0
    @Published var audioLevel: Float = 0.0  // 0.0~1.0 正規化音量，供波形 UI 使用
    
    /// 60 秒限制（iOS SFSpeechRecognizer 限制）
    static let maxDuration: Int = 55
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var timer: Timer?
    
    // MARK: - 權限檢查
    
    var isMicrophoneAuthorized: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }
    
    var isSpeechAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    var isAuthorized: Bool {
        isMicrophoneAuthorized && isSpeechAuthorized
    }
    
    // MARK: - 請求權限
    
    func requestPermissions() async -> Bool {
        state = .requesting
        
        // 1. 麥克風權限
        let micGranted: Bool
        if AVAudioApplication.shared.recordPermission == .undetermined {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            micGranted = AVAudioApplication.shared.recordPermission == .granted
        }
        
        guard micGranted else {
            state = .denied
            return false
        }
        
        // 2. 語音辨識權限
        let speechGranted: Bool
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            speechGranted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        } else {
            speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        }
        
        if !speechGranted {
            state = .denied
            return false
        }
        
        state = .idle
        return true
    }
    
    // MARK: - 開始錄音
    
    func startRecording() {
        // 重置狀態
        transcript = ""
        elapsedSeconds = 0
        
        // 初始化語音辨識器（zh-TW）
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            state = .unavailable
            return
        }
        
        // 設定 audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error("無法啟動音訊: \(error.localizedDescription)")
            return
        }
        
        // 建立辨識請求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            state = .error("無法建立辨識請求")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // 若裝置支援 on-device，優先嘗試（隱私考量）
        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = false // 不強制 on-device，讓系統選最佳
        }
        
        // 啟動辨識任務
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                
                if let error {
                    // 不在 recording 狀態時忽略錯誤（可能是正常停止）
                    if self.state == .recording {
                        print("語音辨識錯誤: \(error.localizedDescription)")
                        // 如果已有部分結果，不算錯誤
                        if self.transcript.isEmpty {
                            self.state = .error("辨識失敗: \(error.localizedDescription)")
                        }
                    }
                }
                
                if result?.isFinal == true {
                    self.stopAudioEngine()
                }
            }
        }
        
        // 設定音訊引擎
        audioEngine = AVAudioEngine()
        guard let audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // 計算音量 RMS 供波形 UI 使用
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrtf(sum / Float(max(frameLength, 1)))
            let normalized = min(1.0, rms * 5.0) // 放大並裁切到 0~1
            Task { @MainActor [weak self] in
                self?.audioLevel = normalized
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            state = .recording
            startTimer()
        } catch {
            state = .error("音訊引擎啟動失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 停止錄音
    
    func stopRecording() {
        guard state == .recording else { return }
        state = .processing
        stopAudioEngine()
    }
    
    // MARK: - 私有方法
    
    private func stopAudioEngine() {
        timer?.invalidate()
        timer = nil
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 恢復 audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        if state == .processing || state == .recording {
            state = .idle
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .recording else { return }
                self.elapsedSeconds += 1
                
                // 60秒限制防護：55秒自動停止
                if self.elapsedSeconds >= Self.maxDuration {
                    self.stopRecording()
                }
            }
        }
    }
    
    func reset() {
        stopAudioEngine()
        transcript = ""
        elapsedSeconds = 0
        audioLevel = 0.0
        state = .idle
    }
}
