//
//  KPIAnalyzer.swift
//  realingo_v3
//
//  研究用のKPI測定・分析機能
//  学習効果の詳細な測定と分析を行う
//

import Foundation
import SwiftUI
import Combine

class KPIAnalyzer: ObservableObject {
    static let shared = KPIAnalyzer()
    
    // MARK: - 測定指標の定義
    
    struct EngagementMetrics {
        var sessionDuration: TimeInterval          // セッション時間
        var problemAttempts: Int                   // 問題挑戦回数
        var correctAnswers: Int                    // 正解数
        var streakDays: Int                        // 連続学習日数
        var timeOfDay: String                      // 学習時間帯
        var interactionPatterns: [String: Int]     // インタラクションパターン
        var responseTime: TimeInterval             // 平均回答時間
        var hintUsage: Int                        // ヒント使用回数
        var retryCount: Int                       // リトライ回数
    }
    
    struct LearningEfficiency {
        var accuracyRate: Double                   // 正解率
        var improvementRate: Double                // 改善率
        var retentionRate: Double                  // 定着率
        var masteryLevel: Double                   // 習熟度
        var vocabularyGrowth: Int                  // 語彙増加数
        var grammarProgress: Double                // 文法進捗率
        var fluencyScore: Double                   // 流暢性スコア
        var complexityHandling: Double             // 複雑度対応力
    }
    
    struct UserBehavior {
        var preferredDifficulty: Int               // 好みの難易度
        var problemTypePreference: [ProblemType: Double]  // 問題タイプ選好度
        var learningTimeDistribution: [Int: Double]      // 時間帯別学習分布
        var sessionFrequency: Double               // セッション頻度
        var abandonmentRate: Double                // 離脱率
        var featureUsage: [String: Int]           // 機能使用回数
        var modePreference: [ImageMode: Double]    // モード選好度
    }
    
    struct ContentEffectiveness {
        var problemSuccessRate: [String: Double]   // 問題別成功率
        var imageTypeEffectiveness: [String: Double] // 画像タイプ別効果
        var difficultyProgression: [Int: Double]   // 難易度別進捗
        var tagPerformance: [String: Double]       // タグ別パフォーマンス
        var languagePairEfficiency: [String: Double] // 言語ペア別効率
    }
    
    // MARK: - リアルタイム測定
    
    @Published var currentSession: SessionMetrics?
    @Published var realtimeMetrics: RealtimeMetrics = RealtimeMetrics()
    
    struct SessionMetrics {
        let sessionID: String
        var startTime: Date
        var engagementMetrics: EngagementMetrics
        var learningEfficiency: LearningEfficiency
        var userBehavior: UserBehavior
        var events: [AnalyticsEvent]
    }
    
    struct RealtimeMetrics {
        var currentStreak: Int = 0
        var todayAccuracy: Double = 0.0
        var weeklyProgress: Double = 0.0
        var monthlyGrowth: Double = 0.0
    }
    
    struct AnalyticsEvent {
        let timestamp: Date
        let eventType: EventType
        let metadata: [String: Any]
        
        enum EventType: String {
            case problemStarted = "problem_started"
            case problemCompleted = "problem_completed"
            case hintUsed = "hint_used"
            case answerSubmitted = "answer_submitted"
            case sessionStarted = "session_started"
            case sessionEnded = "session_ended"
            case featureInteraction = "feature_interaction"
            case modeChanged = "mode_changed"
        }
    }
    
    // MARK: - 初期化
    
    private init() {
        setupRealtimeMonitoring()
    }
    
