//
//  ModelsTests.swift
//  realingo_v3Tests
//
//  Models.swift の単体テスト
//

import Testing
@testable import realingo_v3

struct ModelsTests {
    
    // MARK: - SupportedLanguage Tests
    
    @Test func supportedLanguageDisplayNames() {
        #expect(SupportedLanguage.japanese.displayName == "日本語")
        #expect(SupportedLanguage.english.displayName == "English")
        #expect(SupportedLanguage.finnish.displayName == "Suomi")
        #expect(SupportedLanguage.russian.displayName == "Русский")
        #expect(SupportedLanguage.spanish.displayName == "Español")
        #expect(SupportedLanguage.french.displayName == "Français")
        #expect(SupportedLanguage.italian.displayName == "Italiano")
        #expect(SupportedLanguage.korean.displayName == "한국어")
    }
    
    @Test func supportedLanguageFlags() {
        #expect(SupportedLanguage.japanese.flag == "🇯🇵")
        #expect(SupportedLanguage.english.flag == "🇺🇸")
        #expect(SupportedLanguage.finnish.flag == "🇫🇮")
        #expect(SupportedLanguage.russian.flag == "🇷🇺")
        #expect(SupportedLanguage.spanish.flag == "🇪🇸")
        #expect(SupportedLanguage.french.flag == "🇫🇷")
        #expect(SupportedLanguage.italian.flag == "🇮🇹")
        #expect(SupportedLanguage.korean.flag == "🇰🇷")
    }
    
    @Test func supportedLanguageAllCases() {
        #expect(SupportedLanguage.allCases.count == 8)
        #expect(SupportedLanguage.allCases.contains(.japanese))
        #expect(SupportedLanguage.allCases.contains(.english))
        #expect(SupportedLanguage.allCases.contains(.finnish))
        #expect(SupportedLanguage.allCases.contains(.russian))
        #expect(SupportedLanguage.allCases.contains(.spanish))
        #expect(SupportedLanguage.allCases.contains(.french))
        #expect(SupportedLanguage.allCases.contains(.italian))
        #expect(SupportedLanguage.allCases.contains(.korean))
    }
    
    // MARK: - ProblemType Tests
    
    @Test func problemTypeDisplayNames() {
        #expect(ProblemType.wordArrangement.displayName == "単語並べ替え")
        #expect(ProblemType.fillInTheBlank.displayName == "穴埋め問題")
        #expect(ProblemType.speaking.displayName == "スピーキング")
        #expect(ProblemType.writing.displayName == "ライティング")
    }
    
    @Test func problemTypeAllCases() {
        #expect(ProblemType.allCases.count == 4)
        #expect(ProblemType.allCases.contains(.wordArrangement))
        #expect(ProblemType.allCases.contains(.fillInTheBlank))
        #expect(ProblemType.allCases.contains(.speaking))
        #expect(ProblemType.allCases.contains(.writing))
    }
    
    // MARK: - ExtendedQuiz Tests
    
    @Test func extendedQuizCreation() {
        let quiz = ExtendedQuiz(
            problemID: "test-123",
            language: .japanese,
            problemType: .wordArrangement,
            imageMode: .immediate,
            question: "Test question",
            answer: "Test answer",
            imageUrl: "https://example.com/image.jpg",
            audioUrl: nil,
            options: ["word1", "word2", "word3"],
            blankPositions: nil,
            hints: ["hint1"],
            difficulty: 3,
            tags: ["test"],
            explanation: ["ja": "説明"],
            createdByGroup: "A",
            createdByParticipant: "user123",
            createdAt: Date(),
            vlmGenerated: true,
            vlmModel: "gemini-1.5-flash"
        )
        
        #expect(quiz.id == "test-123")
        #expect(quiz.problemID == "test-123")
        #expect(quiz.language == .japanese)
        #expect(quiz.problemType == .wordArrangement)
        #expect(quiz.question == "Test question")
        #expect(quiz.answer == "Test answer")
        #expect(quiz.options?.count == 3)
        #expect(quiz.difficulty == 3)
        #expect(quiz.vlmGenerated == true)
    }
    
    // MARK: - ExtendedProblemLog Tests
    
    @Test func extendedProblemLogCreation() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(60)
        
        let log = ExtendedProblemLog(
            logID: "log-123",
            problemID: "test-123",
            participantID: "user123",
            groupID: "A",
            language: .japanese,
            problemType: .writing,
            imageUrl: nil,
            question: "Test question",
            correctAnswer: "Correct answer",
            userAnswer: "User answer",
            isCorrect: false,
            score: 0.75,
            timeSpentSeconds: 60,
            audioRecordingUrl: nil,
            vlmFeedback: "Good effort",
            errorAnalysis: ["Grammar error"],
            startedAt: startTime,
            completedAt: endTime,
            sessionID: "session-123",
            previousAttempts: 2
        )
        
        #expect(log.id == "log-123")
        #expect(log.participantID == "user123")
        #expect(log.groupID == "A")
        #expect(log.language == .japanese)
        #expect(log.problemType == .writing)
        #expect(log.isCorrect == false)
        #expect(log.score == 0.75)
        #expect(log.timeSpentSeconds == 60)
        #expect(log.vlmFeedback == "Good effort")
        #expect(log.errorAnalysis?.count == 1)
        #expect(log.previousAttempts == 2)
    }
    
    // MARK: - UserProfile Tests
    
    @Test func userProfileCreation() {
        var profile = UserProfile(
            userID: "user123",
            participantID: "participant123",
            groupID: "A",
            nativeLanguage: .japanese,
            learningLanguages: [.english, .finnish],
            currentLanguage: .english,
            proficiencyLevels: [.english: "B1", .finnish: "A2"],
            dailyGoalMinutes: 30,
            reminderTime: nil,
            preferredProblemTypes: [.wordArrangement, .writing],
            totalLearningMinutes: 1500,
            currentStreak: 7,
            longestStreak: 30,
            totalProblemsCompleted: 250,
            consentGiven: true,
            studyStartDate: Date()
        )
        
        #expect(profile.userID == "user123")
        #expect(profile.nativeLanguage == .japanese)
        #expect(profile.learningLanguages.count == 2)
        #expect(profile.currentLanguage == .english)
        #expect(profile.proficiencyLevels[.english] == "B1")
        #expect(profile.dailyGoalMinutes == 30)
        #expect(profile.currentStreak == 7)
        #expect(profile.totalProblemsCompleted == 250)
        #expect(profile.consentGiven == true)
    }
    
    // MARK: - ResearchMetrics Tests
    
    @Test func researchMetricsCreation() {
        let metrics = ResearchMetrics(
            userID: "user123",
            date: Date(),
            dailyActiveTime: 1800,
            sessionsCount: 3,
            problemsAttempted: 20,
            completionRate: 0.85,
            accuracyRate: 0.75,
            improvementRate: 0.1,
            vocabularyGrowth: 15,
            retentionRate: 0.8,
            preferredTimeOfDay: "午前",
            averageSessionLength: 600,
            streakMaintenance: true,
            performanceByType: [
                .wordArrangement: 0.8,
                .fillInTheBlank: 0.7,
                .speaking: 0.6,
                .writing: 0.75
            ]
        )
        
        #expect(metrics.dailyActiveTime == 1800)
        #expect(metrics.sessionsCount == 3)
        #expect(metrics.accuracyRate == 0.75)
        #expect(metrics.preferredTimeOfDay == "午前")
        #expect(metrics.performanceByType.count == 4)
        #expect(metrics.performanceByType[.wordArrangement] == 0.8)
    }
}