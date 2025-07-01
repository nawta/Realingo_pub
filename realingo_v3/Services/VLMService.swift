import Foundation
import SwiftUI
import UIKit

// VLMService: Vision Language Model service using local llama.cpp
class VLMService: ObservableObject {
    static let shared = VLMService()
    
    @Published var isModelLoaded = false
    @Published var isProcessing = false
    @Published var modelPath: String?
    @Published var clipModelPath: String?
    
    private var llamaContext: LlamaContext?
    private let modelFileName = "llava-v1.6-mistral-7b.Q4_K_M.gguf" // VLM model
    private let clipModelFileName = "mmproj-model-f16.gguf" // CLIP projection model
    
    private init() {
        setupVLM()
    }
    
    private func setupVLM() {
        checkForModel()
    }
    
    private func checkForModel() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = documentsPath.appendingPathComponent(modelFileName)
        let clipURL = documentsPath.appendingPathComponent(clipModelFileName)
        
        if FileManager.default.fileExists(atPath: modelURL.path) {
            modelPath = modelURL.path
            
            // Check for CLIP model
            if FileManager.default.fileExists(atPath: clipURL.path) {
                clipModelPath = clipURL.path
            }
            
            Task {
                await loadModel()
            }
        }
    }
    
    @MainActor
    func loadModel() async {
        guard let modelPath = modelPath else { return }
        
        do {
            // Load with CLIP model if available, otherwise just the base model
            llamaContext = try await LlamaContext.create_context(path: modelPath, clipPath: clipModelPath)
            isModelLoaded = true
            print("VLM model loaded successfully")
            if clipModelPath != nil {
                print("CLIP model loaded successfully")
            } else {
                print("Warning: No CLIP model found, VLM functionality will be limited")
            }
        } catch {
            print("Failed to load VLM model: \(error)")
            isModelLoaded = false
        }
    }
    
    // MARK: - Public Methods
    
    // Generate problem from image URL
    func generateProblemFromImageURL(
        imageURL: String,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage
    ) async throws -> ExtendedQuiz {
        // Download image from URL
        guard let url = URL(string: imageURL) else {
            throw NSError(domain: "VLMService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid image URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "VLMService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }
        
        return try await generateProblemFromImage(image, language: language, problemType: problemType, nativeLanguage: nativeLanguage)
    }
    
    // Generate problem from image data
    func generateProblemFromImageData(
        imageData: Data,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage
    ) async throws -> ExtendedQuiz {
        guard let image = UIImage(data: imageData) else {
            throw NSError(domain: "VLMService", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }
        
        return try await generateProblemFromImage(image, language: language, problemType: problemType, nativeLanguage: nativeLanguage)
    }
    
    // Generate image description
    func generateImageDescription(
        imageData: Data,
        prompt: String,
        language: SupportedLanguage
    ) async throws -> String {
        guard isModelLoaded else {
            throw NSError(domain: "VLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "VLM model not loaded"])
        }
        
        guard let llamaContext = llamaContext else {
            throw NSError(domain: "VLMService", code: 3, userInfo: [NSLocalizedDescriptionKey: "LlamaContext not initialized"])
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Create description prompt
        let descriptionPrompt = """
        <image>
        \(prompt)
        
        Please provide your response in \(language.displayName).
        """
        
        // Generate with VLM
        guard clipModelPath != nil else {
            throw NSError(domain: "VLMService", code: 11, userInfo: [NSLocalizedDescriptionKey: "CLIP model not loaded"])
        }
        
        let response = try await llamaContext.generate_with_image(prompt: descriptionPrompt, imageData: imageData)
        return response
    }
    
    // Evaluate user answer
    func evaluateAnswer(
        userAnswer: String,
        correctAnswer: String,
        problemType: ProblemType,
        language: SupportedLanguage
    ) async throws -> VLMFeedback {
        guard isModelLoaded else {
            throw NSError(domain: "VLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "VLM model not loaded"])
        }
        
        guard let llamaContext = llamaContext else {
            throw NSError(domain: "VLMService", code: 3, userInfo: [NSLocalizedDescriptionKey: "LlamaContext not initialized"])
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Create evaluation prompt
        let evaluationPrompt = createEvaluationPrompt(
            userAnswer: userAnswer,
            correctAnswer: correctAnswer,
            problemType: problemType,
            language: language
        )
        
        // Generate evaluation without image
        let response = try await llamaContext.generate_with_image(prompt: evaluationPrompt, imageData: Data())
        
        // Parse response to VLMFeedback
        return try parseVLMFeedback(response)
    }
    
    // Generate problem from image using local VLM (internal method)
    private func generateProblemFromImage(
        _ image: UIImage,
        language: SupportedLanguage,
        problemType: ProblemType,
        nativeLanguage: SupportedLanguage
    ) async throws -> ExtendedQuiz {
        guard isModelLoaded else {
            throw NSError(domain: "VLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "VLM model not loaded"])
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "VLMService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        let base64Image = imageData.base64EncodedString()
        
        // Create prompt for VLM
        let prompt = createVLMPrompt(language: language, problemType: problemType, nativeLanguage: nativeLanguage, withImage: true)
        
        // Process with VLM
        guard let llamaContext = llamaContext else {
            throw NSError(domain: "VLMService", code: 3, userInfo: [NSLocalizedDescriptionKey: "LlamaContext not initialized"])
        }
        
        // Generate response using VLM
        guard clipModelPath != nil else {
            throw NSError(domain: "VLMService", code: 11, userInfo: [NSLocalizedDescriptionKey: "CLIP model not loaded for image processing"])
        }
        
        let response = try await llamaContext.generate_with_image(prompt: prompt, imageData: imageData)
        
        // Parse response to ExtendedQuiz
        return try parseVLMResponse(response, language: language, problemType: problemType, nativeLanguage: nativeLanguage)
    }
    
    private func createVLMPrompt(language: SupportedLanguage, problemType: ProblemType, nativeLanguage: SupportedLanguage, withImage: Bool) -> String {
        let languageInstruction = getLanguageInstruction(for: language)
        
        if withImage {
            return """
            <image>
            Please analyze this image and create a language learning exercise.
            
            \(languageInstruction)
            
            Create a language learning exercise based on this image.
            
            Problem type: \(problemType.displayName)
            Target language: \(language.displayName)
            Native language: \(nativeLanguage.displayName)
            
            Create a sentence that describes what's in the image, and provide:
            1. The sentence in \(language.displayName)
            2. Translation in \(nativeLanguage.displayName)
            3. Individual words from the sentence
            4. Translations for each word in \(nativeLanguage.displayName)
            
            Format the response as JSON:
            {
              "sentence": "sentence in target language",
              "translation": "Translation in native language",
              "words": ["word1", "word2", ...],
              "translations": ["translation1", "translation2", ...]
            }
            """
        } else {
            return """
            Create a simple language learning exercise.
            
            \(languageInstruction)
            
            Problem type: \(problemType.displayName)
            Target language: \(language.displayName)
            Native language: \(nativeLanguage.displayName)
            
            Provide:
            1. A simple sentence in \(language.displayName)
            2. Translation in \(nativeLanguage.displayName)
            3. Individual words from the sentence
            4. Translations for each word in \(nativeLanguage.displayName)
            
            Format the response as JSON:
            {
              "sentence": "sentence in target language",
              "translation": "Translation in native language",
              "words": ["word1", "word2", ...],
              "translations": ["translation1", "translation2", ...]
            }
            """
        }
    }
    
    private func getLanguageInstruction(for language: SupportedLanguage) -> String {
        switch language {
        case .finnish:
            return "Target language: Finnish. Use simple, everyday Finnish suitable for beginners."
        case .japanese:
            return "Target language: Japanese. Use hiragana for beginners, with kanji in parentheses when appropriate."
        case .spanish:
            return "Target language: Spanish. Use simple, everyday Spanish suitable for beginners."
        case .french:
            return "Target language: French. Use simple, everyday French suitable for beginners."
        case .german:
            return "Target language: German. Use simple, everyday German suitable for beginners."
        case .italian:
            return "Target language: Italian. Use simple, everyday Italian suitable for beginners."
        case .russian:
            return "Target language: Russian. Use simple, everyday Russian suitable for beginners."
        case .korean:
            return "Target language: Korean. Use simple, everyday Korean suitable for beginners."
        case .chinese:
            return "Target language: Chinese. Use simplified characters with pinyin."
        default:
            return "Target language: \(language.displayName). Use simple, everyday language suitable for beginners."
        }
    }
    
    private func parseVLMResponse(_ response: String, language: SupportedLanguage, problemType: ProblemType, nativeLanguage: SupportedLanguage) throws -> ExtendedQuiz {
        // Extract JSON from response
        guard let jsonStart = response.range(of: "{"),
              let jsonEnd = response.range(of: "}", options: .backwards),
              jsonStart.lowerBound <= jsonEnd.lowerBound else {
            throw NSError(domain: "VLMService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid VLM response format"])
        }
        
        let jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "VLMService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to data"])
        }
        
        let decoder = JSONDecoder()
        let vlmResponse = try decoder.decode(VLMResponse.self, from: jsonData)
        
        // Create ExtendedQuiz from VLM response
        let participantID = UserDefaults.standard.string(forKey: "participantID") ?? "anonymous"
        let groupID = UserDefaults.standard.string(forKey: "groupID") ?? "A"
        
        return ExtendedQuiz(
            problemID: UUID().uuidString,
            language: language,
            problemType: problemType,
            imageMode: .cameraCapture,
            question: "Arrange the words to form the correct sentence",
            answer: vlmResponse.sentence,
            imageUrl: nil,
            audioUrl: nil,
            options: vlmResponse.words.shuffled(),
            blankPositions: nil,
            hints: nil,
            difficulty: 3,
            tags: ["vlm-generated"],
            explanation: [nativeLanguage.rawValue: vlmResponse.translation],
            metadata: [
                "words": vlmResponse.words.joined(separator: ","),
                "translations": vlmResponse.translations.joined(separator: ",")
            ],
            createdByGroup: groupID,
            createdByParticipant: participantID,
            createdAt: Date(),
            vlmGenerated: true,
            vlmModel: modelFileName,
            notified: nil,
            communityPhotoID: nil
        )
    }
    
    // Check if VLM is available
    var isVLMAvailable: Bool {
        // VLM requires both the base model and CLIP model
        return modelPath != nil && 
               clipModelPath != nil && 
               FileManager.default.fileExists(atPath: modelPath ?? "") &&
               FileManager.default.fileExists(atPath: clipModelPath ?? "")
    }
    
    // Get model download URL
    func getModelDownloadURL() -> URL? {
        // Popular VLM models for llama.cpp
        // LLaVA v1.6 Mistral 7B is a good balance of quality and size
        return URL(string: "https://huggingface.co/cjpais/llava-v1.6-mistral-7b-gguf/resolve/main/llava-v1.6-mistral-7b.Q4_K_M.gguf")
    }
}

    // MARK: - Helper Methods
    
    private func createEvaluationPrompt(
    userAnswer: String,
    correctAnswer: String,
    problemType: ProblemType,
    language: SupportedLanguage
) -> String {
    return """
    Please evaluate this language learning answer.
    
    Problem type: \(problemType.displayName)
    Language: \(language.displayName)
    Correct answer: \(correctAnswer)
    User answer: \(userAnswer)
    
    Provide a detailed evaluation in JSON format:
    {
      "isCorrect": true/false,
      "score": 0.0-1.0,
      "feedback": "Detailed feedback",
      "suggestions": ["suggestion1", "suggestion2"],
      "grammarErrors": ["error1", "error2"],
      "vocabularyErrors": ["error1", "error2"]
    }
    """
}

    private func parseVLMFeedback(_ response: String) throws -> VLMFeedback {
    // Extract JSON from response
    guard let jsonStart = response.range(of: "{"),
          let jsonEnd = response.range(of: "}", options: .backwards),
          jsonStart.lowerBound <= jsonEnd.lowerBound else {
        throw NSError(domain: "VLMService", code: 9, userInfo: [NSLocalizedDescriptionKey: "Invalid feedback format"])
    }
    
    let jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
    guard let jsonData = jsonString.data(using: .utf8) else {
        throw NSError(domain: "VLMService", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to convert feedback to data"])
    }
    
    let decoder = JSONDecoder()
    let feedbackResponse = try decoder.decode(VLMFeedbackResponse.self, from: jsonData)
    
    return VLMFeedback(
        isCorrect: feedbackResponse.isCorrect,
        score: feedbackResponse.score,
        feedback: feedbackResponse.feedback,
        suggestions: feedbackResponse.suggestions,
        detailedAnalysis: nil,
        grammarErrors: feedbackResponse.grammarErrors,
        vocabularyErrors: feedbackResponse.vocabularyErrors,
        pronunciationNotes: nil,
        naturalness: nil
    )
}

// MARK: - Response Structures

private struct VLMResponse: Codable {
    let sentence: String
    let translation: String
    let words: [String]
    let translations: [String]
}

private struct VLMFeedbackResponse: Codable {
    let isCorrect: Bool
    let score: Double
    let feedback: String
    let suggestions: [String]?
    let grammarErrors: [String]?
    let vocabularyErrors: [String]?
}