    private func setupRealtimeMonitoring() {
        // アプリの状態変化を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    // MARK: - セッション管理
    
    func startSession(userID: String, language: SupportedLanguage) {
        let sessionID = UUID().uuidString
        currentSession = SessionMetrics(
            sessionID: sessionID,
            startTime: Date(),
            engagementMetrics: EngagementMetrics(
                sessionDuration: 0,
                problemAttempts: 0,
                correctAnswers: 0,
                streakDays: calculateCurrentStreak(userID: userID),
                timeOfDay: getCurrentTimeOfDay(),
                interactionPatterns: [:],
                responseTime: 0,
                hintUsage: 0,
                retryCount: 0
            ),
            learningEfficiency: LearningEfficiency(
                accuracyRate: 0,
                improvementRate: 0,
                retentionRate: 0,
                masteryLevel: 0,
                vocabularyGrowth: 0,
                grammarProgress: 0,
                fluencyScore: 0,
                complexityHandling: 0
            ),
            userBehavior: UserBehavior(
                preferredDifficulty: 3,
                problemTypePreference: [:],
                learningTimeDistribution: [:],
                sessionFrequency: 0,
                abandonmentRate: 0,
                featureUsage: [:],
                modePreference: [:]
            ),
            events: []
        )
        
        trackEvent(.sessionStarted, metadata: [
            "userID": userID,
            "language": language.rawValue,
            "sessionID": sessionID
        ])
    }
    
    func endSession() {
        guard let session = currentSession else { return }
        
        let duration = Date().timeIntervalSince(session.startTime)
        currentSession?.engagementMetrics.sessionDuration = duration
        
        // セッションデータを保存
        Task {
            await saveSessionMetrics(session)
        }
        
        trackEvent(.sessionEnded, metadata: [
            "duration": duration,
            "problemsAttempted": session.engagementMetrics.problemAttempts,
            "accuracy": session.learningEfficiency.accuracyRate
        ])
        
        currentSession = nil
    }
    
    // MARK: - イベントトラッキング
    
    func trackEvent(_ type: AnalyticsEvent.EventType, metadata: [String: Any] = [:]) {
        let event = AnalyticsEvent(
            timestamp: Date(),
            eventType: type,
            metadata: metadata
        )
        
        currentSession?.events.append(event)
        
        // リアルタイムメトリクスを更新
        updateRealtimeMetrics(for: event)
    }
    
    func trackProblemStart(problem: ExtendedQuiz) {
        trackEvent(.problemStarted, metadata: [
            "problemID": problem.problemID,
            "problemType": problem.problemType.rawValue,
            "difficulty": problem.difficulty,
            "language": problem.language.rawValue
        ])
        
        currentSession?.engagementMetrics.problemAttempts += 1
    }
    
    func trackProblemCompletion(
        problem: ExtendedQuiz,
        isCorrect: Bool,
        timeSpent: TimeInterval,
        hintsUsed: Int = 0
    ) {
        trackEvent(.problemCompleted, metadata: [
            "problemID": problem.problemID,
            "isCorrect": isCorrect,
            "timeSpent": timeSpent,
            "hintsUsed": hintsUsed
        ])
        
        if isCorrect {
            currentSession?.engagementMetrics.correctAnswers += 1
        }
        
        // 平均回答時間を更新
        updateAverageResponseTime(timeSpent)
        
        // 正解率を更新
        updateAccuracyRate()
        
        // 問題タイプの選好度を更新
        updateProblemTypePreference(problem.problemType)
    }
    
    func trackHintUsage(problemID: String) {
        trackEvent(.hintUsed, metadata: ["problemID": problemID])
        currentSession?.engagementMetrics.hintUsage += 1
    }
    
    // MARK: - メトリクス計算
    
    private func calculateCurrentStreak(userID: String) -> Int {
        // UserDefaultsから連続学習日数を取得
        let key = "streak_\(userID)"
        return UserDefaults.standard.integer(forKey: key)
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "朝"
        case 12..<18: return "昼"
        case 18..<23: return "夜"
        default: return "深夜"
        }
    }
    
    private func updateAverageResponseTime(_ newTime: TimeInterval) {
        guard let attempts = currentSession?.engagementMetrics.problemAttempts,
              attempts > 0 else { return }
        
        let currentAvg = currentSession?.engagementMetrics.responseTime ?? 0
        let newAvg = (currentAvg * Double(attempts - 1) + newTime) / Double(attempts)
        currentSession?.engagementMetrics.responseTime = newAvg
    }
    
    private func updateAccuracyRate() {
        guard let attempts = currentSession?.engagementMetrics.problemAttempts,
              let correct = currentSession?.engagementMetrics.correctAnswers,
              attempts > 0 else { return }
        
        currentSession?.learningEfficiency.accuracyRate = Double(correct) / Double(attempts)
        realtimeMetrics.todayAccuracy = Double(correct) / Double(attempts)
    }
    
    private func updateProblemTypePreference(_ type: ProblemType) {
        var preferences = currentSession?.userBehavior.problemTypePreference ?? [:]
        preferences[type] = (preferences[type] ?? 0) + 1
        currentSession?.userBehavior.problemTypePreference = preferences
    }
    
    private func updateRealtimeMetrics(for event: AnalyticsEvent) {
        // イベントに基づいてリアルタイムメトリクスを更新
        switch event.eventType {
        case .problemCompleted:
            if let isCorrect = event.metadata["isCorrect"] as? Bool, isCorrect {
                // 週間進捗を更新
                updateWeeklyProgress()
            }
        default:
            break
        }
    }
    
    private func updateWeeklyProgress() {
        Task {
            let weeklyStats = await fetchWeeklyStats()
            realtimeMetrics.weeklyProgress = calculateProgressRate(from: weeklyStats)
        }
    }
    
    // MARK: - 詳細分析
    
