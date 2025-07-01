//
//  Models.swift
//  realingo_v3
//
//  データモデル定義ファイル
//  参照: specification.md - 多言語対応と新しい問題タイプのサポート
//  関連: Quiz.swift (旧データモデル), ServiceManager.swift (データ永続化)
//

import Foundation
import UIKit

// MARK: - 言語定義
enum SupportedLanguage: String, Codable, CaseIterable {
    case japanese = "ja"
    case english = "en"
    case finnish = "fi"
    case russian = "ru"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case korean = "ko"
    case chinese = "zh"
    case german = "de"
    case kyrgyz = "ky"
    case kazakh = "kk"
    case bulgarian = "bg"
    case belarusian = "be"
    case armenian = "hy"
    case arabic = "ar"
    case hindi = "hi"
    case greek = "el"
    case irish = "ga"
    
    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        case .finnish: return "Suomi"
        case .russian: return "Русский"
        case .spanish: return "Español"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .korean: return "한국어"
        case .chinese: return "中文"
        case .german: return "Deutsch"
        case .kyrgyz: return "Кыргызча"
        case .kazakh: return "Қазақша"
        case .bulgarian: return "Български"
        case .belarusian: return "Беларуская"
        case .armenian: return "Հայերեն"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        case .greek: return "Ελληνικά"
        case .irish: return "Gaeilge"
        }
    }
    
    var flag: String {
        switch self {
        case .japanese: return "🇯🇵"
        case .english: return "🇺🇸"
        case .finnish: return "🇫🇮"
        case .russian: return "🇷🇺"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .italian: return "🇮🇹"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        case .german: return "🇩🇪"
        case .kyrgyz: return "🇰🇬"
        case .kazakh: return "🇰🇿"
        case .bulgarian: return "🇧🇬"
        case .belarusian: return "🇧🇾"
        case .armenian: return "🇦🇲"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .greek: return "🇬🇷"
        case .irish: return "🇮🇪"
        }
    }
    
    var keyboardIdentifier: String {
        switch self {
        case .japanese: return "ja_JP@sw=Kana"
        case .english: return "en_US"
        case .finnish: return "fi"
        case .russian: return "ru"
        case .spanish: return "es"
        case .french: return "fr"
        case .italian: return "it"
        case .korean: return "ko"
        case .chinese: return "zh-Hans"
        case .german: return "de"
        case .kyrgyz: return "ky"
        case .kazakh: return "kk"
        case .bulgarian: return "bg"
        case .belarusian: return "be"
        case .armenian: return "hy"
        case .arabic: return "ar"
        case .hindi: return "hi"
        case .greek: return "el"
        case .irish: return "ga"
        }
    }
    
    var isRTL: Bool {
        return self == .arabic
    }
    
    var locale: Locale {
        switch self {
        case .japanese: return Locale(identifier: "ja_JP")
        case .english: return Locale(identifier: "en_US")
        case .finnish: return Locale(identifier: "fi_FI")
        case .russian: return Locale(identifier: "ru_RU")
        case .spanish: return Locale(identifier: "es_ES")
        case .french: return Locale(identifier: "fr_FR")
        case .italian: return Locale(identifier: "it_IT")
        case .korean: return Locale(identifier: "ko_KR")
        case .chinese: return Locale(identifier: "zh_CN")
        case .german: return Locale(identifier: "de_DE")
        case .kyrgyz: return Locale(identifier: "ky_KG")
        case .kazakh: return Locale(identifier: "kk_KZ")
        case .bulgarian: return Locale(identifier: "bg_BG")
        case .belarusian: return Locale(identifier: "be_BY")
        case .armenian: return Locale(identifier: "hy_AM")
        case .arabic: return Locale(identifier: "ar_SA")
        case .hindi: return Locale(identifier: "hi_IN")
        case .greek: return Locale(identifier: "el_GR")
        case .irish: return Locale(identifier: "ga_IE")
        }
    }
    
    /// 指定された言語のキーボードがインストールされているかチェック
    func isKeyboardInstalled() -> Bool {
        guard let keyboards = UITextInputMode.activeInputModes as? [UITextInputMode] else {
            return false
        }
        
        return keyboards.contains { inputMode in
            guard let primaryLanguage = inputMode.primaryLanguage else { return false }
            
            // 言語コードでの一致をチェック
            switch self {
            case .japanese:
                return primaryLanguage.hasPrefix("ja")
            case .english:
                return primaryLanguage.hasPrefix("en")
            case .chinese:
                return primaryLanguage.hasPrefix("zh-Hans") || primaryLanguage.hasPrefix("zh")
            case .german:
                return primaryLanguage.hasPrefix("de")
            case .kyrgyz:
                return primaryLanguage.hasPrefix("ky")
            case .kazakh:
                return primaryLanguage.hasPrefix("kk")
            case .bulgarian:
                return primaryLanguage.hasPrefix("bg")
            case .belarusian:
                return primaryLanguage.hasPrefix("be")
            case .armenian:
                return primaryLanguage.hasPrefix("hy")
            case .arabic:
                return primaryLanguage.hasPrefix("ar")
            case .hindi:
                return primaryLanguage.hasPrefix("hi")
            case .greek:
                return primaryLanguage.hasPrefix("el")
            case .irish:
                return primaryLanguage.hasPrefix("ga")
            default:
                return primaryLanguage.hasPrefix(self.rawValue)
            }
        }
    }
}

