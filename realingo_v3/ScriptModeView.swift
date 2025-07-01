//
//  ScriptModeView.swift
//  realingo_v3
//
//  スクリプトモードのUI
//  文字起こしされたテキストや議事録から学習
//

import SwiftUI

struct ScriptModeView: View {
    let scriptText: String
    let sourceType: SourceType
    
    enum SourceType {
        case audio
        case text
        case import_
    }
    
    @State private var selectedMode: LearningMode = .translation
    @State private var showingQuiz = false
    @State private var selectedSentence: String?
    @State private var generatedQuiz: ExtendedQuiz?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var sentences: [TranslatedSentence] = []
    @State private var isTranslating = false
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    enum LearningMode: String, CaseIterable {
        case translation = "translation"
        case quiz = "quiz"
        
        var displayName: String {
            switch self {
            case .translation:
                return "翻訳文章提示"
            case .quiz:
                return "問題演習"
            }
        }
        
        var icon: String {
            switch self {
            case .translation:
                return "doc.text"
            case .quiz:
                return "questionmark.circle"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // モード選択
                Picker("学習モード", selection: $selectedMode) {
                    ForEach(LearningMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // コンテンツ表示
                Group {
                    switch selectedMode {
                    case .translation:
                        translationView
                    case .quiz:
                        quizSelectionView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("スクリプトモード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // スクリプトをインポート
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .onAppear {
                if sentences.isEmpty {
                    translateScript()
                }
            }
            .sheet(item: $generatedQuiz) { quiz in
                // 生成された問題に応じた画面に遷移
                Group {
                    switch quiz.problemType {
                    case .wordArrangement:
                        ContentView(quiz: quiz)
                    case .fillInTheBlank:
                        FillInTheBlankView(quiz: quiz)
                    case .speaking:
                        SpeakingPracticeView(quiz: quiz)
                    case .writing:
                        WritingPracticeView(quiz: quiz)
                    }
                }
            }
        }
    }
    
    // MARK: - Translation View
    
    private var translationView: some View {
        VStack {
            if isTranslating {
                ProgressView("翻訳中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sentences.isEmpty {
                Text("翻訳する文章がありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(sentences) { sentence in
                            TranslationRow(
                                sentence: sentence,
                                selectedLanguage: selectedLanguage,
                                nativeLanguage: nativeLanguage
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Quiz Selection View
    
    private var quizSelectionView: some View {
        VStack(spacing: 20) {
            if sentences.isEmpty {
                Text("まず翻訳モードで文章を確認してください")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Text("問題タイプを選択")
                        .font(.headline)
                    
                    ForEach(ProblemType.allCases, id: \.self) { problemType in
                        Button(action: {
                            generateQuizFromScript(problemType: problemType)
                        }) {
                            HStack {
                                Image(systemName: getIcon(for: problemType))
                                    .font(.title2)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizationHelper.getProblemTypeText(problemType, for: nativeLanguage))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(LocalizationHelper.getProblemTypeDescription(problemType, for: nativeLanguage))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isGenerating)
                    }
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func translateScript() {
        isTranslating = true
        
        Task {
            do {
                // スクリプトを文章に分割
                let rawSentences = scriptText
                    .components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // 各文章を翻訳
                var translatedSentences: [TranslatedSentence] = []
                
                for (index, sentence) in rawSentences.enumerated() {
                    // Gemini APIで翻訳
                    let translation = try await translateSentence(sentence)
                    
                    translatedSentences.append(TranslatedSentence(
                        id: UUID().uuidString,
                        original: sentence,
                        translation: translation,
                        index: index
                    ))
                }
                
                await MainActor.run {
                    self.sentences = translatedSentences
                    self.isTranslating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "翻訳エラー: \(error.localizedDescription)"
                    self.isTranslating = false
                }
            }
        }
    }
    
    private func translateSentence(_ sentence: String) async throws -> String {
        // 入力言語を自動検出して、選択された言語に翻訳
        return try await ProblemGenerationService.shared.translateText(
            text: sentence,
            fromLanguage: nativeLanguage,  // 入力言語（日本語など）
            toLanguage: selectedLanguage   // 学習対象言語（フィンランド語など）
        )
    }
    
    private func generateQuizFromScript(problemType: ProblemType) {
        guard !sentences.isEmpty else { return }
        
        isGenerating = true
        
        // ランダムに文章を選択
        let randomSentence = sentences.randomElement()!
        
        Task {
            do {
                // Gemini APIで問題生成
                let quiz = try await ProblemGenerationService.shared.generateProblemFromText(
                    text: randomSentence.original,
                    translation: randomSentence.translation,
                    language: selectedLanguage,
                    problemType: problemType,
                    nativeLanguage: nativeLanguage
                )
                
                await MainActor.run {
                    self.isGenerating = false
                    self.generatedQuiz = quiz
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.errorMessage = "問題生成エラー: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getIcon(for problemType: ProblemType) -> String {
        switch problemType {
        case .wordArrangement:
            return "arrow.left.arrow.right"
        case .fillInTheBlank:
            return "square.and.pencil"
        case .speaking:
            return "mic.fill"
        case .writing:
            return "pencil.and.scribble"
        }
    }
}

// MARK: - Supporting Types

struct TranslatedSentence: Identifiable {
    let id: String
    let original: String
    let translation: String
    let index: Int
}

struct TranslationRow: View {
    let sentence: TranslatedSentence
    let selectedLanguage: SupportedLanguage
    let nativeLanguage: SupportedLanguage
    
    @State private var showTranslation = false
    @State private var showingLLMQuery = false
    @State private var llmQuestion = ""
    @State private var llmAnswer = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 原文
            Text(sentence.original)
                .font(.body)
                .foregroundColor(.primary)
                .onTapGesture {
                    withAnimation(.spring()) {
                        showTranslation.toggle()
                        if showTranslation {
                            SoundEffectManager.shared.playHapticFeedback(style: .light)
                        }
                    }
                }
            
            // 翻訳（タップで表示）
            if showTranslation {
                VStack(alignment: .leading, spacing: 8) {
                    Text(sentence.translation)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .transition(.opacity)
                    
                    Button(action: {
                        showingLLMQuery = true
                    }) {
                        Label("質問する", systemImage: "questionmark.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .sheet(isPresented: $showingLLMQuery) {
            LLMQueryView(
                sentence: sentence.original,
                translation: sentence.translation,
                language: selectedLanguage,
                nativeLanguage: nativeLanguage
            )
        }
    }
}

// MARK: - LLM Query View

struct LLMQueryView: View {
    let sentence: String
    let translation: String
    let language: SupportedLanguage
    let nativeLanguage: SupportedLanguage
    
    @State private var question = ""
    @State private var answer = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // 文章表示
                VStack(alignment: .leading, spacing: 8) {
                    Text("原文:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(sentence)
                        .font(.body)
                    
                    Text("翻訳:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(translation)
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // 質問入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("質問:")
                        .font(.headline)
                    
                    TextEditor(text: $question)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // 送信ボタン
                Button(action: submitQuestion) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("質問を送信")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(question.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(question.isEmpty || isLoading)
                
                // 回答表示
                if !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("回答:")
                            .font(.headline)
                        
                        ScrollView {
                            Text(answer)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("文法・表現について質問")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitQuestion() {
        isLoading = true
        
        Task {
            do {
                // Gemini APIに質問を送信
                let prompt = """
                以下の文章と翻訳について質問があります。日本語で回答してください。

                原文(\(language.displayName)): \(sentence)
                翻訳(日本語): \(translation)

                質問: \(question)

                この文章の文法構造、語彙の意味、表現のニュアンスなどについて詳しく説明してください。
                """
                
                answer = try await GeminiService.shared.generateTextOnlyResponse(prompt: prompt)
                
                await MainActor.run {
                    isLoading = false
                    SoundEffectManager.shared.playCorrectSound()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    answer = "エラーが発生しました: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    ScriptModeView(
        scriptText: "This is a sample text. It contains multiple sentences. Each sentence can be translated.",
        sourceType: .text
    )
}