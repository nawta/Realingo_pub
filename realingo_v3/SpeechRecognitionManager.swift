//
//  SpeechRecognitionManager.swift
//  realingo_v3
//
//  音声認識機能の管理クラス
//  参照: specification.md - スピーキング回答方式
//  関連: SpeakingPracticeView.swift (UI), Models.swift (データモデル)
//

import Foundation
import Speech
import AVFoundation

class SpeechRecognitionManager: NSObject, ObservableObject {
    // 音声認識の状態
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    // 音声認識関連のプロパティ
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 録音関連
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        checkAuthorization()
    }
    
    private func setupSpeechRecognizer() {
        // デフォルトは英語、後で言語切り替えメソッドを追加
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    // 言語を変更するメソッド
    func changeLanguage(_ language: SupportedLanguage) {
        let localeIdentifier: String
        switch language {
        case .japanese:
            localeIdentifier = "ja-JP"
        case .english:
            localeIdentifier = "en-US"
        case .finnish:
            localeIdentifier = "fi-FI"
        case .russian:
            localeIdentifier = "ru-RU"
        case .spanish:
            localeIdentifier = "es-ES"
        case .french:
            localeIdentifier = "fr-FR"
        case .italian:
            localeIdentifier = "it-IT"
        case .korean:
            localeIdentifier = "ko-KR"
        case .chinese:
            localeIdentifier = "zh-CN"
        case .german:
            localeIdentifier = "de-DE"
        case .kyrgyz:
            localeIdentifier = "ky-KG"
        case .kazakh:
            localeIdentifier = "kk-KZ"
        case .bulgarian:
            localeIdentifier = "bg-BG"
        case .belarusian:
            localeIdentifier = "be-BY"
        case .armenian:
            localeIdentifier = "hy-AM"
        case .arabic:
            localeIdentifier = "ar-SA"
        case .hindi:
            localeIdentifier = "hi-IN"
        case .greek:
            localeIdentifier = "el-GR"
        case .irish:
            localeIdentifier = "ga-IE"
        }
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        speechRecognizer?.delegate = self
    }
    
    // 認証状態をチェック
    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                case .denied:
                    self?.isAuthorized = false
                    self?.errorMessage = "音声認識の使用が拒否されました"
                case .restricted:
                    self?.isAuthorized = false
                    self?.errorMessage = "音声認識が制限されています"
                case .notDetermined:
                    self?.isAuthorized = false
                    self?.errorMessage = "音声認識の許可が必要です"
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
        
        // マイクの権限も確認
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                if !granted {
                    DispatchQueue.main.async {
                        self?.isAuthorized = false
                        self?.errorMessage = "マイクの使用許可が必要です"
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                if !granted {
                    DispatchQueue.main.async {
                        self?.isAuthorized = false
                        self?.errorMessage = "マイクの使用許可が必要です"
                    }
                }
            }
        }
    }
    
    // 録音開始
    func startRecording() throws {
        // 既存のタスクをキャンセル
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // オーディオセッションの設定
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 認識リクエストの作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        let inputNode = audioEngine.inputNode
        
        // 録音フォーマットの取得
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // 音声認識タスクの開始
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self?.recognizedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self?.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self?.isRecording = false
                }
            }
        }
        
        // オーディオエンジンの開始
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.recognizedText = ""
        }
        
        // 録音ファイルの保存も同時に行う
        setupAudioRecorder()
        audioRecorder?.record()
    }
    
    // 録音停止
    func stopRecording() {
        // 音声認識タスクをキャンセル
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 音声認識リクエストを終了
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // オーディオエンジンを停止
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 録音を停止
        audioRecorder?.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    // 録音ファイルのセットアップ
    private func setupAudioRecorder() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        recordingURL = audioFilename
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
        } catch {
            print("Audio recorder setup failed: \(error)")
        }
    }
    
    // 最後の録音ファイルのURLを取得
    func getLastRecordingURL() -> URL? {
        return recordingURL
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognitionManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            DispatchQueue.main.async {
                self.errorMessage = "音声認識が一時的に利用できません"
            }
        }
    }
}

// MARK: - Error Types
enum SpeechRecognitionError: Error, LocalizedError {
    case requestCreationFailed
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .requestCreationFailed:
            return "音声認識リクエストの作成に失敗しました"
        case .audioEngineError:
            return "オーディオエンジンのエラーが発生しました"
        }
    }
}