// MARK: - 画像モード定義
enum ImageMode: String, Codable {
    case normal = "normal"
    case immediate = "immediate"
    case reminiscence = "reminiscence"
    case cameraCapture = "camera_capture"
    case random = "random"  // みんなの写真モード
}

// MARK: - 問題タイプ
enum ProblemType: String, Codable, CaseIterable {
    case wordArrangement = "word_arrangement"  // 語順並べ替え
    case fillInTheBlank = "fill_in_the_blank"  // 穴埋め
    case speaking = "speaking"                  // スピーキング
    case writing = "writing"                    // ライティング
    
    var displayName: String {
        // デフォルトで日本語を返す（後方互換性のため）
        // 実際の使用時はLocalizationHelper.getProblemTypeText()を使用すること
        switch self {
        case .wordArrangement: return "Word Arrangement"
        case .fillInTheBlank: return "Fill in the Blank"
        case .speaking: return "Speaking"
        case .writing: return "Writing"
        }
    }
}


// MARK: - 拡張版Quiz
struct ExtendedQuiz: Codable, Identifiable, Hashable {
    var id: String { problemID }
    let problemID: String
    
    // 基本情報
    let language: SupportedLanguage
    let problemType: ProblemType
    var imageMode: ImageMode
    
    // 問題内容
    let question: String
    let answer: String
    let imageUrl: String?
    let audioUrl: String?  // スピーキング問題用
    
    // 問題タイプ別の追加情報
    var options: [String]?         // 選択肢（並べ替えや穴埋め用）
    let blankPositions: [Int]?     // 穴埋め位置
    let hints: [String]?           // ヒント
    
    // メタ情報
    let difficulty: Int            // 1-5のレベル
    let tags: [String]?           // トピックタグ
    let explanation: [String: String]?
    var metadata: [String: String]?  // 追加のメタデータ
    
    // 作成情報
    let createdByGroup: String
    let createdByParticipant: String
    let createdAt: Date
    
    // VLM関連
    let vlmGenerated: Bool        // VLMで生成されたかどうか
    let vlmModel: String?         // 使用したVLMモデル
    
    // レミニセンス関連
    var notified: Bool?           // 通知済みかどうか
    
    // コミュニティ写真関連
    var communityPhotoID: String? // 使用したコミュニティ写真のID
}

// MARK: - 拡張版回答ログ
struct ExtendedProblemLog: Codable, Identifiable {
    var id: String { logID }
    let logID: String
    let problemID: String
    
    // ユーザー情報
    let participantID: String
    let groupID: String
    
    // 問題情報
    let language: SupportedLanguage
    let problemType: ProblemType
    let imageUrl: String?
    let question: String
    let correctAnswer: String
    
