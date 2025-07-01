//
//  ContentView.swift
//  realingo_v3
//
//  Created by 西田直人 on 3/9/25.
//  改良版: Duolingo風単語UI + 発音フォールバック、写真取得ロジック更新など
//

import CoreData
import SwiftUI
import Photos

struct ContentView: View {
    @AppStorage("isResearchMode") private var isResearchMode = false
    @AppStorage("participantID") private var participantID = "0"
    @AppStorage("groupID") private var groupID = "A"
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    @State private var debugMessage: String = ""
    @State private var quizzes: [Quiz] = []
    @State private var currentQuiz: Quiz? = nil
    @State private var showResultModal = false
    @State private var isCorrectAnswer = false
    @State private var showUploadModal = false
    
    // 外部からExtendedQuizを受け取るためのイニシャライザ
    init(quiz: ExtendedQuiz? = nil) {
        if let extendedQuiz = quiz {
            // ExtendedQuizからQuizに変換
            var convertedQuiz = Quiz(
                problemID: extendedQuiz.problemID,
                question: extendedQuiz.question,
                answer: extendedQuiz.answer,
                imageUrl: extendedQuiz.imageUrl,
                explanation: extendedQuiz.explanation,
                options: extendedQuiz.options,
                problemType: extendedQuiz.problemType.rawValue,
                createdByGroup: extendedQuiz.createdByGroup,
                createdByParticipant: extendedQuiz.createdByParticipant
            )
            
            // optionsが無い場合はanswerから生成
            if convertedQuiz.options == nil || convertedQuiz.options?.isEmpty == true {
                let words = convertedQuiz.answer.components(separatedBy: " ").filter { !$0.isEmpty }
                if !words.isEmpty {
                    convertedQuiz.options = words.shuffled()
                }
            }
            
            _currentQuiz = State(initialValue: convertedQuiz)
            
            // 初期化時に単語をセットアップ
            if let opts = convertedQuiz.options, !opts.isEmpty {
                _availableWords = State(initialValue: opts.shuffled())
                _selectedWords = State(initialValue: [])
            }
        }
    }
    
    
    // Duolingo風 並べ替えUI
    @State private var selectedWords: [String] = []
    @State private var availableWords: [String] = []
    
    @State private var correctCount: Int = 0
    @State private var fetchedImage: UIImage? = nil
    @State private var showExplanation: Bool = false
    @State private var sessionStartTime = Date()
    @State private var playCorrectSound = false
    @State private var playIncorrectSound = false
    @StateObject private var ttsManager = TTSManager.shared
    @State private var showGrammarAlert = false
    @State private var grammarFeedbackMessage = ""
    
