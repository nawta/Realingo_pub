//
//  DataPersistenceManagerTests.swift
//  realingo_v3Tests
//
//  DataPersistenceManager の単体テスト
//

import Testing
import Foundation
@testable import realingo_v3

struct DataPersistenceManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func dataPersistenceManagerSingleton() {
        let manager1 = DataPersistenceManager.shared
        let manager2 = DataPersistenceManager.shared
        
        // シングルトンインスタンスが同一であることを確認
        #expect(manager1 === manager2)
    }
    
    // MARK: - Mock Data Creation
    
    @Test func createMockQuiz() {
        let quiz = createTestQuiz()
        
        #expect(quiz.problemID == "test-quiz-123")
        #expect(quiz.language == .finnish)
        #expect(quiz.problemType == .wordArrangement)
        #expect(quiz.question == "Arrange the words to form a sentence")
        #expect(quiz.answer == "Tämä on kaunis maisema")
        #expect(quiz.options?.count == 4)
        #expect(quiz.difficulty == 3)
    }
    
    @Test func createMockProblemLog() {
        let log = createTestProblemLog()
        
        #expect(log.logID == "test-log-123")
        #expect(log.problemID == "test-quiz-123")
        #expect(log.participantID == "user-123")
        #expect(log.groupID == "A")
        #expect(log.language == .finnish)
        #expect(log.isCorrect == true)
        #expect(log.score == 1.0)
        #expect(log.timeSpentSeconds == 45)
    }
    
    @Test func createMockUserProfile() {
        let profile = createTestUserProfile()
        
        #expect(profile.userID == "user-123")
        #expect(profile.participantID == "participant-123")
        #expect(profile.groupID == "A")
        #expect(profile.nativeLanguage == .japanese)
        #expect(profile.learningLanguages.contains(.finnish))
        #expect(profile.currentLanguage == .finnish)
        #expect(profile.dailyGoalMinutes == 30)
        #expect(profile.currentStreak == 5)
    }
    
    @Test func createMockLearningSession() {
        let session = createTestLearningSession()
        
        #expect(session.sessionID == "test-session-123")
        #expect(session.userID == "user-123")
        #expect(session.language == .finnish)
        #expect(session.problemsAttempted == 10)
        #expect(session.problemsCorrect == 8)
        #expect(session.totalTimeSeconds == 600)
    }
    
    @Test func createMockResearchMetrics() {
        let metrics = createTestResearchMetrics()
        
        #expect(metrics.userID == "user-123")
        #expect(metrics.dailyActiveTime == 1800)
        #expect(metrics.sessionsCount == 3)
        #expect(metrics.problemsAttempted == 25)
        #expect(metrics.accuracyRate == 0.8)
        #expect(metrics.performanceByType[.wordArrangement] == 0.85)
    }
    
    // MARK: - Helper Methods
    
    private func createTestQuiz() -> ExtendedQuiz {
        ExtendedQuiz(
            problemID: "test-quiz-123",
            language: .finnish,
            problemType: .wordArrangement,
            imageMode: .immediate,
            question: "Arrange the words to form a sentence",
            answer: "Tämä on kaunis maisema",
            imageUrl: "https://example.com/test.jpg",
            audioUrl: nil,
            options: ["Tämä", "on", "kaunis", "maisema"],
            blankPositions: nil,
            hints: ["Start with the subject"],
            difficulty: 3,
            tags: ["nature", "basic"],
            explanation: ["en": "This is a beautiful landscape"],
            createdByGroup: "A",
            createdByParticipant: "user-123",
            createdAt: Date(),
            vlmGenerated: true,
            vlmModel: "gemini-1.5-flash"
        )
    }
    
    private func createTestProblemLog() -> ExtendedProblemLog {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(45)
        
        return ExtendedProblemLog(
            logID: "test-log-123",
            problemID: "test-quiz-123",
            participantID: "user-123",
            groupID: "A",
            language: .finnish,
            problemType: .wordArrangement,
            imageUrl: "https://example.com/test.jpg",
            question: "Arrange the words to form a sentence",
            correctAnswer: "Tämä on kaunis maisema",
            userAnswer: "Tämä on kaunis maisema",
            isCorrect: true,
            score: 1.0,
            timeSpentSeconds: 45,
            audioRecordingUrl: nil,
            vlmFeedback: nil,
            errorAnalysis: nil,
            startedAt: startTime,
            completedAt: endTime,
            sessionID: "test-session-123",
            previousAttempts: 0
        )
    }
    
    private func createTestUserProfile() -> UserProfile {
        UserProfile(
            userID: "user-123",
            participantID: "participant-123",
            groupID: "A",
            nativeLanguage: .japanese,
            learningLanguages: [.finnish, .english],
            currentLanguage: .finnish,
            proficiencyLevels: [.finnish: "A2", .english: "B1"],
            dailyGoalMinutes: 30,
            reminderTime: nil,
            preferredProblemTypes: [.wordArrangement, .fillInTheBlank],
            totalLearningMinutes: 1200,
            currentStreak: 5,
            longestStreak: 15,
            totalProblemsCompleted: 150,
            consentGiven: true,
            studyStartDate: Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        )
    }
    
    private func createTestLearningSession() -> LearningSession {
        LearningSession(
            sessionID: "test-session-123",
            userID: "user-123",
            language: .finnish,
            startedAt: Date().addingTimeInterval(-600), // 10 minutes ago
            endedAt: Date(),
            problemsAttempted: 10,
            problemsCorrect: 8,
            totalTimeSeconds: 600,
            problemLogs: ["log-1", "log-2", "log-3"]
        )
    }
    
    private func createTestResearchMetrics() -> ResearchMetrics {
        ResearchMetrics(
            userID: "user-123",
            date: Date(),
            dailyActiveTime: 1800, // 30 minutes
            sessionsCount: 3,
            problemsAttempted: 25,
            completionRate: 0.9,
            accuracyRate: 0.8,
            improvementRate: 0.15,
            vocabularyGrowth: 20,
            retentionRate: 0.75,
            preferredTimeOfDay: "午前",
            averageSessionLength: 600, // 10 minutes
            streakMaintenance: true,
            performanceByType: [
                .wordArrangement: 0.85,
                .fillInTheBlank: 0.75,
                .speaking: 0.7,
                .writing: 0.8
            ]
        )
    }
}