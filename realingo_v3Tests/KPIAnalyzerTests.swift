//
//  KPIAnalyzerTests.swift
//  realingo_v3Tests
//
//  KPIAnalyzer の単体テスト
//

import Testing
import Foundation
@testable import realingo_v3

struct KPIAnalyzerTests {
    
    // MARK: - Initialization Tests
    
    @Test func kpiAnalyzerSingleton() {
        let analyzer1 = KPIAnalyzer.shared
        let analyzer2 = KPIAnalyzer.shared
        
        // シングルトンインスタンスが同一であることを確認
        #expect(analyzer1 === analyzer2)
    }
    
    // MARK: - Metrics Structure Tests
    
    @Test func engagementMetricsInitialization() {
        let metrics = KPIAnalyzer.EngagementMetrics(
            sessionDuration: 1800,
            problemAttempts: 25,
            correctAnswers: 20,
            streakDays: 7,
            timeOfDay: "朝",
            interactionPatterns: ["hint_click": 5, "retry": 3],
            responseTime: 30.5,
            hintUsage: 5,
            retryCount: 3
        )
        
        #expect(metrics.sessionDuration == 1800)
        #expect(metrics.problemAttempts == 25)
        #expect(metrics.correctAnswers == 20)
        #expect(metrics.streakDays == 7)
        #expect(metrics.timeOfDay == "朝")
        #expect(metrics.interactionPatterns["hint_click"] == 5)
        #expect(metrics.responseTime == 30.5)
        #expect(metrics.hintUsage == 5)
        #expect(metrics.retryCount == 3)
    }
    
    @Test func learningEfficiencyInitialization() {
        let efficiency = KPIAnalyzer.LearningEfficiency(
            accuracyRate: 0.85,
            improvementRate: 0.15,
            retentionRate: 0.75,
            masteryLevel: 0.6,
            vocabularyGrowth: 50,
            grammarProgress: 0.7,
            fluencyScore: 0.65,
            complexityHandling: 0.55
        )
        
        #expect(efficiency.accuracyRate == 0.85)
        #expect(efficiency.improvementRate == 0.15)
        #expect(efficiency.retentionRate == 0.75)
        #expect(efficiency.masteryLevel == 0.6)
        #expect(efficiency.vocabularyGrowth == 50)
        #expect(efficiency.grammarProgress == 0.7)
        #expect(efficiency.fluencyScore == 0.65)
        #expect(efficiency.complexityHandling == 0.55)
    }
    
    @Test func userBehaviorInitialization() {
        let behavior = KPIAnalyzer.UserBehavior(
            preferredDifficulty: 3,
            problemTypePreference: [.wordArrangement: 0.4, .speaking: 0.3],
            learningTimeDistribution: [9: 0.3, 15: 0.5, 21: 0.2],
            sessionFrequency: 0.8,
            abandonmentRate: 0.1,
            featureUsage: ["hint": 10, "audio": 5],
            modePreference: [.immediate: 0.7, .reminiscence: 0.3]
        )
        
        #expect(behavior.preferredDifficulty == 3)
        #expect(behavior.problemTypePreference[.wordArrangement] == 0.4)
        #expect(behavior.learningTimeDistribution[15] == 0.5)
        #expect(behavior.sessionFrequency == 0.8)
        #expect(behavior.abandonmentRate == 0.1)
        #expect(behavior.featureUsage["hint"] == 10)
        #expect(behavior.modePreference[.immediate] == 0.7)
    }
    
    // MARK: - Event Tracking Tests
    
    @Test func analyticsEventTypes() {
        let eventTypes: [KPIAnalyzer.AnalyticsEvent.EventType] = [
            .problemStarted,
            .problemCompleted,
            .hintUsed,
            .answerSubmitted,
            .sessionStarted,
            .sessionEnded,
            .featureInteraction,
            .modeChanged
        ]
        
        #expect(eventTypes.count == 8)
        #expect(eventTypes.contains(.problemStarted))
        #expect(eventTypes.contains(.hintUsed))
    }
    