    func analyzeLearningPatterns(userID: String) async -> LearningPatternAnalysis {
        // 過去のセッションデータを取得
        let sessions = await fetchUserSessions(userID: userID, limit: 30)
        
        // パターン分析
        let timeDistribution = analyzeTimeDistribution(sessions)
        let difficultyProgression = analyzeDifficultyProgression(sessions)
        let problemTypeEfficiency = analyzeProblemTypeEfficiency(sessions)
        let retentionAnalysis = analyzeRetention(sessions)
        
        return LearningPatternAnalysis(
            optimalLearningTime: findOptimalLearningTime(timeDistribution),
            recommendedDifficulty: calculateRecommendedDifficulty(difficultyProgression),
            strongAreas: identifyStrongAreas(problemTypeEfficiency),
            improvementAreas: identifyImprovementAreas(problemTypeEfficiency),
            retentionScore: retentionAnalysis.score,
            suggestions: generatePersonalizedSuggestions(
                timeDistribution: timeDistribution,
                efficiency: problemTypeEfficiency,
                retention: retentionAnalysis
            )
        )
    }
    
    struct LearningPatternAnalysis {
        let optimalLearningTime: String
        let recommendedDifficulty: Int
        let strongAreas: [String]
        let improvementAreas: [String]
        let retentionScore: Double
        let suggestions: [String]
    }
    
    // MARK: - データ永続化
    
    private func saveSessionMetrics(_ session: SessionMetrics) async {
        // ResearchMetricsに変換して保存
        let metrics = ResearchMetrics(
            userID: UserDefaults.standard.string(forKey: "currentUserID") ?? "",
            date: Date(),
            dailyActiveTime: Int(session.engagementMetrics.sessionDuration),
            sessionsCount: 1,
            problemsAttempted: session.engagementMetrics.problemAttempts,
            completionRate: Double(session.engagementMetrics.correctAnswers) / Double(max(session.engagementMetrics.problemAttempts, 1)),
            accuracyRate: session.learningEfficiency.accuracyRate,
            improvementRate: session.learningEfficiency.improvementRate,
            vocabularyGrowth: session.learningEfficiency.vocabularyGrowth,
            retentionRate: session.learningEfficiency.retentionRate,
            preferredTimeOfDay: session.engagementMetrics.timeOfDay,
            averageSessionLength: Int(session.engagementMetrics.sessionDuration),
            streakMaintenance: session.engagementMetrics.streakDays > 0,
            performanceByType: session.userBehavior.problemTypePreference.mapValues { count in
                count / Double(session.engagementMetrics.problemAttempts)
            }
        )
        
        try? await DataPersistenceManager.shared.saveResearchMetrics(metrics)
    }
    
    // MARK: - Helper Methods
    
    private func fetchUserSessions(userID: String, limit: Int) async -> [SessionMetrics] {
        // 実装: Firestoreから過去のセッションデータを取得
        return []
    }
    
    private func fetchWeeklyStats() async -> [String: Any] {
        // 実装: 週間統計を取得
        return [:]
    }
    
    private func calculateProgressRate(from stats: [String: Any]) -> Double {
        // 実装: 進捗率を計算
        return 0.0
    }
    
    private func analyzeTimeDistribution(_ sessions: [SessionMetrics]) -> [String: Double] {
        // 実装: 時間帯別の学習分布を分析
        return [:]
    }
    
    private func analyzeDifficultyProgression(_ sessions: [SessionMetrics]) -> [Int: Double] {
        // 実装: 難易度の進捗を分析
        return [:]
    }
    
    private func analyzeProblemTypeEfficiency(_ sessions: [SessionMetrics]) -> [ProblemType: Double] {
        // 実装: 問題タイプ別の効率を分析
        return [:]
    }
    
    private func analyzeRetention(_ sessions: [SessionMetrics]) -> (score: Double, details: [String: Any]) {
        // 実装: 定着率を分析
        return (0.0, [:])
    }
    
    private func findOptimalLearningTime(_ distribution: [String: Double]) -> String {
        // 実装: 最適な学習時間を見つける
        return "朝"
    }
    
    private func calculateRecommendedDifficulty(_ progression: [Int: Double]) -> Int {
        // 実装: 推奨難易度を計算
        return 3
    }
    
    private func identifyStrongAreas(_ efficiency: [ProblemType: Double]) -> [String] {
        // 実装: 得意分野を特定
        return []
    }
    
    private func identifyImprovementAreas(_ efficiency: [ProblemType: Double]) -> [String] {
        // 実装: 改善が必要な分野を特定
        return []
    }
    
    private func generatePersonalizedSuggestions(
        timeDistribution: [String: Double],
        efficiency: [ProblemType: Double],
        retention: (score: Double, details: [String: Any])
    ) -> [String] {
        // 実装: パーソナライズされた提案を生成
        return []
    }
    
    // MARK: - Notification Handlers
    
    @objc private func appDidBecomeActive() {
        // アプリがアクティブになった時の処理
    }
    
    @objc private func appWillResignActive() {
        // アプリが非アクティブになる時の処理
        if currentSession != nil {
            endSession()
        }
    }
}