    // 回答情報
    let userAnswer: String
    let isCorrect: Bool
    let score: Double?            // 部分点対応
    let timeSpentSeconds: Int     // 回答時間
    
    // 詳細な回答データ
    let audioRecordingUrl: String?    // スピーキング用
    let vlmFeedback: String?          // VLMによるフィードバック
    let errorAnalysis: [String]?      // エラー分析
    
    // タイムスタンプ
    let startedAt: Date
    let completedAt: Date
    
    // 学習コンテキスト
    let sessionID: String         // 学習セッションID
    let previousAttempts: Int     // 同じ問題の試行回数
}

// MARK: - ユーザープロファイル
struct UserProfile: Codable {
    var userID: String
    var participantID: String?
    var groupID: String?
    
    // 言語設定
    var nativeLanguage: SupportedLanguage
    var learningLanguages: [SupportedLanguage]
    var currentLanguage: SupportedLanguage
    
    // 習熟度（CEFR準拠）
    var proficiencyLevels: [SupportedLanguage: String]  // A1-C2
    
    // 学習設定
    var dailyGoalMinutes: Int
    var reminderTime: Date?
    var preferredProblemTypes: [ProblemType]
    
    // 統計
    var totalLearningMinutes: Int
    var currentStreak: Int
    var longestStreak: Int
    var totalProblemsCompleted: Int
    
    // 研究用
    var consentGiven: Bool
    var studyStartDate: Date?
}

// MARK: - 学習セッション
struct LearningSession: Codable, Identifiable {
    var id: String { sessionID }
    let sessionID: String
    let userID: String
    
    let language: SupportedLanguage
    let startedAt: Date
    var endedAt: Date?
    
    var problemsAttempted: Int
    var problemsCorrect: Int
    var totalTimeSeconds: Int
    
    // 詳細な記録
    var problemLogs: [String]  // ExtendedProblemLog IDs
}

// MARK: - 研究用メトリクス
struct ResearchMetrics: Codable {
    let userID: String
    let date: Date
    
    // エンゲージメント指標
    let dailyActiveTime: Int
    let sessionsCount: Int
    let problemsAttempted: Int
    let completionRate: Double
    
    // 学習効果指標
    let accuracyRate: Double
    let improvementRate: Double
    let vocabularyGrowth: Int
    let retentionRate: Double
    
    // 行動パターン
    let preferredTimeOfDay: String
    let averageSessionLength: Int
    let streakMaintenance: Bool
    
    // 問題タイプ別パフォーマンス
    let performanceByType: [ProblemType: Double]
}

// MARK: - レミニセンスモード用モデル
struct ReminiscenceQuiz: Codable, Identifiable {
    var id: String = UUID().uuidString
    let participantID: String
    let imageURL: String?  // photoURL から imageURL に変更（Optional対応）
    let localImagePath: String?  // ローカル画像パス（研究同意なしの場合）
    let photoDate: Date
    let timeInterval: String // "1週間前", "1ヶ月前" など
    
    // ExtendedQuizと互換性のあるフィールド
    let language: SupportedLanguage
    let problemType: ProblemType
    let questionText: String  // question から questionText に変更
    let correctAnswers: [String]  // correctAnswer から correctAnswers に変更
    var options: [String]
    let blankPositions: [Int]?  // 穴埋め問題用の空欄位置
    let explanation: String?
    let difficulty: Int
    let tags: [String]
    let generatedBy: String
    
    let createdAt: Date = Date()
    var completedAt: Date?
    var userAnswer: String?
    var isCorrect: Bool?
}

// MARK: - VLMフィードバック
struct VLMFeedback: Codable {
    let isCorrect: Bool
    let score: Double  // 0.0 - 1.0
    let feedback: String
    let suggestions: [String]?
    let detailedAnalysis: String?
    
    // 言語学習特有のフィードバック
    let grammarErrors: [String]?
    let vocabularyErrors: [String]?
    let pronunciationNotes: String?  // スピーキング問題用
    let naturalness: Double?  // 自然さのスコア
}