    @StateObject private var dataPersistence = DataPersistenceManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 研究モードインジケーター（デバッグ時のみ表示）
                    #if DEBUG
                    if isResearchMode {
                        HStack {
                            Image(systemName: "flask.fill")
                                .font(.caption)
                            Text("研究モード: \(groupID)-\(participantID)")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(15)
                    }
                    #endif
                
                if let quiz = currentQuiz {
                    Text(LocalizationHelper.getCommonText("problem", for: nativeLanguage)).font(.headline)
                    
                    // ★ 常にDuolingo風UIを表示する(または quiz.options != nil の場合のみ)
                    Text(quiz.question).padding()
                    
                    if let imageUrl = quiz.imageUrl {
                        VStack {
                            Group {
                                if imageUrl.hasPrefix("file://") {
                                    // ローカル画像の場合
                                    let localPath = String(imageUrl.dropFirst(7)) // "file://" を除去
                                    if let localImage = ReminiscenceManager.shared.loadLocalImage(path: localPath) {
                                        Image(uiImage: localImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 200)
                                    } else {
                                        Text(LocalizationHelper.getCommonText("cannotLoadImage", for: nativeLanguage))
                                            .frame(height: 200)
                                    }
                                } else {
                                    // リモート画像の場合
                                    AsyncImage(url: URL(string: imageUrl)) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image.resizable().scaledToFit().frame(height: 200)
                                        case .failure(_):
                                            Text(LocalizationHelper.getCommonText("cannotLoadImage", for: nativeLanguage))
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                            .padding()
                            
                            // 写真アップロードボタン
                            if let extendedQuiz = quizToExtendedQuiz(quiz) {
                                PhotoUploadButton(quiz: extendedQuiz)
                            }
                        }
                    } else if let uiImage = fetchedImage {
                        VStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                            
                            // 写真アップロードボタン（fetchedImageがある場合）
                            if let quiz = currentQuiz, let extendedQuiz = quizToExtendedQuiz(quiz) {
                                PhotoUploadButton(quiz: extendedQuiz)
                            }
                        }
                    }
                    
                    // 選択された順序
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizationHelper.getCommonText("answer", for: nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if selectedWords.isEmpty {
                                Text(LocalizationHelper.getCommonText("tapWordsToCreateSentence", for: nativeLanguage))
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(selectedWords, id: \.self) { word in
                                    Text(word)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.3))
                                        .cornerRadius(4)
                                        .onTapGesture {
                                            // 単語をタップして戻す
                                            if let index = selectedWords.firstIndex(of: word) {
                                                selectedWords.remove(at: index)
                                                availableWords.append(word)
                                            }
                                        }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .frame(minHeight: 50)
                    }
                    .padding(.horizontal)
                    
                    // 利用可能な単語
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizationHelper.getCommonText("availableWords", for: nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        if availableWords.isEmpty {
                            Text(LocalizationHelper.getCommonText("noWordsAvailable", for: nativeLanguage))
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 100)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                        } else {
                            ScrollView {
                                SimpleWrapView(words: availableWords) { word in
                                    selectWord(word)
                                    debugMessage += "[Selected] \(word)\n"
                                }
                                .padding(.horizontal)
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    
                    HStack {
                        Button(LocalizationHelper.getCommonText("reset", for: nativeLanguage)) {
                            resetWordsForQuiz(quiz)
                        }
                        .padding()
                        
                        Button(LocalizationHelper.getCommonText("submit", for: nativeLanguage)) {
                            checkDuolingoAnswer(for: quiz)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        if quiz.explanation != nil {
                            Button(LocalizationHelper.getCommonText("showExplanation", for: nativeLanguage)) {
                                showExplanation = true
                                if let explanationDict = quiz.explanation {
                                    // 辞書から適切な言語の解説を取得
                                    let explanationText = explanationDict[nativeLanguage.rawValue] ?? explanationDict.values.first ?? LocalizationHelper.getCommonText("noExplanationAvailable", for: nativeLanguage)
                                    debugMessage += "[解説] \(explanationText)\n"
                                    print("[解説] \(explanationText)")
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    Button(LocalizationHelper.getCommonText("listenToPronunciation", for: nativeLanguage)) {
                        speakText(quiz.answer, language: selectedLanguage)
                    }
                    
                    Text("\(LocalizationHelper.getCommonText("correctCount", for: nativeLanguage)): \(correctCount)").padding(.top, 40)
                    
                } else {
                    Text(LocalizationHelper.getCommonText("noProblemsAvailable", for: nativeLanguage))
                }
                
                Button(currentQuiz?.imageUrl != nil ? LocalizationHelper.getCommonText("generateDifferentSentence", for: nativeLanguage) : LocalizationHelper.getCommonText("debugCreateProblem", for: nativeLanguage)) {
                    debugCreateOrFetchProblem()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                ScrollView {
                    Text(debugMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(maxHeight: 150)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                
                    // 研究モード時のみ研究設定へのリンクを表示
                    if isResearchMode {
                        NavigationLink(destination: ResearchSettingsView()) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text(LocalizationHelper.getCommonText("researchSettings", for: nativeLanguage))
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top)
                    }
                    
                }
                .padding()
            }
            .navigationTitle(LocalizationHelper.getCommonText("learningLanguageTitle", for: nativeLanguage).replacingOccurrences(of: "{language}", with: selectedLanguage.displayName))
            .alert(LocalizationHelper.getCommonText("explanation", for: nativeLanguage), isPresented: $showExplanation) {
                Button("OK", role: .cancel) {}
            } message: {
                if let dict = currentQuiz?.explanation {
                    // 適切な言語の解説を優先的に表示
                    let explanationText = dict[nativeLanguage.rawValue] ?? dict.values.first ?? LocalizationHelper.getCommonText("noExplanationAvailable", for: nativeLanguage)
                    Text(explanationText)
                } else {
                    Text(LocalizationHelper.getCommonText("noExplanationAvailable", for: nativeLanguage))
                }
            }
            .sheet(isPresented: $showResultModal) {
                ResultModalView(
                    isCorrect: isCorrectAnswer,
                    correctAnswer: currentQuiz?.answer ?? "",
                    userAnswer: selectedWords.joined(separator: " "),
                    nativeLanguage: nativeLanguage,
                    onDismiss: {
                        showResultModal = false
                        // 次の問題へ進む
                        debugCreateOrFetchProblem()
                    }
                )
            }
            .sheet(isPresented: $showUploadModal) {
                UploadModalView(
                    imageUrl: currentQuiz?.imageUrl ?? "",
                    nativeLanguage: nativeLanguage,
                    onDismiss: {
                        showUploadModal = false
                    }
                )
            }
            .onAppear {
                sessionStartTime = Date()
                // Duolingo風UIセットアップ
                if let quiz = currentQuiz {
                    debugMessage += "[onAppear] currentQuiz exists, answer: \(quiz.answer), options: \(quiz.options ?? [])\n"
                    
                    // availableWordsが既に設定されている場合はスキップ
                    if !availableWords.isEmpty {
                        debugMessage += "[onAppear] availableWords already set: \(availableWords)\n"
                        return
                    }
                    
                    if let opts = quiz.options, !opts.isEmpty {
                        setupWords(opts)
                        debugMessage += "[onAppear] Set up words from options: \(availableWords)\n"
                    } else {
                        // optionsが無い場合はanswerから生成
                        debugMessage += "[onAppear] No options, generating from answer\n"
                        let words = quiz.answer.components(separatedBy: " ").filter { !$0.isEmpty }
                        if !words.isEmpty {
                            setupWords(words)
                            debugMessage += "[onAppear] Generated words from answer: \(availableWords)\n"
                        } else {
                            debugMessage += "[onAppear] Failed to generate words from answer\n"
                        }
                    }
                }
            }
            .alert(LocalizationHelper.getCommonText("grammarCheckResult", for: nativeLanguage), isPresented: $showGrammarAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(grammarFeedbackMessage)
            }
        }
    }
    
    // QuizからExtendedQuizへの変換ヘルパー
    private func quizToExtendedQuiz(_ quiz: Quiz) -> ExtendedQuiz? {
        // ProblemTypeの文字列をenumに変換
        guard let problemType = ProblemType(rawValue: quiz.problemType) else {
            // rawValueがマッチしない場合、デフォルトでwordArrangementを使用
            let extendedQuiz = ExtendedQuiz(
                problemID: quiz.problemID,
                language: selectedLanguage,
                problemType: .wordArrangement,
                imageMode: .normal,
                question: quiz.question,
                answer: quiz.answer,
                imageUrl: quiz.imageUrl,
                audioUrl: nil,
                options: quiz.options,
                blankPositions: nil,
                hints: nil,
                difficulty: 3,
                tags: nil,
                explanation: quiz.explanation,
                metadata: nil,
                createdByGroup: quiz.createdByGroup,
                createdByParticipant: quiz.createdByParticipant,
                createdAt: Date(),
                vlmGenerated: false,
                vlmModel: nil,
                notified: nil,
                communityPhotoID: nil
            )
            return extendedQuiz
        }
        
        return ExtendedQuiz(
            problemID: quiz.problemID,
            language: selectedLanguage,
            problemType: problemType,
            imageMode: .normal,
            question: quiz.question,
            answer: quiz.answer,
            imageUrl: quiz.imageUrl,
            audioUrl: nil,
            options: quiz.options,
            blankPositions: nil,
            hints: nil,
            difficulty: 3,
            tags: nil,
            explanation: quiz.explanation,
            metadata: nil,
            createdByGroup: quiz.createdByGroup,
            createdByParticipant: quiz.createdByParticipant,
            createdAt: Date(),
            vlmGenerated: false,
            vlmModel: nil,
            notified: nil,
            communityPhotoID: nil
        )
    }
    
    // MARK: - 文法チェック関連
    func checkGrammar(userAnswer: String, correctAnswer: String) {
        debugMessage += "[文法チェック] 開始: \(userAnswer)\n"
    }
    
    func showGrammarFeedback(feedback: VLMFeedback, isCorrect: Bool) {
        var message = isCorrect ? "正解です！\n\n" : "惜しい！\n\n"
        message += feedback.feedback + "\n\n"
        
        if let suggestions = feedback.suggestions, !suggestions.isEmpty {
            message += "提案:\n"
            for suggestion in suggestions {
                message += "• \(suggestion)\n"
            }
            message += "\n"
        }
        
        if let grammarErrors = feedback.grammarErrors, !grammarErrors.isEmpty {
            message += "文法エラー:\n"
            for error in grammarErrors {
                message += "• \(error)\n"
            }
        }
        
        message += "\nスコア: \(Int(feedback.score * 100))点"
        
        grammarFeedbackMessage = message
        showGrammarAlert = true
    }
    
    // MARK: Duolingo-style
    func setupWords(_ words: [String]) {
        availableWords = words.shuffled()
        selectedWords = []
    }
    func selectWord(_ w: String) {
        selectedWords.append(w)
        if let i = availableWords.firstIndex(of: w) {
            availableWords.remove(at: i)
        }
    }
    func resetWordsForQuiz(_ quiz: Quiz) {
        if let opts = quiz.options {
            setupWords(opts)
        }
    }
    func checkDuolingoAnswer(for quiz: Quiz) {
        let userAnswer = selectedWords.joined(separator: " ")
        let isCorrect = (userAnswer.lowercased() == quiz.answer.lowercased())
        
        // モーダル表示用のフラグを設定
        isCorrectAnswer = isCorrect
        showResultModal = true
        
        if isCorrect { 
            correctCount += 1
            SoundEffectManager.shared.playCorrectSound()
            SoundEffectManager.shared.playHapticFeedback(style: .light)
            // 正解文章を読み上げ
            let selectedLanguage = SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
            TTSManager.shared.speak(text: quiz.answer, language: selectedLanguage)
        } else {
            SoundEffectManager.shared.playIncorrectSound()
            SoundEffectManager.shared.playHapticFeedback(style: .heavy)
        }
        
        // 文法チェックのためにGemini APIを呼び出す
        checkGrammar(userAnswer: userAnswer, correctAnswer: quiz.answer)
        
        // ProblemLogを保存
        let selectedLanguage = SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
        Task {
            // Gemini APIで文法評価を取得
            var vlmFeedbackText: String? = nil
            var errorAnalysis: [String] = []
            
            do {
                let feedback = try await ProblemGenerationService.shared.evaluateAnswer(
                    userAnswer: userAnswer,
                    correctAnswer: quiz.answer,
                    problemType: .wordArrangement,
                    language: selectedLanguage
                )
                vlmFeedbackText = feedback.feedback
                errorAnalysis = feedback.suggestions ?? []
                
                // フィードバックを表示
                DispatchQueue.main.async {
                    self.showGrammarFeedback(feedback: feedback, isCorrect: isCorrect)
                }
            } catch {
                debugMessage += "文法チェックエラー: \(error.localizedDescription)\n"
                if !isCorrect {
                    errorAnalysis = ["正解: \(quiz.answer)"]
                }
            }
            
            let log = ExtendedProblemLog(
                logID: UUID().uuidString,
                problemID: quiz.problemID,
                participantID: participantID,
                groupID: groupID,
                language: selectedLanguage,
                problemType: .wordArrangement,
                imageUrl: quiz.imageUrl,
                question: quiz.question,
                correctAnswer: quiz.answer,
                userAnswer: userAnswer,
                isCorrect: isCorrect,
                score: isCorrect ? 1.0 : 0.0,
                timeSpentSeconds: Int(Date().timeIntervalSince(sessionStartTime)),
                audioRecordingUrl: nil,
                vlmFeedback: vlmFeedbackText,
                errorAnalysis: errorAnalysis,
                startedAt: sessionStartTime,
                completedAt: Date(),
                sessionID: UUID().uuidString,
                previousAttempts: 0
            )
            
            do {
                try await dataPersistence.saveProblemLog(log)
                print("[ContentView] Problem log saved successfully: \(log.logID)")
            } catch {
                print("[ContentView] Failed to save problem log: \(error)")
                debugMessage += "ログ保存エラー: \(error.localizedDescription)\n"
            }
        }
        
        selectedWords = []
        availableWords = []
        sessionStartTime = Date() // 次の問題用にリセット
    }
    
//    // MARK: - 従来 checkAnswer
//    
//    func checkAnswer(quiz: Quiz) {
//        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
//        let isCorrect = (trimmed.lowercased() == quiz.answer.lowercased())
//        if isCorrect {
//            correctCount += 1
//        }
//        
//        let log = ProblemLog(
//            logID: UUID().uuidString,
//            problemID: quiz.problemID,
//            participantID: participantID,
//            groupID: groupID,
//            imageUrl: quiz.imageUrl,
//            question: quiz.question,
//            correctAnswer: quiz.answer,
//            userAnswer: trimmed,
//            isCorrect: isCorrect,
//            timestamp: Date().timeIntervalSince1970
//        )
//        ServiceManager.shared.saveProblemLogToFirebase(log)
//        ServiceManager.shared.saveLogToLocal(log)
//        
//        // 次の問題へ
//        userAnswer = ""
//    }
    
    // MARK: - 音声再生（旧実装）
    func speakText(_ text: String, language: SupportedLanguage) {
        // TTSManagerを使用するように移行
        TTSManager.shared.speak(text: text, language: language)
    }
    
    // MARK: - デバッグ: 新規問題作成 or 取得
    func debugCreateOrFetchProblem() {
        let initialMsg = "debugCreateOrFetchProblem() CALLED. isResearchMode=\(isResearchMode), groupID=\(groupID)\n"
        debugMessage += initialMsg
        print(initialMsg)
        
        // 既存の画像URLがある場合は、それを使って新しい問題を生成
        if let currentImageUrl = currentQuiz?.imageUrl {
            debugMessage += "既存の画像で新しい問題を生成\n"
            generateNewProblemWithSameImage(imageUrl: currentImageUrl)
        } else if isResearchMode {
            switch groupID {
            case "A":
                debugMessage += " -> createProblemForGroupA()\n"
                createProblemForGroupA()
            case "B", "C":
                debugMessage += " -> fetchProblemsFromGroupA()\n"
                fetchProblemsFromGroupA()
            default:
                debugMessage += " -> fetchProblemsFromGroupA() (default)\n"
                fetchProblemsFromGroupA()
            }
        } else {
            debugMessage += "通常モードです(未実装)\n"
            print(debugMessage)
        }
    }
    
    // 同じ画像で新しい問題を生成
    func generateNewProblemWithSameImage(imageUrl: String) {
        debugMessage += "[generateNewProblemWithSameImage] imageUrl = \(imageUrl)\n"
        
        callGeminiForProblem(secureUrl: imageUrl) { quiz in
            DispatchQueue.main.async {
                if var quiz = quiz {
                    self.debugMessage += "新しい問題生成成功: problemID=\(quiz.problemID)\n"
                    self.debugMessage += "  Answer: \(quiz.answer)\n"
                    self.debugMessage += "  Options: \(quiz.options ?? [])\n"
                    
                    // 前の問題と同じ画像URLを保持
                    quiz.imageUrl = imageUrl
                    
                    self.currentQuiz = quiz
                    self.quizzes.append(quiz)
                    
                    // 単語リストをリセット
                    if let opts = quiz.options, !opts.isEmpty {
                        self.setupWords(opts)
                        self.debugMessage += "Options setup successfully: \(opts)\n"
                    } else {
                        self.debugMessage += "WARNING: No options in new quiz! Answer: \(quiz.answer)\n"
                        let words = quiz.answer.components(separatedBy: " ").filter { !$0.isEmpty }
                        if !words.isEmpty {
                            quiz.options = words.shuffled()
                            self.setupWords(quiz.options ?? [])
                            self.debugMessage += "Generated options from answer: \(quiz.options ?? [])\n"
                        }
                    }
                } else {
                    self.debugMessage += "新しい問題の生成に失敗\n"
                }
            }
        }
    }
    
    // MARK: - 実験群(A)新規問題作成 (写真取得ロジック変更)
    func createProblemForGroupA() {
        debugMessage += "[createProblemForGroupA] 開始\n"
        
        // 改善: 1日前, 3日前, 1週間前,...のカメラ写真を取得
        if let asset = PhotoFetcher.shared.fetchRandomCameraPhoto() {
            debugMessage += "[createProblemForGroupA] fetchRandomCameraPhoto success.\n"
            let manager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            
            manager.requestImage(for: asset, targetSize: CGSize(width: 800, height: 800),
                                 contentMode: .aspectFit, options: requestOptions) { image, info in
                guard let uiImage = image else {
                    let msg = "uiImage is nil. 画像取得に失敗\n"
                    self.debugMessage += msg
                    return
                }
                guard let compressedData = uiImage.jpegData(compressionQuality: 0.7) else {
                    let msg = "JPEG圧縮に失敗\n"
                    self.debugMessage += msg
                    return
                }
                
                self.debugMessage += "[createProblemForGroupA] uploadToCloudinary...\n"
                ServiceManager.shared.uploadToCloudinary(imageData: compressedData,
                                                         preset: "testtttt",
                                                         cloudName: "dy53z9iup") { secureUrl in
                    DispatchQueue.main.async {
                        if let secureUrl = secureUrl {
                            self.debugMessage += "Cloudinaryアップロード成功: \(secureUrl)\n"
                            self.callChatGPTForFinnish(secureUrl: secureUrl) { quiz in
                                DispatchQueue.main.async {
                                    if var quiz = quiz {
                                        self.debugMessage += "ChatGPTからクイズ生成成功: problemID=\(quiz.problemID)\n"
                                        self.debugMessage += "  Answer: \(quiz.answer)\n"
                                        self.debugMessage += "  Options (before): \(quiz.options ?? [])\n"
                                        
                                        // optionsが空の場合は必ずanswerから生成
                                        if quiz.options == nil || quiz.options?.isEmpty == true {
                                            let words = quiz.answer.components(separatedBy: " ").filter { !$0.isEmpty }
                                            quiz.options = words.shuffled()
                                            self.debugMessage += "  Generated options: \(quiz.options ?? [])\n"
                                        }
                                        
                                        ServiceManager.shared.saveProblemToFirebase(quiz) { success in
                                            self.debugMessage += "saveProblemToFirebase: \(success ? "成功" : "失敗")\n"
                                        }
                                        self.currentQuiz = quiz
                                        self.quizzes.append(quiz)
                                        // Duolingo風UIの単語リスト初期化
                                        if let opts = quiz.options, !opts.isEmpty {
                                            self.setupWords(opts)
                                            self.debugMessage += "Options setup successfully: \(opts)\n"
                                        } else {
                                            self.debugMessage += "WARNING: No options in quiz! Answer: \(quiz.answer)\n"
                                            // answerから単語を生成
                                            let words = quiz.answer.components(separatedBy: " ").filter { !$0.isEmpty }
                                            if !words.isEmpty {
                                                quiz.options = words.shuffled()
                                                self.setupWords(quiz.options ?? [])
                                                self.debugMessage += "Generated options from answer: \(quiz.options ?? [])\n"
                                            }
                                        }
                                    } else {
                                        self.debugMessage += "ChatGPTクイズ生成に失敗(null)\n"
                                    }
                                }
                            }
                        } else {
                            let msg = "Cloudinaryアップロードに失敗\n"
                            self.debugMessage += msg
                        }
                    }
                }
            }
        } else {
            let msg = "No camera photo found for specified intervals.\n"
            debugMessage += msg
        }
    }
    
    // Gemini API呼び出しで問題を作成
    func callGeminiForProblem(secureUrl: String, completion: @escaping (Quiz?) -> Void) {
        self.debugMessage += "[callGeminiForProblem] secureUrl = \(secureUrl)\n"
        
        Task {
            do {
                // 現在の言語設定を取得
                let currentLanguage = SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
                
                // Gemini APIで問題生成
                let extendedQuiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: secureUrl,
                    language: currentLanguage,
                    problemType: .wordArrangement,
                    nativeLanguage: .japanese  // TODO: ユーザー設定から取得
                )
                
                // ExtendedQuizからQuizに変換
                let quiz = Quiz(
                    problemID: extendedQuiz.problemID,
                    question: extendedQuiz.question,
                    answer: extendedQuiz.answer,
                    imageUrl: extendedQuiz.imageUrl,
                    explanation: extendedQuiz.explanation,
                    options: extendedQuiz.options,
                    problemType: extendedQuiz.problemType.rawValue,
                    createdByGroup: extendedQuiz.createdByGroup,
                    createdByParticipant: extendedQuiz.createdByParticipant
                )
                
                DispatchQueue.main.async {
                    self.debugMessage += "[Gemini] 問題生成成功\n"
                    self.debugMessage += "[Gemini] Quiz options: \(quiz.options ?? [])\n"
                    self.debugMessage += "[Gemini] Quiz answer: \(quiz.answer)\n"
                    completion(quiz)
                }
            } catch {
                DispatchQueue.main.async {
                    self.debugMessage += "[Gemini] エラー: \(error.localizedDescription)\n"
                    completion(nil)
                }
            }
        }
    }
    
    // 旧ChatGPT関数（互換性のため残す）
    func callChatGPTForFinnish(secureUrl: String, completion: @escaping (Quiz?) -> Void) {
        // Gemini APIを使用
        callGeminiForProblem(secureUrl: secureUrl, completion: completion)
    }
    
    func fetchProblemsFromGroupA() {
        debugMessage += "[fetchProblemsFromGroupA] 開始\n"
        ServiceManager.shared.fetchProblemsFromFirebase(group: "A") { qs in
            DispatchQueue.main.async {
                self.debugMessage += "fetchProblemsFromFirebase: \(qs.count)件\n"
                if qs.isEmpty {
                    self.debugMessage += "B/C向けに問題がありません。\n"
                } else {
                    var randomQ = qs.randomElement()!
                    self.debugMessage += "ランダム選択: problemID=\(randomQ.problemID)\n"
                    self.currentQuiz = randomQ
                    self.quizzes.append(randomQ)
                    // Duolingo風UI 初期化
                    if let opts = randomQ.options, !opts.isEmpty {
                        self.setupWords(opts)
                        self.debugMessage += "Options setup successfully: \(opts)\n"
                    } else {
                        self.debugMessage += "WARNING: No options in fetched quiz! Answer: \(randomQ.answer)\n"
                        // answerから単語を生成
                        let words = randomQ.answer.components(separatedBy: " ").filter { !$0.isEmpty }
                        if !words.isEmpty {
                            randomQ.options = words.shuffled()
                            self.setupWords(randomQ.options ?? [])
                            self.debugMessage += "Generated options from answer: \(randomQ.options ?? [])\n"
                        }
                    }
                }
            }
        }
    }
}
