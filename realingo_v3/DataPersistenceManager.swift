//
//  DataPersistenceManager.swift
//  realingo_v3
//
//  学習データの永続化管理クラス
//  参照: specification.md - 出題した問題について、研究モードについて
//  関連: Models.swift (データモデル), ServiceManager.swift (Firebase連携)
//

import Foundation
import FirebaseFirestore

class DataPersistenceManager: ObservableObject {
    static let shared = DataPersistenceManager()
    let db = Firestore.firestore()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - Quiz管理
    
    /// 問題を保存
    func saveQuiz(_ quiz: ExtendedQuiz) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try db.collection("quizzes").document(quiz.problemID).setData(from: quiz)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// 問題を取得
    func fetchQuiz(problemID: String) async throws -> ExtendedQuiz? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let document = try await db.collection("quizzes").document(problemID).getDocument()
            return try document.data(as: ExtendedQuiz.self)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// 言語と問題タイプで問題を検索
    func fetchQuizzes(
        language: SupportedLanguage,
        problemType: ProblemType,
        limit: Int = 20
    ) async throws -> [ExtendedQuiz] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("quizzes")
                .whereField("language", isEqualTo: language.rawValue)
                .whereField("problemType", isEqualTo: problemType.rawValue)
                .limit(to: limit)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                let quiz = try document.data(as: ExtendedQuiz.self)
                
                // テスト/ダミーデータをフィルタリング
                if isTestOrDummyDataExtended(quiz) {
                    print("[DataPersistenceManager] Filtering out test/dummy ExtendedQuiz: \(quiz.problemID)")
                    return nil
                }
                
                return quiz
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - 回答ログ管理
    
    /// 回答ログを保存
    func saveProblemLog(_ log: ExtendedProblemLog) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try db.collection("problemLogs").document(log.logID).setData(from: log)
            
            // 研究用メトリクスも更新
            await updateResearchMetrics(for: log)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// ユーザーの回答履歴を取得
    func fetchUserLogs(
        participantID: String,
        language: SupportedLanguage? = nil,
        limit: Int = 50
    ) async throws -> [ExtendedProblemLog] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var query = db.collection("problemLogs")
                .whereField("participantID", isEqualTo: participantID)
                .order(by: "completedAt", descending: true)
            
            if let language = language {
                query = query.whereField("language", isEqualTo: language.rawValue)
            }
            
            let snapshot = try await query.limit(to: limit).getDocuments()
            
