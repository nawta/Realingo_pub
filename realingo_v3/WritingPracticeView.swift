//
//  WritingPracticeView.swift
//  realingo_v3
//
//  ライティング練習画面
//  参照: specification.md - ライティング回答方式
//  関連: ServiceManager.swift (VLM添削), Models.swift (データモデル)
//

import SwiftUI
import Foundation

struct WritingPracticeView: View {
    @State private var userAnswer = ""
    @State private var currentQuiz: ExtendedQuiz?
    @State private var showResult = false
    @State private var vlmFeedback = ""
    @State private var isProcessing = false
    @State private var sessionStartTime = Date()
    @State private var keyboardHeight: CGFloat = 0
    
    // 外部からExtendedQuizを受け取るためのイニシャライザ
    init(quiz: ExtendedQuiz? = nil) {
        _currentQuiz = State(initialValue: quiz)
    }
    
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @AppStorage("participantID") private var participantID = ""
    @AppStorage("groupID") private var groupID = ""
    
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var dataPersistence = DataPersistenceManager.shared
    @StateObject private var vlmManager = VLMManager.shared
    @State private var vlmFeedbackDetail: VLMFeedback?
    @FocusState private var isTextFieldFocused: Bool
    @State private var showKeyboardAlert = false
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    if let quiz = currentQuiz {
                        // 画像表示
                        imageSection(quiz: quiz)
                        
                        // 問題文
                        Text(quiz.question)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // ヒント（あれば）
                        hintsSection(quiz: quiz)
                        
                        // Firebase Storage アップロードボタン（モック）
                        uploadButton(quiz: quiz)
                        
                        // 回答入力エリア
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(LocalizationHelper.getCommonText("yourAnswer", for: nativeLanguage) + ":")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if !userAnswer.isEmpty {
                                    Text("\(userAnswer.count) " + LocalizationHelper.getCommonText("characters", for: nativeLanguage))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            TextEditor(text: $userAnswer)
                                .frame(minHeight: 150)
                                .padding(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .focused($isTextFieldFocused)
                                .disabled(showResult)
                                .id("textEditor")
                            
                            // 言語別の入力ヒント
                            Text(getInputHint())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        
                        // 提出ボタン
                        if !showResult {
                            Button(action: submitAnswer) {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(LocalizationHelper.getCommonText("submitAnswer", for: nativeLanguage))
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(userAnswer.isEmpty || isProcessing ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(userAnswer.isEmpty || isProcessing)
                        }
                        
                        // 結果表示
                        if showResult && !isProcessing {
                            VStack(spacing: 15) {
                                // 模範解答
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(LocalizationHelper.getCommonText("modelAnswer", for: nativeLanguage) + ":")
                                        .font(.headline)
                                    Text(quiz.answer)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                
                                // VLMフィードバック
                                vlmFeedbackSection()
                                
                                // 次の問題へ
                                Button(LocalizationHelper.getCommonText("next", for: nativeLanguage)) {
                                    loadNextProblem()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                    } else {
                        // 問題読み込み中
                        ProgressView(LocalizationHelper.getCommonText("loadingQuestion", for: nativeLanguage))
                            .padding(50)
                            .onAppear {
                                if currentQuiz == nil {
                                    loadNextProblem()
                                }
                            }
                    }
                }
                .padding(.bottom, keyboardHeight)
            }
            .onChange(of: isTextFieldFocused) { _, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("textEditor", anchor: .center)
                    }
                }
            }
        }
        .navigationTitle("\(selectedLanguage.displayName) " + LocalizationHelper.getProblemTypeText(.writing, for: nativeLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LocalizationHelper.getCommonText("done", for: nativeLanguage)) {
                    isTextFieldFocused = false
                }
            }
        }
        .onAppear {
            sessionStartTime = Date()
            setupKeyboardObservers()
            
            // キーボードチェック
            if !selectedLanguage.isKeyboardInstalled() {
                showKeyboardAlert = true
            }
        }
        .alert(LocalizationHelper.getCommonText("keyboardNotInstalled", for: nativeLanguage), isPresented: $showKeyboardAlert) {
            Button(LocalizationHelper.getCommonText("openSettings", for: nativeLanguage)) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(LocalizationHelper.getCommonText("ok", for: nativeLanguage)) { }
        } message: {
            Text(LocalizationHelper.getCommonText("installKeyboardMessage", for: nativeLanguage).replacingOccurrences(of: "{LANGUAGE}", with: selectedLanguage.displayName))
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func imageSection(quiz: ExtendedQuiz) -> some View {
        if let imageUrl = quiz.imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(10)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                    )
            }
        }
    }
    
    @ViewBuilder
    private func hintsSection(quiz: ExtendedQuiz) -> some View {
        if let hints = quiz.hints, !hints.isEmpty, !showResult {
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizationHelper.getCommonText("hint", for: nativeLanguage) + ":")
                    .font(.caption)
                    .fontWeight(.semibold)
                ForEach(hints, id: \.self) { hint in
                    Text("• \(hint)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func uploadButton(quiz: ExtendedQuiz) -> some View {
        PhotoUploadButton(quiz: quiz)
    }
    
    @ViewBuilder
    private func vlmFeedbackSection() -> some View {
        if let feedback = vlmFeedbackDetail {
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizationHelper.getCommonText("feedback", for: nativeLanguage) + ":")
                    .font(.headline)
                
                Text(feedback.feedback)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                // スコア表示
                scoreSection(feedback: feedback)
                
                // 詳細分析
                if let detailedAnalysis = feedback.detailedAnalysis, !detailedAnalysis.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(LocalizationHelper.getCommonText("analysis", for: nativeLanguage), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(detailedAnalysis)
                            .font(.caption)
                            .padding(.leading)
                    }
                }
                
                // 改善点
                improvementsSection(feedback: feedback)
            }
        }
    }
    
    @ViewBuilder
    private func scoreSection(feedback: VLMFeedback) -> some View {
        if let grammarScore = feedback.grammarErrors?.count,
           let vocabularyScore = feedback.vocabularyErrors?.count {
            HStack(spacing: 15) {
                WritingScoreIndicator(label: LocalizationHelper.getCommonText("grammar", for: nativeLanguage), score: 10 - min(grammarScore, 10))
                WritingScoreIndicator(label: LocalizationHelper.getCommonText("vocabulary", for: nativeLanguage), score: 10 - min(vocabularyScore, 10))
                WritingScoreIndicator(label: LocalizationHelper.getCommonText("content", for: nativeLanguage), score: Int(feedback.score * 10))
                WritingScoreIndicator(label: LocalizationHelper.getCommonText("fluency", for: nativeLanguage), score: Int((feedback.naturalness ?? 0.5) * 10))
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func improvementsSection(feedback: VLMFeedback) -> some View {
        if let suggestions = feedback.suggestions, !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Label(LocalizationHelper.getCommonText("improvements", for: nativeLanguage), systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                ForEach(suggestions, id: \.self) { suggestion in
                    Text("• \(suggestion)")
                        .font(.caption)
                        .padding(.leading)
                }
            }
        }
    }
    
    private func getInputHint() -> String {
        return LocalizationHelper.getCommonText("writeYourAnswer", for: nativeLanguage)
    }
    
    private func loadNextProblem() {
        isProcessing = true
        
        Task {
            do {
                // Gemini APIでライティング問題を生成
                let newQuiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: "https://picsum.photos/400/300", // 今はランダム画像を使用
                    language: selectedLanguage,
                    problemType: .writing,
                    nativeLanguage: .japanese  // TODO: ユーザー設定から取得
                )
                
                await MainActor.run {
                    self.currentQuiz = newQuiz
                    self.showResult = false
                    self.vlmFeedback = ""
                    self.vlmFeedbackDetail = nil
                    self.userAnswer = ""
                    self.isTextFieldFocused = false
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    print("Error generating writing problem: \(error)")
                    // エラー時はダミーデータを使用
                    self.loadDummyProblem()
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func loadDummyProblem() {
        // バックアップ用のダミーデータ
        currentQuiz = ExtendedQuiz(
            problemID: UUID().uuidString,
            language: selectedLanguage,
            problemType: .writing,
            imageMode: .immediate,
            question: LocalizationHelper.getCommonText("writingInstruction", for: nativeLanguage),
            answer: selectedLanguage == .finnish ? "Tämä on kaunis luonnonmaisema. Sininen taivas ja valkoiset pilvet näkyvät. Kaukana näkyy vuoria ja edessä on vihreä niitty." : "This is a beautiful natural landscape. Blue sky and white clouds are visible. Mountains can be seen in the distance and there is a green meadow in front.",
            imageUrl: "https://picsum.photos/400/300",
            audioUrl: nil,
            options: nil,
            blankPositions: nil,
            hints: [
                LocalizationHelper.getCommonText("describeScenery", for: nativeLanguage),
                LocalizationHelper.getCommonText("useColorsAndShapes", for: nativeLanguage),
                LocalizationHelper.getCommonText("includeYourFeelings", for: nativeLanguage)
            ],
            difficulty: 3,
            tags: ["nature", "description", "writing"],
            explanation: nil,
            createdByGroup: groupID,
            createdByParticipant: participantID,
            createdAt: Date(),
            vlmGenerated: false,
            vlmModel: nil
        )
        
        showResult = false
        vlmFeedback = ""
        vlmFeedbackDetail = nil
        userAnswer = ""
        isTextFieldFocused = false
    }
    
    private func submitAnswer() {
        guard let quiz = currentQuiz, !userAnswer.isEmpty else { return }
        
        isProcessing = true
        isTextFieldFocused = false
        
        // VLMによる添削
        Task {
            do {
                // VLMフィードバックを取得
                var feedbackResult: VLMFeedback?
                var feedbackText = ""
                
                // まずGemini APIで採点を試みる
                do {
                    feedbackResult = try await ProblemGenerationService.shared.evaluateAnswer(
                        userAnswer: userAnswer,
                        correctAnswer: quiz.answer,
                        problemType: .writing,
                        language: selectedLanguage
                    )
                    feedbackText = feedbackResult?.feedback ?? ""
                } catch {
                    // Gemini APIが失敗した場合はシミュレート
                    await simulateVLMFeedback()
                    feedbackText = self.vlmFeedback
                }
                
                // 回答ログを保存
                let score = feedbackResult?.score ?? calculateScore()
                let log = ExtendedProblemLog(
                    logID: UUID().uuidString,
                    problemID: quiz.problemID,
                    participantID: participantID,
                    groupID: groupID,
                    language: selectedLanguage,
                    problemType: .writing,
                    imageUrl: quiz.imageUrl,
                    question: quiz.question,
                    correctAnswer: quiz.answer,
                    userAnswer: userAnswer,
                    isCorrect: score >= 0.7,
                    score: score,
                    timeSpentSeconds: Int(Date().timeIntervalSince(sessionStartTime)),
                    audioRecordingUrl: nil,
                    vlmFeedback: feedbackText,
                    errorAnalysis: feedbackResult?.suggestions ?? analyzeErrors(),
                    startedAt: sessionStartTime,
                    completedAt: Date(),
                    sessionID: UUID().uuidString,
                    previousAttempts: 0
                )
                
                // Firebaseに保存
                try? await dataPersistence.saveProblemLog(log)
                
                DispatchQueue.main.async {
                    self.vlmFeedbackDetail = feedbackResult
                    self.showResult = true
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func calculateScore() -> Double {
        // 仮のスコア計算（文字数ベース）
        let minLength = 20
        let idealLength = 100
        let length = userAnswer.count
        
        if length < minLength {
            return Double(length) / Double(minLength) * 0.5
        } else if length <= idealLength {
            return 0.5 + (Double(length - minLength) / Double(idealLength - minLength)) * 0.5
        } else {
            return min(1.0, 0.9 + (Double(length - idealLength) / Double(idealLength)) * 0.1)
        }
    }
    
    private func analyzeErrors() -> [String] {
        // 仮のエラー分析
        var errors: [String] = []
        
        if userAnswer.count < 20 {
            errors.append("文章が短すぎます")
        }
        
        if !userAnswer.contains(".") && !userAnswer.contains("。") && !userAnswer.contains("!") && !userAnswer.contains("?") {
            errors.append("句読点が不足しています")
        }
        
        return errors
    }
    
    private func simulateVLMFeedback() async {
        // 実際のVLM実装までの仮実装
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
        
        let feedbacks = [
            "よく書けています！文法的に正確で、描写も具体的です。次は感情表現も加えてみましょう。",
            "基本的な内容は伝わっています。もう少し詳細な描写を加えると、より豊かな文章になります。",
            "語彙の選択が適切です。文と文のつながりをより自然にするため、接続詞を活用してみてください。",
            "しっかりとした構成で書けています。次は比喩表現なども使って、より生き生きとした文章を目指しましょう。"
        ]
        
        DispatchQueue.main.async {
            self.vlmFeedback = feedbacks.randomElement() ?? ""
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            withAnimation {
                self.keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation {
                self.keyboardHeight = 0
            }
        }
    }
}

// スコア表示用のコンポーネント
struct WritingScoreIndicator: View {
    let label: String
    let score: Int
    
    var body: some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(score)/10")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(scoreColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var scoreColor: Color {
        switch score {
        case 8...10: return .green
        case 6..<8: return .blue
        case 4..<6: return .orange
        default: return .red
        }
    }
}

#Preview {
    NavigationStack {
        WritingPracticeView()
    }
}