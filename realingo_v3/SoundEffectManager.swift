//
//  SoundEffectManager.swift
//  realingo_v3
//
//  効果音を管理するクラス
//  正解・不正解時の効果音を再生
//

import AVFoundation
import SwiftUI

class SoundEffectManager: ObservableObject {
    static let shared = SoundEffectManager()
    
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("soundEffectVolume") private var soundEffectVolume: Double = 0.7
    
    private var correctSoundPlayer: AVAudioPlayer?
    private var incorrectSoundPlayer: AVAudioPlayer?
    private var achievementSoundPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
        preloadSounds()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[SoundEffectManager] Failed to setup audio session: \(error)")
        }
    }
    
    private func preloadSounds() {
        // システムサウンドを使用
        prepareSystemSound()
    }
    
    private func prepareSystemSound() {
        // システムサウンドIDを使用
        // 正解音: 1057 (Tink)
        // 不正解音: 1053 (Tock)
        // 達成音: 1025 (New Mail)
    }
    
    // MARK: - Public Methods
    
    func playCorrectSound() {
        guard soundEffectsEnabled else { return }
        AudioServicesPlaySystemSound(1057) // Tink sound
    }
    
    func playIncorrectSound() {
        guard soundEffectsEnabled else { return }
        AudioServicesPlaySystemSound(1053) // Tock sound
    }
    
    func playAchievementSound() {
        guard soundEffectsEnabled else { return }
        AudioServicesPlaySystemSound(1025) // New Mail sound
    }
    
    func playHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Settings
    
    func toggleSoundEffects() {
        soundEffectsEnabled.toggle()
    }
    
    func setSoundEffectVolume(_ volume: Double) {
        soundEffectVolume = max(0.0, min(1.0, volume))
        correctSoundPlayer?.volume = Float(soundEffectVolume)
        incorrectSoundPlayer?.volume = Float(soundEffectVolume)
        achievementSoundPlayer?.volume = Float(soundEffectVolume)
    }
}

// MARK: - SwiftUI View Modifier

struct SoundEffectModifier: ViewModifier {
    let soundType: SoundEffectType
    let trigger: Bool
    
    enum SoundEffectType {
        case correct
        case incorrect
        case achievement
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { oldValue, newValue in
                if newValue {
                    switch soundType {
                    case .correct:
                        SoundEffectManager.shared.playCorrectSound()
                    case .incorrect:
                        SoundEffectManager.shared.playIncorrectSound()
                    case .achievement:
                        SoundEffectManager.shared.playAchievementSound()
                    }
                }
            }
    }
}

extension View {
    func soundEffect(_ type: SoundEffectModifier.SoundEffectType, trigger: Bool) -> some View {
        modifier(SoundEffectModifier(soundType: type, trigger: trigger))
    }
}