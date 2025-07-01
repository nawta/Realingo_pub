//
//  GeminiService.swift
//  realingo_v3
//
//  Gemini APIを使用した問題生成サービス
//  参照: VLM_Integration_Guide.md
//  関連: ContentView.swift (既存のChatGPT呼び出しを置き換え), Models.swift
//

import Foundation
import UIKit

class GeminiService {
    static let shared = GeminiService()
    
    private var apiKey: String {
        // APIKeyManagerから動的に取得（研究モード/通常モードで切り替え）
        APIKeyManager.shared.geminiAPIKey
    }
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model = "gemini-1.5-flash"
    
    private init() {
        // 初期化処理は不要（APIキーは動的に取得）
    }
    
    // MARK: - テキストから問題生成
    func generateProblemFromText(
        text: String,
        translation: String? = nil,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage = .japanese
    ) async throws -> ExtendedQuiz {
        
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        let prompt = createTextPrompt(
            text: text,
            translation: translation,
            problemType: problemType,
            language: language,
            nativeLanguage: nativeLanguage
        )
        
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [GeminiPart(text: prompt)]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 1000,
                responseMimeType: "application/json"
            )
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.serverError(response: response)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }
        
        return try parseGeminiResponse(text, language: language, problemType: problemType, imageURL: nil)
    }
    
    // MARK: - Base64画像から問題生成
    func generateProblemFromBase64Image(
        base64Image: String,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage = .japanese
    ) async throws -> ExtendedQuiz {
        
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        // Base64をデータに変換して既存のメソッドを使用
        guard let imageData = Data(base64Encoded: base64Image) else {
            throw GeminiError.invalidImageData
        }
        
        return try await generateProblemFromImageData(
            imageData: imageData,
            language: language,
            problemType: problemType,
            nativeLanguage: nativeLanguage
        )
    }
    
    // MARK: - 画像URLから問題生成
    func generateProblemFromImageURL(
        imageURL: String,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage = .japanese
    ) async throws -> ExtendedQuiz {
        
        guard !apiKey.isEmpty else {
            print("[GeminiService] API Key is empty. isResearchMode: \(APIKeyManager.shared.isResearchMode)")
            print("[GeminiService] geminiAPIKey: \(APIKeyManager.shared.geminiAPIKey)")
            throw GeminiError.noAPIKey
        }
        
        print("[GeminiService] generateProblemFromImageURL started")
        print("[GeminiService] imageURL: \(imageURL)")
        print("[GeminiService] language: \(language), problemType: \(problemType)")
        print("[GeminiService] Using API Key: \(String(apiKey.prefix(10)))...") // デバッグ用
        print("[GeminiService] Research Mode: \(APIKeyManager.shared.isResearchMode)") // 研究モード確認
        
        // 画像URLからデータをダウンロード
        guard let url = URL(string: imageURL) else {
            throw GeminiError.invalidURL
        }
        
        let (imageData, _) = try await URLSession.shared.data(from: url)
        
        // 画像をリサイズしてトークン数を削減
        guard let originalImage = UIImage(data: imageData) else {
            throw GeminiError.imageProcessingFailed
        }
        
        let resizedImage = resizeImage(originalImage, maxDimension: 1024)
        
        // JPEG形式でエンコード（品質0.8）
        guard let resizedImageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageProcessingFailed
        }
        
        let base64String = resizedImageData.base64EncodedString()
        
        let prompt = createPrompt(for: problemType, language: language, nativeLanguage: nativeLanguage, imageURL: imageURL)
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        print("[GeminiService] Endpoint URL: \(endpoint)") // デバッグ用
        
        guard let apiUrl = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: prompt),
                        GeminiPart(inlineData: GeminiInlineData(mimeType: "image/jpeg", data: base64String), fileData: nil)
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 1000,
                responseMimeType: "application/json"
            )
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            // デバッグ用にリクエストボディを出力
            print("[GeminiService] Request body size: \(jsonData.count) bytes")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // エラーの詳細をログ出力
                if let httpResponse = response as? HTTPURLResponse {
                    print("[GeminiService] API Error - Status Code: \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        print("[GeminiService] Error Response: \(errorData)")
                    }
                }
                throw GeminiError.serverError(response: response)
            }
            
            // レスポンスをデバッグ
            print("[GeminiService] Response received, size: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[GeminiService] Response (first 500 chars): \(String(responseString.prefix(500)))")
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
                print("[GeminiService] No text content in response")
                throw GeminiError.noContent
            }
            
            print("[GeminiService] Extracted text from response: \(text)")
            return try parseGeminiResponse(text, language: language, problemType: problemType, imageURL: imageURL)
        } catch {
            print("[GeminiService] Error in generateProblemFromImageURL: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[GeminiService] Key not found: \(key), context: \(context)")
                case .typeMismatch(let type, let context):
                    print("[GeminiService] Type mismatch: \(type), context: \(context)")
                case .valueNotFound(let type, let context):
                    print("[GeminiService] Value not found: \(type), context: \(context)")
                case .dataCorrupted(let context):
                    print("[GeminiService] Data corrupted: \(context)")
                @unknown default:
                    print("[GeminiService] Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    // MARK: - 画像データから問題生成
    func generateProblemFromImageData(
        imageData: Data,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage = .japanese
    ) async throws -> ExtendedQuiz {
        
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        let prompt = createPrompt(for: problemType, language: language, nativeLanguage: nativeLanguage, imageURL: nil)
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: prompt),
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: "image/jpeg",
                                data: base64Image
                            ),
                            fileData: nil
                        )
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 1000,
                responseMimeType: "application/json"
            )
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        // デバッグ用にリクエストボディを出力
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Gemini API Request: \(jsonString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // エラーの詳細をログ出力
            if let httpResponse = response as? HTTPURLResponse {
                print("Gemini API Error - Status Code: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("Error Response: \(errorData)")
                }
            }
            throw GeminiError.serverError(response: response)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }
        
        return try parseGeminiResponse(text, language: language, problemType: problemType, imageURL: nil)
    }
    
    // MARK: - 画像の説明生成
    func generateImageDescription(
        imageData: Data,
        prompt: String,
        language: SupportedLanguage
    ) async throws -> String {
        
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 画像をリサイズ
        guard let originalImage = UIImage(data: imageData) else {
            throw GeminiError.imageProcessingFailed
        }
        
        let resizedImage = resizeImage(originalImage, maxDimension: 1024)
        guard let resizedImageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageProcessingFailed
        }
        
        let base64Image = resizedImageData.base64EncodedString()
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: prompt),
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: "image/jpeg",
                                data: base64Image
                            ),
                            fileData: nil
                        )
                    ]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 500,
                responseMimeType: "application/json"
            )
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.serverError(response: response)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }
        
        return text
    }
    
    func generateImageDescriptionFromURL(
        imageURL: String,
        prompt: String,
        language: SupportedLanguage
    ) async throws -> String {
        
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        // URLから画像をダウンロード
        guard let url = URL(string: imageURL) else {
            throw GeminiError.invalidURL
        }
        
        let (imageData, _) = try await URLSession.shared.data(from: url)
        
        // ダウンロードした画像データを使って説明を生成
        return try await generateImageDescription(
            imageData: imageData,
            prompt: prompt,
            language: language
        )
    }
    
    // MARK: - 回答の評価
    func evaluateAnswer(
        userAnswer: String,
        correctAnswer: String,
        problemType: ProblemType,
        language: SupportedLanguage
    ) async throws -> VLMFeedback {
        
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        let prompt = createEvaluationPrompt(
            userAnswer: userAnswer,
            correctAnswer: correctAnswer,
            problemType: problemType,
            language: language
        )
        
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [GeminiPart(text: prompt)]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.5,
                maxOutputTokens: 500,
                responseMimeType: "application/json"
            )
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        // デバッグ用にリクエストボディを出力
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Gemini API Request: \(jsonString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // エラーの詳細をログ出力
            if let httpResponse = response as? HTTPURLResponse {
                print("Gemini API Error - Status Code: \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("Error Response: \(errorData)")
                }
            }
            throw GeminiError.serverError(response: response)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }
        
        return try JSONDecoder().decode(VLMFeedback.self, from: text.data(using: .utf8)!)
    }
    
    // MARK: - プロンプト生成
    private func createTextPrompt(
        text: String,
        translation: String?,
        problemType: ProblemType,
        language: SupportedLanguage,
        nativeLanguage: SupportedLanguage
    ) -> String {
        let languageName = language.displayName
        let translationInfo = translation != nil ? "\n翻訳: \(translation!)" : ""
        
        switch problemType {
        case .wordArrangement:
            return """
            以下のテキストから\(languageName)で語順並べ替え問題を作成してください。
            
            テキスト: \(text)\(translationInfo)
            
            要件：
            1. テキストから重要な文を1つ選択
            2. 5〜10単語程度の\(languageName)の文章
            3. 学習者向けの適切な難易度
            
            必ず以下のJSON形式で回答してください：
            {
                "question": "\(LocalizationHelper.getCommonText("wordArrangementInstruction", for: nativeLanguage))",
                "answer": "\(languageName)の正解文章（スペース区切り）",
                "options": ["\(languageName)の単語1", "\(languageName)の単語2", ...],
                "hints": ["\(nativeLanguage.displayName)のヒント1", "\(nativeLanguage.displayName)のヒント2"],
                "explanation": "\(nativeLanguage.displayName)での文法解説",
                "tags": ["タグ1", "タグ2"]
            }
            """
            
        case .fillInTheBlank:
            return """
            以下のテキストから\(languageName)で穴埋め問題を作成してください。
            
            テキスト: \(text)\(translationInfo)
            
            要件：
            1. テキストから重要な文を1つ選択
            2. 1〜3箇所の空欄
            3. 文脈から推測可能な単語
            
            必ず以下のJSON形式で回答してください：
            {
                "question": "\(LocalizationHelper.getCommonText("fillInTheBlankInstruction", for: nativeLanguage))",
                "answer": "\(languageName)の完全な文章（単語をスペースで区切る）",
                "options": ["選択肢1", "選択肢2", "選択肢3", "選択肢4"],
                "blankPositions": [単語の位置1, 単語の位置2],
                "hints": ["\(nativeLanguage.displayName)のヒント1", "\(nativeLanguage.displayName)のヒント2"],
                "explanation": "\(nativeLanguage.displayName)での解説",
                "tags": ["タグ1", "タグ2"]
            }
            """
            
        case .speaking, .writing:
            return """
            以下のテキストについて、\(languageName)で説明する問題を作成してください。
            
            テキスト: \(text)\(translationInfo)
            
            要件：
            1. テキストの内容を要約・説明する課題
            2. 3文以上の説明を求める
            3. 創造的な表現を促す
            
            以下のJSON形式で回答してください：
            {
                "question": "このテキストについて、\(languageName)で3文以上説明してください",
                "answer": "模範解答（3文以上）",
                "hints": ["説明のポイント1", "使える表現例"],
                "explanation": "評価のポイント",
                "tags": ["要約", "説明文"]
            }
            """
        }
    }
    
    private func createPrompt(for problemType: ProblemType, language: SupportedLanguage, nativeLanguage: SupportedLanguage, imageURL: String?) -> String {
        let languageName = language.displayName
        
        switch problemType {
        case .wordArrangement:
            return """
            この画像を見て、\(languageName)で語順並べ替え問題を作成してください。
            
            要件：
            1. 画像の内容に関連した\(languageName)の自然な文章
            2. 5〜10単語程度の\(languageName)の文章
            3. 学習者向けの適切な難易度
            
            必ず以下のJSON形式で回答してください。optionsフィールドは必須です：
            {
                "question": "\(LocalizationHelper.getCommonText("wordArrangementInstruction", for: nativeLanguage))",
                "answer": "\(languageName)の正解文章（スペース区切り）",
                "options": ["\(languageName)の単語1", "\(languageName)の単語2", ...],
                "hints": ["\(nativeLanguage.displayName)の\(LocalizationHelper.getCommonText("hint", for: nativeLanguage))1", "\(nativeLanguage.displayName)の\(LocalizationHelper.getCommonText("hint", for: nativeLanguage))2"],
                "explanation": "\(nativeLanguage.displayName)での\(LocalizationHelper.getCommonText("grammarExplanation", for: nativeLanguage))",
                "tags": ["タグ1", "タグ2"]
            }
            
            重要：
            - answerとoptionsは必ず\(languageName)で書いてください
            - optionsには、answerをスペースで分割した単語を順不同で含めてください
            - hintsとexplanationは\(nativeLanguage.displayName)で書いてください
            """
            
        case .fillInTheBlank:
            return """
            この画像を見て、\(languageName)で穴埋め問題を作成してください。
            
            要件：
            1. 画像の内容に関連した\(languageName)の文章
            2. 1〜3箇所の空欄
            3. 文脈から推測可能な単語
            4. 文章は必ずスペースで単語を区切ること
            
            必ず以下のJSON形式で回答してください：
            {
                "question": "\(LocalizationHelper.getCommonText("fillInTheBlankInstruction", for: nativeLanguage))",
                "answer": "\(languageName)の完全な文章（空欄なし、単語をスペースで区切る）",
                "options": ["選択肢1", "選択肢2", "選択肢3", "選択肢4"],
                "blankPositions": [単語の位置1, 単語の位置2],
                "hints": ["\(nativeLanguage.displayName)のヒント1", "\(nativeLanguage.displayName)のヒント2"],
                "explanation": "\(nativeLanguage.displayName)での解説",
                "tags": ["タグ1", "タグ2"]
            }
            
            重要：
            - answerには空欄（_____）を含めず、完全な文章を\(languageName)で書いてください
            - answerの単語は必ずスペースで区切ってください
            - blankPositionsは0から始まる単語のインデックスです（例："これ は 美しい 風景 です"なら、"美しい"は2、"風景"は3）
            - optionsには必ず以下を含めてください：
              1. blankPositionsで指定した位置の正解の単語をすべて含める
              2. 正解の単語に加えて、ダミーの選択肢も含める
              3. 合計で6〜8個の選択肢を用意する
            - 例：answer="There is a laptop on the desk", blankPositions=[0,3]の場合、optionsには必ず"There"と"on"を含める
            - hintsとexplanationは\(nativeLanguage.displayName)で書いてください
            """
            
        case .speaking, .writing:
            return """
            この画像について、\(languageName)で説明する問題を作成してください。
            
            要件：
            1. 画像の内容を説明する課題
            2. 3文以上の説明を求める
            3. 創造的な表現を促す
            
            以下のJSON形式で回答してください：
            {
                "question": "\(LocalizationHelper.getCommonText("writingInstruction", for: nativeLanguage))",
                "answer": "模範解答（3文以上、\(languageName)で）",
                "hints": ["描写のポイント1", "使える表現例"],
                "explanation": "評価のポイント",
                "tags": ["描写", "説明文"]
            }
            """
        }
    }
    
    private func createEvaluationPrompt(
        userAnswer: String,
        correctAnswer: String,
        problemType: ProblemType,
        language: SupportedLanguage
    ) -> String {
        return """
        以下の回答を評価してください。
        
        言語: \(language.displayName)
        問題タイプ: \(problemType.displayName)
        模範解答: \(correctAnswer)
        ユーザーの回答: \(userAnswer)
        
        以下のJSON形式で評価を返してください：
        {
            "score": 0.0〜1.0の総合スコア,
            "feedback": "具体的なフィードバック",
            "improvements": ["改善点1", "改善点2"],
            "strengths": ["良い点1", "良い点2"],
            "grammarScore": 0〜10,
            "vocabularyScore": 0〜10,
            "contentScore": 0〜10,
            "fluencyScore": 0〜10
        }
        """
    }
    
    private func parseGeminiResponse(
        _ jsonString: String,
        language: SupportedLanguage,
        problemType: ProblemType,
        imageURL: String?
    ) throws -> ExtendedQuiz {
        guard let data = jsonString.data(using: .utf8) else {
            throw GeminiError.parsingError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        let answer = json["answer"] as? String ?? ""
        var options = json["options"] as? [String]
        let blankPositions = json["blankPositions"] as? [Int]
        
        // 語順並べ替え問題の場合、optionsがない場合はanswerから自動生成
        if problemType == .wordArrangement && (options == nil || options?.isEmpty == true) && !answer.isEmpty {
            // answerをスペースで分割してシャッフル
            options = answer.components(separatedBy: " ").shuffled()
            print("[GeminiService] Optionsを自動生成: \(options ?? [])")
        }
        
        // 穴埋め問題の場合、正解の単語が選択肢に含まれているか確認
        if problemType == .fillInTheBlank, let positions = blankPositions, var optionsList = options {
            let words = answer.components(separatedBy: " ")
            var missingWords: [String] = []
            
            // 各空欄位置の単語が選択肢に含まれているか確認
            for position in positions {
                if position < words.count {
                    let correctWord = words[position]
                    if !optionsList.contains(correctWord) {
                        missingWords.append(correctWord)
                        print("[GeminiService] 警告: 正解の単語 '\(correctWord)' が選択肢に含まれていません")
                    }
                }
            }
            
            // 不足している正解の単語を選択肢に追加
            if !missingWords.isEmpty {
                optionsList.append(contentsOf: missingWords)
                options = optionsList
                print("[GeminiService] 正解の単語を選択肢に追加: \(missingWords)")
            }
        }
        
        // デバッグ情報を出力
        print("[GeminiService] parseGeminiResponse完了:")
        print("  - problemType: \(problemType)")
        print("  - question: \(json["question"] as? String ?? "なし")")
        print("  - answer: \(answer)")
        print("  - options: \(options ?? [])")
        print("  - blankPositions: \(blankPositions ?? [])")
        print("  - hints: \(json["hints"] as? [String] ?? [])")
        
        return ExtendedQuiz(
            problemID: UUID().uuidString,
            language: language,
            problemType: problemType,
            imageMode: .immediate,
            question: json["question"] as? String ?? "",
            answer: answer,
            imageUrl: imageURL,
            audioUrl: nil,
            options: options,
            blankPositions: blankPositions,
            hints: json["hints"] as? [String],
            difficulty: 3,
            tags: json["tags"] as? [String],
            explanation: ["ja": json["explanation"] as? String ?? ""],
            createdByGroup: "A",
            createdByParticipant: "",
            createdAt: Date(),
            vlmGenerated: true,
            vlmModel: "gemini-1.5-flash"
        )
    }
    
    // MARK: - 画像リサイズ
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // アスペクト比を保持しながら、長辺が maxDimension になるようにスケールを計算
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }
        
        // 既に十分小さい場合はそのまま返す
        if scale >= 1.0 {
            return image
        }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        // UIGraphicsImageRenderer を使用して高品質なリサイズを実行
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            // アンチエイリアシングを有効にして描画
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    // MARK: - テキストベースのプロンプト生成
    private func createTextBasedPrompt(
        text: String,
        translation: String,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage
    ) -> String {
        let basePrompt = """
        Create a \(language.displayName) language learning problem based on this text.
        
        Original text (\(language.displayName)): \(text)
        Translation (\(nativeLanguage.displayName)): \(translation)
        
        """
        
        let specificInstructions = createPrompt(for: problemType, language: language, nativeLanguage: nativeLanguage, imageURL: nil)
        
        return basePrompt + specificInstructions
    }
    
    // MARK: - 翻訳機能
    func translateText(
        text: String,
        fromLanguage: SupportedLanguage,
        toLanguage: SupportedLanguage
    ) async throws -> String {
        let prompt = """
        Translate the following text from \(fromLanguage.displayName) to \(toLanguage.displayName).
        Return ONLY the translation, without any explanations or additional text.
        
        Text to translate: \(text)
        """
        
        // Gemini APIリクエストを送信
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        print("[GeminiService] Using API Key: \(String(apiKey.prefix(10)))...") // デバッグ用
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [GeminiPart(text: prompt)]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.3,
                maxOutputTokens: 500
            )
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.serverError(response: response)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let responseText = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }
        
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - テキストのみ生成（LLM質問機能用）
    func generateTextOnlyResponse(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        let endpoint = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [GeminiPart(text: prompt)]
                )
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 1000
            )
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.serverError(response: response)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let responseText = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }
        
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Request/Response Models
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?
    let fileData: GeminiFileData?
    
    init(text: String) {
        self.text = text
        self.inlineData = nil
        self.fileData = nil
    }
    
    init(inlineData: GeminiInlineData?, fileData: GeminiFileData?) {
        self.text = nil
        self.inlineData = inlineData
        self.fileData = fileData
    }
}

struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String
}

struct GeminiFileData: Codable {
    let mimeType: String
    let fileUri: String
}

struct GeminiGenerationConfig: Codable {
    let temperature: Double
    let maxOutputTokens: Int
    let responseMimeType: String?
    
    init(temperature: Double, maxOutputTokens: Int, responseMimeType: String? = nil) {
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.responseMimeType = responseMimeType
    }
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

// MARK: - Errors
enum GeminiError: LocalizedError {
    case invalidURL
    case noAPIKey
    case serverError(response: URLResponse?)
    case noContent
    case parsingError
    case imageProcessingFailed
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .noAPIKey:
            return "Gemini APIキーが設定されていません"
        case .serverError(let response):
            if let httpResponse = response as? HTTPURLResponse {
                return "サーバーエラー: \(httpResponse.statusCode)"
            }
            return "サーバーエラー"
        case .noContent:
            return "コンテンツが取得できませんでした"
        case .parsingError:
            return "レスポンスの解析に失敗しました"
        case .imageProcessingFailed:
            return "画像の処理に失敗しました"
        case .invalidImageData:
            return "無効な画像データです"
        }
    }
}