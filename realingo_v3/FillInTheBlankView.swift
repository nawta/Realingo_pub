//
//  FillInTheBlankView.swift
//  realingo_v3
//
//  穴埋め問題の練習画面
//  参照: specification.md - 穴埋め問題
//  関連: Models.swift (ExtendedQuiz), GeminiService.swift (問題生成)
//

import SwiftUI

struct FillInTheBlankView: View {
    @State private var currentQuiz: ExtendedQuiz?
    @State private var userAnswers: [String] = []
    @State private var showResult = false
    @State private var isProcessing = false
    @State private var sessionStartTime = Date()
    @State private var selectedBlankIndex: Int?
    @State private var showingOptions = false
    @State private var isCorrect = false
    
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
    
    @StateObject private var dataPersistence = DataPersistenceManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let quiz = currentQuiz {
                    // 画像表示
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
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                    
                    // 問題文（指示文のみ、固定）
                    Text(LocalizationHelper.getCommonText("fillInTheBlankInstruction", for: nativeLanguage))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 15)
                    
                    // 穴埋め文章
                    VStack {
                        FillInSentenceView(
                            quiz: quiz,
                            userAnswers: $userAnswers,
                            selectedBlankIndex: $selectedBlankIndex,
                            showResult: showResult
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // 選択肢
                    if let options = quiz.options, !showResult {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizationHelper.getCommonText("availableWords", for: nativeLanguage))
                                .font(.headline)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                                    OptionButton(
                                        text: option,
                                        isUsed: userAnswers.contains(option),
                                        action: {
                                            if let blankIndex = selectedBlankIndex {
                                                fillBlank(at: blankIndex, with: option)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // ヒント
                    if let hints = quiz.hints, !hints.isEmpty, !showResult {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(LocalizationHelper.getCommonText("hint", for: nativeLanguage))
                                .font(.caption)
                                .fontWeight(.semibold)
                            ForEach(Array(hints.enumerated()), id: \.offset) { index, hint in
                                if let positions = quiz.blankPositions, index < positions.count {
                                    Text("\(LocalizationHelper.getCommonText("blank", for: nativeLanguage))\(index + 1): \(hint)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // 提出ボタンとアップロードボタン
                    if !showResult {
                        HStack(spacing: 15) {
                            Button(action: checkAnswer) {
                                Text(LocalizationHelper.getCommonText("check", for: nativeLanguage))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isAllFilled() ? Color.blue : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(!isAllFilled())
                            
                            // 写真アップロードボタン
                            PhotoUploadButton(quiz: quiz)
                        }
                        .padding(.horizontal)
                    }
                    
                    // 結果表示
                    if showResult {
                        ResultView(
                            quiz: quiz,
                            userAnswers: userAnswers,
                            nativeLanguage: nativeLanguage,
                            isCorrect: isCorrect,
                            onNext: loadNextProblem
                        )
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
            .padding(.vertical)
        }
        .navigationTitle("\(selectedLanguage.displayName) \(LocalizationHelper.getProblemTypeText(.fillInTheBlank, for: nativeLanguage))")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sessionStartTime = Date()
            // 初期化時にquizが渡されていて、空欄がある場合は初期設定
            if let quiz = currentQuiz {
                print("[FillInTheBlankView] Quiz loaded: \(quiz.problemID)")
                print("[FillInTheBlankView] Quiz blankPositions: \(quiz.blankPositions ?? [])")
                print("[FillInTheBlankView] Quiz answer: \(quiz.answer)")
                print("[FillInTheBlankView] Quiz options: \(quiz.options ?? [])")
                
                if let positions = quiz.blankPositions, !positions.isEmpty {
                    userAnswers = Array(repeating: "", count: positions.count)
                    selectedBlankIndex = nil // 最初は何も選択しない
                    print("[FillInTheBlankView] Initialized userAnswers with \(positions.count) blanks")
                } else {
                    print("[FillInTheBlankView] Warning: No blankPositions found!")
                    // 空欄がない場合の処理
                    userAnswers = []
                    selectedBlankIndex = nil
                }
            }
        }
    }
    
    private func fillBlank(at index: Int, with word: String) {
        guard index < userAnswers.count else { return }
        
        // 既に入っている単語を選択肢に戻す
        if !userAnswers[index].isEmpty {
            userAnswers[index] = ""
        }
        
        // 新しい単語を入れる
        userAnswers[index] = word
        
        // 次の空欄を自動選択
        if let positions = currentQuiz?.blankPositions {
            for (i, _) in positions.enumerated() {
                if i > index && userAnswers[i].isEmpty {
                    selectedBlankIndex = i
                    return
                }
            }
            // 全て埋まったら選択解除
            selectedBlankIndex = nil
        }
    }
    
    private func isAllFilled() -> Bool {
        return !userAnswers.contains("")
    }
    
    private func checkAnswer() {
        guard let quiz = currentQuiz else { return }
        
        showResult = true
        
        // 正解判定
        let correctWords = extractCorrectWords(from: quiz.answer, at: quiz.blankPositions ?? [])
        isCorrect = userAnswers == correctWords
        
        // デバッグログ
        print("[checkAnswer] 正解判定デバッグ:")
        print("  - quiz.answer: \(quiz.answer)")
        print("  - blankPositions: \(quiz.blankPositions ?? [])")
        print("  - correctWords: \(correctWords)")
        print("  - userAnswers: \(userAnswers)")
        print("  - isCorrect: \(isCorrect)")
        print("  - 構築された回答文: \(constructUserAnswer())")
        
        // 回答ログを保存
        Task {
            let log = ExtendedProblemLog(
                logID: UUID().uuidString,
                problemID: quiz.problemID,
                participantID: participantID,
                groupID: groupID,
                language: selectedLanguage,
                problemType: .fillInTheBlank,
                imageUrl: quiz.imageUrl,
                question: quiz.question,
                correctAnswer: quiz.answer,
                userAnswer: constructUserAnswer(),
                isCorrect: isCorrect,
                score: isCorrect ? 1.0 : calculatePartialScore(correctWords: correctWords),
                timeSpentSeconds: Int(Date().timeIntervalSince(sessionStartTime)),
                audioRecordingUrl: nil,
                vlmFeedback: nil,
                errorAnalysis: analyzeErrors(correctWords: correctWords),
                startedAt: sessionStartTime,
                completedAt: Date(),
                sessionID: UUID().uuidString,
                previousAttempts: 0
            )
            
            try? await dataPersistence.saveProblemLog(log)
        }
    }
    
    private func constructUserAnswer() -> String {
        guard let quiz = currentQuiz,
              let positions = quiz.blankPositions else {
            return userAnswers.joined(separator: ", ")
        }
        
        // 単語配列を作成
        var words = quiz.answer.components(separatedBy: " ")
        
        // 空欄位置に回答を挿入
        for (blankIndex, wordPosition) in positions.enumerated() {
            if wordPosition < words.count && blankIndex < userAnswers.count {
                words[wordPosition] = userAnswers[blankIndex]
            }
        }
        
        return words.joined(separator: " ")
    }
    
    private func extractCorrectWords(from answer: String, at positions: [Int]) -> [String] {
        // answer文字列から正しい位置の単語を抽出
        let words = answer.components(separatedBy: " ")
        return positions.compactMap { pos in
            pos < words.count ? words[pos] : nil
        }
    }
    
    private func calculatePartialScore(correctWords: [String]) -> Double {
        let correctCount = zip(userAnswers, correctWords).filter { $0 == $1 }.count
        return Double(correctCount) / Double(correctWords.count)
    }
    
    private func analyzeErrors(correctWords: [String]) -> [String] {
        var errors: [String] = []
        for (index, (user, correct)) in zip(userAnswers, correctWords).enumerated() {
            if user != correct {
                errors.append("\(LocalizationHelper.getCommonText("blank", for: nativeLanguage))\(index + 1): '\(user)' → '\(correct)'")
            }
        }
        return errors
    }
    
    private func loadNextProblem() {
        isProcessing = true
        
        Task {
            do {
                // ProblemGenerationServiceで穴埋め問題を生成（API/VLM自動選択）
                let newQuiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: "https://picsum.photos/400/300", // 今はランダム画像を使用
                    language: selectedLanguage,
                    problemType: .fillInTheBlank,
                    nativeLanguage: nativeLanguage
                )
                
                await MainActor.run {
                    self.currentQuiz = newQuiz
                    
                    // 空欄の数だけ空文字列を用意
                    if let positions = newQuiz.blankPositions {
                        self.userAnswers = Array(repeating: "", count: positions.count)
                        self.selectedBlankIndex = 0
                    }
                    
                    self.showResult = false
                    self.isProcessing = false
                    self.isCorrect = false
                }
            } catch {
                await MainActor.run {
                    print("Error generating fill-in-the-blank problem: \(error)")
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
            problemType: .fillInTheBlank,
            imageMode: .immediate,
            question: LocalizationHelper.getCommonText("fillInTheBlankInstruction", for: nativeLanguage),
            answer: "Tämä on kaunis maisema", // フィンランド語のサンプル
            imageUrl: "https://picsum.photos/400/300",
            audioUrl: nil,
            options: ["kaunis", "maisema", "iso", "rakennus", "sininen", "taivas"],
            blankPositions: [2, 3],  // "kaunis"と"maisema"の位置
            hints: ["adjective", "noun"],
            difficulty: 3,
            tags: ["adjective", "noun"],
            explanation: nil,
            createdByGroup: groupID,
            createdByParticipant: participantID,
            createdAt: Date(),
            vlmGenerated: false,
            vlmModel: nil
        )
        
        // 空欄の数だけ空文字列を用意
        if let positions = currentQuiz?.blankPositions {
            userAnswers = Array(repeating: "", count: positions.count)
            selectedBlankIndex = 0
        }
        
        showResult = false
        isCorrect = false
    }
}

// MARK: - Sub Views

struct FillInSentenceView: View {
    let quiz: ExtendedQuiz
    @Binding var userAnswers: [String]
    @Binding var selectedBlankIndex: Int?
    let showResult: Bool
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        // 文章を単語単位で分割し、空欄位置を考慮して表示
        let words = quiz.answer.components(separatedBy: " ")
        let positions = quiz.blankPositions ?? []
        
        // デバッグログ
        let _ = print("[FillInSentenceView] words: \(words)")
        let _ = print("[FillInSentenceView] positions: \(positions)")
        let _ = print("[FillInSentenceView] userAnswers: \(userAnswers)")
        
        // シンプルなラップレイアウト
        VStack(alignment: .leading, spacing: 8) {
            createWrappedContent(words: words, positions: positions)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func createWrappedContent(words: [String], positions: [Int]) -> some View {
        // 単語を行ごとにグループ化（簡易版）
        let wordsPerLine = 5 // 1行あたりの単語数の目安
        let lines = stride(from: 0, to: words.count, by: wordsPerLine).map { lineStart in
            Array(words[lineStart..<min(lineStart + wordsPerLine, words.count)])
        }
        
        ForEach(0..<lines.count, id: \.self) { lineIndex in
            HStack(spacing: 8) {
                ForEach(0..<lines[lineIndex].count, id: \.self) { wordIndex in
                    let globalIndex = lineIndex * wordsPerLine + wordIndex
                    let word = lines[lineIndex][wordIndex]
                    
                    if let blankIndex = positions.firstIndex(of: globalIndex) {
                        // この位置は空欄
                        BlankField(
                            text: blankIndex < userAnswers.count ? userAnswers[blankIndex] : "",
                            isSelected: selectedBlankIndex == blankIndex,
                            isCorrect: showResult ? checkIfCorrect(blankIndex: blankIndex, correctWord: word) : nil,
                            onTap: {
                                if !showResult {
                                    selectedBlankIndex = blankIndex
                                }
                            }
                        )
                    } else {
                        // 通常の単語
                        Text(word)
                            .padding(.vertical, 4)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            }
        }
    }
    
    private func checkIfCorrect(blankIndex: Int, correctWord: String) -> Bool {
        // 実際の正解チェック
        guard blankIndex < userAnswers.count else { return false }
        return userAnswers[blankIndex] == correctWord
    }
}


struct BlankField: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool?
    let onTap: () -> Void
    
    var body: some View {
        Text(text.isEmpty ? "____" : text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor, lineWidth: 2)
                    )
            )
            .onTapGesture(perform: onTap)
    }
    
    private var backgroundColor: Color {
        if let isCorrect = isCorrect {
            return isCorrect ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
        } else if isSelected {
            return Color.blue.opacity(0.1)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if let isCorrect = isCorrect {
            return isCorrect ? Color.green : Color.red
        } else if isSelected {
            return Color.blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

struct OptionButton: View {
    let text: String
    let isUsed: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isUsed ? Color.gray.opacity(0.3) : Color.blue.opacity(0.1))
                .foregroundColor(isUsed ? .gray : .primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isUsed ? Color.gray.opacity(0.3) : Color.blue, lineWidth: 1)
                )
        }
        .disabled(isUsed)
    }
}

struct ResultView: View {
    let quiz: ExtendedQuiz
    let userAnswers: [String]
    let nativeLanguage: SupportedLanguage
    let isCorrect: Bool
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            // 結果表示
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCorrect ? .green : .red)
                Text(LocalizationHelper.getCommonText(isCorrect ? "correct" : "incorrect", for: nativeLanguage))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.bottom, 10)
            
            // ユーザーの回答
            if !isCorrect {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizationHelper.getCommonText("yourAnswer", for: nativeLanguage) + ":")
                        .font(.headline)
                    Text(constructUserAnswer(quiz: quiz, userAnswers: userAnswers))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // 正解表示
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizationHelper.getCommonText(isCorrect ? "answer" : "correctAnswer", for: nativeLanguage) + ":")
                    .font(.headline)
                Text(quiz.answer)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // 説明（あれば）
            if let explanation = quiz.explanation?[nativeLanguage.rawValue] ?? quiz.explanation?.values.first {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizationHelper.getCommonText("explanation", for: nativeLanguage) + ":")
                        .font(.headline)
                    Text(explanation)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // 次の問題へ
            Button(LocalizationHelper.getCommonText("next", for: nativeLanguage)) {
                onNext()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func constructUserAnswer(quiz: ExtendedQuiz, userAnswers: [String]) -> String {
        guard let positions = quiz.blankPositions else {
            return userAnswers.joined(separator: ", ")
        }
        
        // 単語配列を作成
        var words = quiz.answer.components(separatedBy: " ")
        
        // 空欄位置に回答を挿入
        for (blankIndex, wordPosition) in positions.enumerated() {
            if wordPosition < words.count && blankIndex < userAnswers.count {
                words[wordPosition] = userAnswers[blankIndex].isEmpty ? "____" : userAnswers[blankIndex]
            }
        }
        
        return words.joined(separator: " ")
    }
}

#Preview {
    NavigationStack {
        FillInTheBlankView()
    }
}