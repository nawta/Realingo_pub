//
//  SpeakingPracticeView.swift
//  realingo_v3
//
//  スピーキング練習画面
//  参照: specification.md - スピーキング回答方式
//  関連: SpeechRecognitionManager.swift (音声認識), ServiceManager.swift (VLM添削)
//

import SwiftUI
import AVFoundation

struct SpeakingPracticeView: View {
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var serviceManager = ServiceManager.shared
    @StateObject private var dataPersistence = DataPersistenceManager.shared
    @StateObject private var vlmManager = VLMManager.shared
    @State private var currentQuiz: ExtendedQuiz?
    @State private var showResult = false
    @State private var vlmFeedback = ""
    @State private var vlmFeedbackDetail: VLMFeedback?
    @State private var isProcessing = false
    @State private var sessionStartTime = Date()
    
    // 外部からExtendedQuizを受け取るためのイニシャライザ
    init(quiz: ExtendedQuiz? = nil) {
        _currentQuiz = State(initialValue: quiz)
    }
    
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    @AppStorage("participantID") private var participantID = ""
    @AppStorage("groupID") private var groupID = ""
    
    var body: some View {
        VStack(spacing: 20) {
            if !speechManager.isAuthorized {
                // 権限リクエスト画面
                VStack(spacing: 20) {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text(LocalizationHelper.getCommonText("speechPermissionRequired", for: nativeLanguage))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(speechManager.errorMessage ?? LocalizationHelper.getCommonText("allowSpeechInSettings", for: nativeLanguage))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button(LocalizationHelper.getCommonText("openSettings", for: nativeLanguage)) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let quiz = currentQuiz {
                // 問題表示
                ScrollView {
                    VStack(spacing: 20) {
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
                        
                        // 録音ボタンと認識結果
                        VStack(spacing: 15) {
                            // 録音ボタン
                            Button(action: {
                                if speechManager.isRecording {
                                    speechManager.stopRecording()
                                    processAnswer()
                                } else {
                                    do {
                                        try speechManager.startRecording()
                                    } catch {
                                        print("Recording failed: \(error)")
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(speechManager.isRecording ? Color.red : Color.blue)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: speechManager.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(speechManager.isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: speechManager.isRecording)
                            
                            Text(speechManager.isRecording ? LocalizationHelper.getCommonText("recording", for: nativeLanguage) : LocalizationHelper.getCommonText("tapToSpeak", for: nativeLanguage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // 認識されたテキスト
                            if !speechManager.recognizedText.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(LocalizationHelper.getCommonText("recognitionResult", for: nativeLanguage) + ":")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    
                                    Text(speechManager.recognizedText)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // 結果表示
                        if showResult && !isProcessing {
                            VStack(spacing: 15) {
                                // 正解
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(LocalizationHelper.getCommonText("modelAnswer", for: nativeLanguage) + ":")
                                        .font(.caption)
                                        .fontWeight(.semibold)
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
                        }
                        
                        if isProcessing {
                            ProgressView(LocalizationHelper.getCommonText("processing", for: nativeLanguage))
                                .padding()
                        }
                    }
                    .padding()
                }
            } else {
                // 問題読み込み中
                ProgressView(LocalizationHelper.getCommonText("loadingQuestion", for: nativeLanguage))
                    .onAppear {
                        if currentQuiz == nil {
                            loadNextProblem()
                        }
                    }
            }
        }
        .navigationTitle("\(selectedLanguage.displayName) \(LocalizationHelper.getProblemTypeText(.speaking, for: nativeLanguage))")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            speechManager.changeLanguage(selectedLanguage)
            sessionStartTime = Date()
        }
    }
    
    private func loadNextProblem() {
        isProcessing = true
        
        Task {
            do {
                // Gemini APIでスピーキング問題を生成
                let newQuiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: "https://picsum.photos/400/300", // 今はランダム画像を使用
                    language: selectedLanguage,
                    problemType: .speaking,
                    nativeLanguage: nativeLanguage
                )
                
                await MainActor.run {
                    self.currentQuiz = newQuiz
                    self.showResult = false
                    self.vlmFeedback = ""
                    self.vlmFeedbackDetail = nil
                    self.speechManager.recognizedText = ""
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    print("Error generating speaking problem: \(error)")
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
            problemType: .speaking,
            imageMode: .immediate,
            question: LocalizationHelper.getCommonText("speakingInstruction", for: nativeLanguage),
            answer: selectedLanguage == .finnish ? "Tämä on kaunis maisema. Näen järven ja metsän." : "This is a beautiful landscape. I can see a lake and forest.",
            imageUrl: "https://picsum.photos/400/300",
            audioUrl: nil,
            options: nil,
            blankPositions: nil,
            hints: [
                LocalizationHelper.getCommonText("describeImage", for: nativeLanguage),
                LocalizationHelper.getCommonText("useAdjectives", for: nativeLanguage)
            ],
            difficulty: 3,
            tags: ["nature", "description"],
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
        speechManager.recognizedText = ""
    }
    
    private func processAnswer() {
        guard let quiz = currentQuiz else { return }
        
        isProcessing = true
        
        // VLMによる添削
        Task {
            do {
                // VLMフィードバックを取得
                var feedbackResult: VLMFeedback?
                var feedbackText = ""
                
                // まずGemini APIで採点を試みる
                do {
                    feedbackResult = try await ProblemGenerationService.shared.evaluateAnswer(
                        userAnswer: speechManager.recognizedText,
                        correctAnswer: quiz.answer,
                        problemType: .speaking,
                        language: selectedLanguage
                    )
                    feedbackText = feedbackResult?.feedback ?? ""
                } catch {
                    // Gemini APIが失敗した場合はシミュレート
                    await simulateVLMFeedback()
                    feedbackText = self.vlmFeedback
                }
                
                // 回答ログを保存
                let score = feedbackResult?.score ?? 0.8
                let log = ExtendedProblemLog(
                    logID: UUID().uuidString,
                    problemID: quiz.problemID,
                    participantID: participantID,
                    groupID: groupID,
                    language: selectedLanguage,
                    problemType: .speaking,
                    imageUrl: quiz.imageUrl,
                    question: quiz.question,
                    correctAnswer: quiz.answer,
                    userAnswer: speechManager.recognizedText,
                    isCorrect: score >= 0.7,
                    score: score,
                    timeSpentSeconds: Int(Date().timeIntervalSince(sessionStartTime)),
                    audioRecordingUrl: speechManager.getLastRecordingURL()?.absoluteString,
                    vlmFeedback: feedbackText,
                    errorAnalysis: feedbackResult?.suggestions,
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
    
    private func simulateVLMFeedback() async {
        // 実際のVLM実装までの仮実装
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒待機
        
        let feedbacks = [
            "よく話せています！文法は正確で、発音も明瞭です。",
            "基本的な内容は伝わっていますが、もう少し詳細な描写があるとより良いでしょう。",
            "語彙の選択が適切です。次は時制にも注意してみましょう。",
            "自然な表現ができています。より流暢に話すには、接続詞を活用してみてください。"
        ]
        
        DispatchQueue.main.async {
            self.vlmFeedback = feedbacks.randomElement() ?? ""
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
        if let hints = quiz.hints, !hints.isEmpty {
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
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(feedback.feedback)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                // スコア表示
                if let grammarScore = feedback.grammarErrors?.count,
                   let vocabularyScore = feedback.vocabularyErrors?.count {
                    HStack(spacing: 15) {
                        ScoreIndicator(label: LocalizationHelper.getCommonText("grammar", for: nativeLanguage), score: 10 - min(grammarScore, 10))
                        ScoreIndicator(label: LocalizationHelper.getCommonText("vocabulary", for: nativeLanguage), score: 10 - min(vocabularyScore, 10))
                        ScoreIndicator(label: LocalizationHelper.getCommonText("content", for: nativeLanguage), score: Int(feedback.score * 10))
                        ScoreIndicator(label: LocalizationHelper.getCommonText("fluency", for: nativeLanguage), score: Int((feedback.naturalness ?? 0.5) * 10))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                
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
        }
    }
}

// スコア表示用のコンポーネント
struct ScoreIndicator: View {
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
        SpeakingPracticeView()
    }
}