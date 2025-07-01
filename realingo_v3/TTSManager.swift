//
//  TTSManager.swift
//  realingo_v3
//
//  テキスト読み上げ機能を管理するクラス
//  参照: specification.md - 回答の仕方について
//  関連: ContentView.swift, Models.swift (SupportedLanguage)
//

import AVFoundation
import SwiftUI

class TTSManager: NSObject, ObservableObject {
    static let shared = TTSManager()
    
    @Published var isSpeaking = false
    @AppStorage("ttsEnabled") private var ttsEnabled = true
    @AppStorage("ttsSpeechRate") private var speechRate: Double = 0.5
    
    private let synthesizer = AVSpeechSynthesizer()
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[TTSManager] Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// テキストを指定された言語で読み上げる
    func speak(text: String, language: SupportedLanguage, completion: (() -> Void)? = nil) {
        guard ttsEnabled else {
            completion?()
            return
        }
        
        // 既に読み上げ中の場合は停止
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // 言語に応じた音声を設定
        utterance.voice = AVSpeechSynthesisVoice(language: language.locale.identifier)
        
        // 音声が見つからない場合はデフォルトを使用
        if utterance.voice == nil {
            print("[TTSManager] Voice not found for \(language.displayName), using default")
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // 読み上げ速度を設定
        utterance.rate = Float(speechRate)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // 読み上げ前後の間隔
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// 読み上げを停止
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    /// 読み上げを一時停止
    func pauseSpeaking() {
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    /// 読み上げを再開
    func resumeSpeaking() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    /// 利用可能な音声を取得
    func availableVoices(for language: SupportedLanguage) -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix(language.rawValue)
        }
    }
    
    // MARK: - Settings
    
    func setTTSEnabled(_ enabled: Bool) {
        ttsEnabled = enabled
        if !enabled {
            stopSpeaking()
        }
    }
    
    func setSpeechRate(_ rate: Double) {
        speechRate = max(0.0, min(1.0, rate))
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - SwiftUI View Modifier

struct TTSModifier: ViewModifier {
    let text: String
    let language: SupportedLanguage
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { oldValue, newValue in
                if newValue {
                    TTSManager.shared.speak(text: text, language: language)
                }
            }
    }
}

extension View {
    func speakText(_ text: String, language: SupportedLanguage, trigger: Bool) -> some View {
        modifier(TTSModifier(text: text, language: language, trigger: trigger))
    }
}