    @Test func analyticsEventCreation() {
        let event = KPIAnalyzer.AnalyticsEvent(
            timestamp: Date(),
            eventType: .problemCompleted,
            metadata: ["problemID": "test-123", "isCorrect": true]
        )
        
        #expect(event.eventType == .problemCompleted)
        #expect(event.metadata["problemID"] as? String == "test-123")
        #expect(event.metadata["isCorrect"] as? Bool == true)
    }
    
    // MARK: - Session Metrics Tests
    
    @Test func sessionMetricsCreation() {
        let sessionID = "test-session-123"
        let startTime = Date()
        
        let session = KPIAnalyzer.SessionMetrics(
            sessionID: sessionID,
            startTime: startTime,
            engagementMetrics: KPIAnalyzer.EngagementMetrics(
                sessionDuration: 0,
                problemAttempts: 0,
                correctAnswers: 0,
                streakDays: 0,
                timeOfDay: "朝",
                interactionPatterns: [:],
                responseTime: 0,
                hintUsage: 0,
                retryCount: 0
            ),
            learningEfficiency: KPIAnalyzer.LearningEfficiency(
                accuracyRate: 0,
                improvementRate: 0,
                retentionRate: 0,
                masteryLevel: 0,
                vocabularyGrowth: 0,
                grammarProgress: 0,
                fluencyScore: 0,
                complexityHandling: 0
            ),
            userBehavior: KPIAnalyzer.UserBehavior(
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
        
        #expect(session.sessionID == sessionID)
        #expect(session.startTime == startTime)
        #expect(session.events.isEmpty)
    }
    
    // MARK: - Realtime Metrics Tests
    
    @Test func realtimeMetricsInitialValues() {
        let metrics = KPIAnalyzer.RealtimeMetrics()
        
        #expect(metrics.currentStreak == 0)
        #expect(metrics.todayAccuracy == 0.0)
        #expect(metrics.weeklyProgress == 0.0)
        #expect(metrics.monthlyGrowth == 0.0)
    }
    
    // MARK: - Learning Pattern Analysis Tests
    
    @Test func learningPatternAnalysisStructure() {
        let analysis = KPIAnalyzer.LearningPatternAnalysis(
            optimalLearningTime: "午前",
            recommendedDifficulty: 4,
            strongAreas: ["単語並べ替え", "文法"],
            improvementAreas: ["スピーキング", "リスニング"],
            retentionScore: 0.75,
            suggestions: [
                "午前中の学習を継続しましょう",
                "スピーキング練習を増やすことをお勧めします"
            ]
        )
        
        #expect(analysis.optimalLearningTime == "午前")
        #expect(analysis.recommendedDifficulty == 4)
        #expect(analysis.strongAreas.count == 2)
        #expect(analysis.improvementAreas.contains("スピーキング"))
        #expect(analysis.retentionScore == 0.75)
        #expect(analysis.suggestions.count == 2)
    }
    
    // MARK: - Helper Method Tests
    
    @Test func timeOfDayCalculation() {
        // 時間帯の判定ロジックをテスト
        let calendar = Calendar.current
        
        // 朝の時間帯 (6:00-11:59)
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 8
        let morningDate = calendar.date(from: components)!
        
        // 昼の時間帯 (12:00-17:59)
        components.hour = 14
        let afternoonDate = calendar.date(from: components)!
        
        // 夜の時間帯 (18:00-22:59)
        components.hour = 20
        let eveningDate = calendar.date(from: components)!
        
        // 深夜の時間帯 (23:00-5:59)
        components.hour = 2
        let lateNightDate = calendar.date(from: components)!
        
        // 各時間帯の判定が正しいことを確認
        #expect(calendar.component(.hour, from: morningDate) >= 6 && calendar.component(.hour, from: morningDate) < 12)
        #expect(calendar.component(.hour, from: afternoonDate) >= 12 && calendar.component(.hour, from: afternoonDate) < 18)
        #expect(calendar.component(.hour, from: eveningDate) >= 18 && calendar.component(.hour, from: eveningDate) < 23)
        #expect(calendar.component(.hour, from: lateNightDate) < 6 || calendar.component(.hour, from: lateNightDate) >= 23)
    }
}