            return try snapshot.documents.compactMap { document in
                let log = try document.data(as: ExtendedProblemLog.self)
                
                // テスト/ダミーデータをフィルタリング
                if isTestOrDummyDataLog(log) {
                    print("[DataPersistenceManager] Filtering out test/dummy log: \(log.logID)")
                    return nil
                }
                
                return log
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// 復習用の問題を取得
    func fetchProblemsForReview(
        participantID: String,
        daysAgo: Int = 7
    ) async throws -> [ExtendedProblemLog] {
        isLoading = true
        defer { isLoading = false }
        
        let targetDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        
        do {
            let snapshot = try await db.collection("problemLogs")
                .whereField("participantID", isEqualTo: participantID)
                .whereField("isCorrect", isEqualTo: false)
                .whereField("completedAt", isGreaterThan: targetDate)
                .order(by: "completedAt", descending: true)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: ExtendedProblemLog.self)
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - レミニセンスモード用
    
    /// レミニセンス問題を保存
    func saveReminiscenceQuiz(_ quiz: ReminiscenceQuiz) async throws {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            // ReminiscenceQuizをFirestoreに保存
            let quizData = try JSONEncoder().encode(quiz)
            let quizDict = try JSONSerialization.jsonObject(with: quizData, options: []) as! [String: Any]
            
            try await db.collection("reminiscenceQuizzes").document(quiz.id).setData(quizDict)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    /// レミニセンス問題を取得
    func getReminiscenceQuizzes(participantID: String, limit: Int = 10) async throws -> [ReminiscenceQuiz] {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            let snapshot = try await db.collection("reminiscenceQuizzes")
                .whereField("participantID", isEqualTo: participantID)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            return snapshot.documents.compactMap { document in
                do {
                    // ドキュメントデータを取得
                    var documentData = document.data()
                    
                    // 古いmetadataフィールドが存在する場合は削除
                    documentData.removeValue(forKey: "metadata")
                    
                    // JSONデータに変換してデコード
                    let jsonData = try JSONSerialization.data(withJSONObject: documentData)
                    let quiz = try JSONDecoder().decode(ReminiscenceQuiz.self, from: jsonData)
                    
                    // テスト/ダミーデータをフィルタリング
                    if isTestOrDummyData(quiz) {
                        print("[DataPersistenceManager] Filtering out test/dummy data: \(quiz.id)")
                        return nil
                    }
                    
                    return quiz
                } catch {
                    print("[DataPersistenceManager] Failed to decode ReminiscenceQuiz: \(error)")
                    return nil
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
            
            // Firebaseのインデックスエラーの場合、コンソールにURLを表示
            if let nsError = error as NSError?,
               let indexURL = nsError.userInfo["index_url"] as? String {
                print("")
                print("========================================")
                print("🔥 Firebase Index Required")
                print("========================================")
                print("Please create a composite index by visiting:")
                print("\(indexURL)")
                print("========================================")
                print("")
            } else if error.localizedDescription.contains("index") {
                print("")
                print("========================================")
                print("🔥 Firebase Index Error")
                print("========================================")
                print("Error: \(error.localizedDescription)")
                print("")
                print("You may need to create a composite index for:")
                print("- Collection: reminiscenceQuizzes")
                print("- Fields: participantID (Ascending), createdAt (Descending)")
                print("")
                print("Check the Firebase Console for the exact index URL")
                print("========================================")
                print("")
            }
            
            throw error
        }
    }
    
    /// レミニセンス問題を保存（エイリアス）
    func saveProblem(_ quiz: ReminiscenceQuiz) async throws {
        try await saveReminiscenceQuiz(quiz)
    }
    
    
    // MARK: - ユーザープロファイル管理
    
    /// ユーザープロファイルを保存
    func saveUserProfile(_ profile: UserProfile) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try db.collection("userProfiles").document(profile.userID).setData(from: profile)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// ユーザープロファイルを取得
    func fetchUserProfile(userID: String) async throws -> UserProfile? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let document = try await db.collection("userProfiles").document(userID).getDocument()
            return try document.data(as: UserProfile.self)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// ユーザープロファイルを取得（getUserProfileエイリアス）
    func getUserProfile(participantID: String) async throws -> UserProfile? {
        return try await fetchUserProfile(userID: participantID)
    }
    
    /// 習熟度を更新
    func updateProficiencyLevel(
        userID: String,
        language: SupportedLanguage,
        newLevel: String
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("userProfiles").document(userID).updateData([
                "proficiencyLevels.\(language.rawValue)": newLevel
            ])
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - 学習セッション管理
    
    /// 学習セッションを開始
    func startLearningSession(
        userID: String,
        language: SupportedLanguage
    ) async throws -> LearningSession {
        isLoading = true
        defer { isLoading = false }
        
        let session = LearningSession(
            sessionID: UUID().uuidString,
            userID: userID,
            language: language,
            startedAt: Date(),
            endedAt: nil,
            problemsAttempted: 0,
            problemsCorrect: 0,
            totalTimeSeconds: 0,
            problemLogs: []
        )
        
        do {
            try db.collection("learningSessions").document(session.sessionID).setData(from: session)
            return session
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// 学習セッションを終了
    func endLearningSession(_ session: LearningSession) async throws {
        isLoading = true
        defer { isLoading = false }
        
        var updatedSession = session
        updatedSession.endedAt = Date()
        updatedSession.totalTimeSeconds = Int(Date().timeIntervalSince(session.startedAt))
        
        do {
            try db.collection("learningSessions").document(session.sessionID).setData(from: updatedSession)
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - 研究用メトリクス
    
    /// 研究用メトリクスを更新
    private func updateResearchMetrics(for log: ExtendedProblemLog) async {
        let today = Calendar.current.startOfDay(for: Date())
        let metricsID = "\(log.participantID)_\(today.timeIntervalSince1970)"
        
        do {
            let document = db.collection("researchMetrics").document(metricsID)
            let snapshot = try await document.getDocument()
            
            if snapshot.exists {
                // 既存のメトリクスを更新
                try await document.updateData([
                    "problemsAttempted": FieldValue.increment(Int64(1)),
                    "accuracyRate": FieldValue.increment(log.isCorrect ? Int64(1) : Int64(0))
                ])
            } else {
                // 新しいメトリクスを作成
                let metrics = ResearchMetrics(
                    userID: log.participantID,
                    date: today,
                    dailyActiveTime: 0,
                    sessionsCount: 1,
                    problemsAttempted: 1,
                    completionRate: 1.0,
                    accuracyRate: log.isCorrect ? 1.0 : 0.0,
                    improvementRate: 0.0,
                    vocabularyGrowth: 0,
                    retentionRate: 0.0,
                    preferredTimeOfDay: getCurrentTimeOfDay(),
                    averageSessionLength: 0,
                    streakMaintenance: true,
                    performanceByType: [log.problemType: log.isCorrect ? 1.0 : 0.0]
                )
                
                try document.setData(from: metrics)
            }
        } catch {
            print("Error updating research metrics: \(error)")
        }
    }
    
    /// 研究用メトリクスを保存
    func saveResearchMetrics(_ metrics: ResearchMetrics) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let metricsID = "\(metrics.userID)_\(metrics.date.timeIntervalSince1970)"
        
        do {
            try db.collection("researchMetrics").document(metricsID).setData(from: metrics)
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// 研究用メトリクスを取得
    func fetchResearchMetrics(
        userID: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [ResearchMetrics] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("researchMetrics")
                .whereField("userID", isEqualTo: userID)
                .whereField("date", isGreaterThanOrEqualTo: startDate)
                .whereField("date", isLessThanOrEqualTo: endDate)
                .order(by: "date", descending: true)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: ResearchMetrics.self)
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    /// テスト/ダミーデータかどうかを判定
    private func isTestOrDummyData(_ quiz: ReminiscenceQuiz) -> Bool {
        // ID パターンでのフィルタリング
        let testPatterns = [
            "test", "dummy", "sample", "mock", "debug", "dev",
            "Test", "Dummy", "Sample", "Mock", "Debug", "Dev",
            "TEST", "DUMMY", "SAMPLE", "MOCK", "DEBUG", "DEV"
        ]
        
        for pattern in testPatterns {
            if quiz.id.contains(pattern) ||
               quiz.participantID.contains(pattern) ||
               quiz.questionText.contains(pattern) ||
               quiz.generatedBy.contains(pattern) {
                return true
            }
        }
        
        // 特定のテスト用participantIDをフィルタリング
        let testParticipantIDs = [
            "user-123", "participant-123", "test-user", "test-participant",
            "user123", "participant123", "testuser", "testparticipant"
        ]
        
        if testParticipantIDs.contains(quiz.participantID) {
            return true
        }
        
        // 異常に短い質問文をフィルタリング（通常の問題文は最低10文字以上）
        if quiz.questionText.count < 10 {
            return true
        }
        
        // 空の回答配列をフィルタリング
        if quiz.correctAnswers.isEmpty {
            return true
        }
        
        // "Test"や"テスト"で始まる質問文をフィルタリング
        let questionLowercased = quiz.questionText.lowercased()
        if questionLowercased.hasPrefix("test") || 
           questionLowercased.hasPrefix("テスト") ||
           questionLowercased.hasPrefix("dummy") ||
           questionLowercased.hasPrefix("sample") {
            return true
        }
        
        return false
    }
    
    /// テスト/ダミーデータかどうかを判定（ExtendedQuiz用）
    private func isTestOrDummyDataExtended(_ quiz: ExtendedQuiz) -> Bool {
        // ID パターンでのフィルタリング
        let testPatterns = [
            "test", "dummy", "sample", "mock", "debug", "dev",
            "Test", "Dummy", "Sample", "Mock", "Debug", "Dev",
            "TEST", "DUMMY", "SAMPLE", "MOCK", "DEBUG", "DEV"
        ]
        
        for pattern in testPatterns {
            if quiz.problemID.contains(pattern) ||
               quiz.createdByParticipant.contains(pattern) ||
               quiz.question.contains(pattern) ||
               quiz.answer.contains(pattern) {
                return true
            }
        }
        
        // 特定のテスト用participantIDをフィルタリング
        let testParticipantIDs = [
            "user-123", "participant-123", "test-user", "test-participant",
            "user123", "participant123", "testuser", "testparticipant"
        ]
        
        if testParticipantIDs.contains(quiz.createdByParticipant) {
            return true
        }
        
        // 異常に短い質問文をフィルタリング（通常の問題文は最低10文字以上）
        if quiz.question.count < 10 {
            return true
        }
        
        // 異常に短い回答をフィルタリング
        if quiz.answer.count < 2 {
            return true
        }
        
        // "Test"や"テスト"で始まる質問文をフィルタリング
        let questionLowercased = quiz.question.lowercased()
        if questionLowercased.hasPrefix("test") || 
           questionLowercased.hasPrefix("テスト") ||
           questionLowercased.hasPrefix("dummy") ||
           questionLowercased.hasPrefix("sample") {
            return true
        }
        
        return false
    }
    
    /// テスト/ダミーデータかどうかを判定（ExtendedProblemLog用）
    private func isTestOrDummyDataLog(_ log: ExtendedProblemLog) -> Bool {
        // ID パターンでのフィルタリング
        let testPatterns = [
            "test", "dummy", "sample", "mock", "debug", "dev",
            "Test", "Dummy", "Sample", "Mock", "Debug", "Dev",
            "TEST", "DUMMY", "SAMPLE", "MOCK", "DEBUG", "DEV"
        ]
        
        for pattern in testPatterns {
            if log.logID.contains(pattern) ||
               log.problemID.contains(pattern) ||
               log.participantID.contains(pattern) ||
               log.question.contains(pattern) ||
               log.sessionID.contains(pattern) {
                return true
            }
        }
        
        // 特定のテスト用participantIDをフィルタリング
        let testParticipantIDs = [
            "user-123", "participant-123", "test-user", "test-participant",
            "user123", "participant123", "testuser", "testparticipant"
        ]
        
        if testParticipantIDs.contains(log.participantID) {
            return true
        }
        
        // 異常に短い質問文をフィルタリング
        if log.question.count < 10 {
            return true
        }
        
        return false
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9:
            return "早朝"
        case 9..<12:
            return "午前"
        case 12..<15:
            return "昼"
        case 15..<18:
            return "午後"
        case 18..<21:
            return "夕方"
        case 21..<24:
            return "夜"
        default:
            return "深夜"
        }
    }
    
    // MARK: - バッチ処理
    
    /// 複数の回答ログを一括保存
    func saveProblemLogsBatch(_ logs: [ExtendedProblemLog]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let batch = db.batch()
        
        for log in logs {
            let ref = db.collection("problemLogs").document(log.logID)
            do {
                try batch.setData(from: log, forDocument: ref)
            } catch {
                self.error = error
                throw error
            }
        }
        
        do {
            try await batch.commit()
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - データ取得
    
    /// 問題ログを日付範囲で取得
    func fetchProblemLogs(userID: String, dateRange: (start: Date, end: Date)) async -> [ExtendedProblemLog] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("problemLogs")
                .whereField("participantID", isEqualTo: userID)
                .whereField("completedAt", isGreaterThanOrEqualTo: dateRange.start)
                .whereField("completedAt", isLessThanOrEqualTo: dateRange.end)
                .order(by: "completedAt", descending: false)
                .getDocuments()
            
            return try snapshot.documents.compactMap { document in
                try document.data(as: ExtendedProblemLog.self)
            }
        } catch {
            print("Error fetching problem logs: \(error)")
            return []
        }
    }
    
    // MARK: - みんなの写真モード
    
    /// Firestoreからランダムな画像URLを取得
    func getRandomImageURL() async throws -> String? {
        await MainActor.run {
            isLoading = true
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        do {
            // まず全体の問題数を取得（画像URLを持つもののみ）
            let countQuery = db.collection("quizzes")
                .whereField("imageUrl", isNotEqualTo: NSNull())
            
            let countSnapshot = try await countQuery.getDocuments()
            let totalCount = countSnapshot.documents.count
            
            print("[DataPersistenceManager] Total quizzes with images: \(totalCount)")
            
            guard totalCount > 0 else {
                print("[DataPersistenceManager] No images found in database")
                return nil
            }
            
            // ランダムなインデックスを選択
            let randomIndex = Int.random(in: 0..<totalCount)
            
            // 該当するドキュメントを取得
            let randomSnapshot = try await db.collection("quizzes")
                .whereField("imageUrl", isNotEqualTo: NSNull())
                .limit(to: randomIndex + 1)
                .getDocuments()
            
            if let document = randomSnapshot.documents.last {
                let quiz = try document.data(as: ExtendedQuiz.self)
                print("[DataPersistenceManager] Random image URL: \(quiz.imageUrl ?? "nil")")
                return quiz.imageUrl
            }
            
            return nil
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
}