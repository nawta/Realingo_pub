//
//  ProblemGenerationService.swift
//  realingo_v3
//
//  問題生成サービスの統合管理（Gemini API / オンデバイスVLM）
//  参照: specification.md - API/VLM切り替え機能
//  関連: GeminiService.swift, VLMService.swift
//

import Foundation
import SwiftUI
import Combine

// 問題生成モード
enum ProblemGenerationMode: String, CaseIterable {
    case geminiAPI = "Gemini API"
    case onDeviceVLM = "オンデバイスVLM"
    
    var icon: String {
        switch self {
        case .geminiAPI:
            return "cloud"
        case .onDeviceVLM:
            return "iphone"
        }
    }
    
    var description: String {
        switch self {
        case .geminiAPI:
            return "クラウドベースの高精度AI"
        case .onDeviceVLM:
            return "プライバシー重視のローカルAI"
        }
    }
}

// 統合問題生成サービス
@MainActor
class ProblemGenerationService: ObservableObject {
    static let shared = ProblemGenerationService()
    
    @AppStorage("problemGenerationMode") private var generationModeRaw: String = ProblemGenerationMode.geminiAPI.rawValue
    @Published var isVLMAvailable = false
    @Published var currentVLMModel: VLMModel?
    
    private let geminiService = GeminiService.shared
    private let vlmService = VLMService.shared
    private let vlmManager = VLMManager.shared
    
    var currentMode: ProblemGenerationMode {
        get {
            ProblemGenerationMode(rawValue: generationModeRaw) ?? .geminiAPI
        }
        set {
            generationModeRaw = newValue.rawValue
        }
    }
    
    private init() {
        checkVLMAvailability()
    }
    
    // VLMの利用可能性をチェック
    private func checkVLMAvailability() {
        currentVLMModel = vlmManager.currentModel
        isVLMAvailable = currentVLMModel != nil
        
        // VLMManagerの状態を監視
        vlmManager.$currentModel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.currentVLMModel = model
                self?.isVLMAvailable = model != nil
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // 画像URLから問題生成
    func generateProblemFromImageURL(
        imageURL: String,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage
    ) async throws -> ExtendedQuiz {
        
        switch currentMode {
        case .geminiAPI:
            return try await geminiService.generateProblemFromImageURL(
                imageURL: imageURL,
                language: language,
                problemType: problemType,
                nativeLanguage: nativeLanguage
            )
            
        case .onDeviceVLM:
            guard isVLMAvailable else {
                throw VLMError.modelNotFound
            }
            return try await vlmService.generateProblemFromImageURL(
                imageURL: imageURL,
                language: language,
                problemType: problemType,
                nativeLanguage: nativeLanguage
            )
        }
    }
    
    // 画像データから問題生成
    func generateProblemFromImageData(
        imageData: Data,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage
    ) async throws -> ExtendedQuiz {
        
        switch currentMode {
        case .geminiAPI:
            // GeminiServiceの実装に合わせて調整
            let base64Image = imageData.base64EncodedString()
            return try await geminiService.generateProblemFromBase64Image(
                base64Image: base64Image,
                language: language,
                problemType: problemType,
                nativeLanguage: nativeLanguage
            )
            
        case .onDeviceVLM:
            guard isVLMAvailable else {
                throw VLMError.modelNotFound
            }
            return try await vlmService.generateProblemFromImageData(
                imageData: imageData,
                language: language,
                problemType: problemType,
                nativeLanguage: nativeLanguage
            )
        }
    }
    
    // 画像の説明生成
    func generateImageDescription(
        imageData: Data,
        prompt: String,
        language: SupportedLanguage
    ) async throws -> String {
        
        switch currentMode {
        case .geminiAPI:
            return try await geminiService.generateImageDescription(
                imageData: imageData,
                prompt: prompt,
                language: language
            )
            
        case .onDeviceVLM:
            guard isVLMAvailable else {
                throw VLMError.modelNotFound
            }
            return try await vlmService.generateImageDescription(
                imageData: imageData,
                prompt: prompt,
                language: language
            )
        }
    }
    
    // 回答の評価
    func evaluateAnswer(
        userAnswer: String,
        correctAnswer: String,
        problemType: ProblemType,
        language: SupportedLanguage
    ) async throws -> VLMFeedback {
        
        switch currentMode {
        case .geminiAPI:
            return try await geminiService.evaluateAnswer(
                userAnswer: userAnswer,
                correctAnswer: correctAnswer,
                problemType: problemType,
                language: language
            )
            
        case .onDeviceVLM:
            guard isVLMAvailable else {
                throw VLMError.modelNotFound
            }
            return try await vlmService.evaluateAnswer(
                userAnswer: userAnswer,
                correctAnswer: correctAnswer,
                problemType: problemType,
                language: language
            )
        }
    }
    
    // テキストから問題生成（Gemini APIのみ）
    func generateProblemFromText(
        text: String,
        translation: String,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage
    ) async throws -> ExtendedQuiz {
        
        // テキストベースの問題生成はGemini APIのみサポート
        return try await geminiService.generateProblemFromText(
            text: text,
            translation: translation,
            language: language,
            problemType: problemType,
            nativeLanguage: nativeLanguage
        )
    }
    
    // 翻訳（Gemini APIのみ）
    func translateText(
        text: String,
        fromLanguage: SupportedLanguage,
        toLanguage: SupportedLanguage
    ) async throws -> String {
        
        // 翻訳はGemini APIのみサポート
        return try await geminiService.translateText(
            text: text,
            fromLanguage: fromLanguage,
            toLanguage: toLanguage
        )
    }
    
    // モード切り替え時の検証
    func canSwitchToMode(_ mode: ProblemGenerationMode) -> (canSwitch: Bool, reason: String?) {
        switch mode {
        case .geminiAPI:
            // API キーの確認
            let hasAPIKey = !APIKeyManager.shared.geminiAPIKey.isEmpty
            return (hasAPIKey, hasAPIKey ? nil : "Gemini APIキーが設定されていません")
            
        case .onDeviceVLM:
            // VLMモデルのロード状態を確認
            return (isVLMAvailable, isVLMAvailable ? nil : "VLMモデルがロードされていません")
        }
    }
}