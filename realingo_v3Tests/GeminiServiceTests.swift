//
//  GeminiServiceTests.swift
//  realingo_v3Tests
//
//  GeminiService の単体テスト
//

import Testing
import Foundation
@testable import realingo_v3

struct GeminiServiceTests {
    
    // MARK: - Initialization Tests
    
    @Test func geminiServiceSingleton() {
        let service1 = GeminiService.shared
        let service2 = GeminiService.shared
        
        // シングルトンインスタンスが同一であることを確認
        #expect(service1 === service2)
    }
    
    // MARK: - Request Construction Tests
    
    @Test func geminiRequestConstruction() throws {
        let request = GeminiRequest(
            contents: [
                GeminiContent(
                    parts: [
                        GeminiPart(text: "Test prompt"),
                        GeminiPart(
                            inlineData: GeminiInlineData(
                                mimeType: "image/jpeg",
                                data: "base64encodeddata"
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
        
        #expect(request.contents.count == 1)
        #expect(request.contents[0].parts.count == 2)
        #expect(request.contents[0].parts[0].text == "Test prompt")
        #expect(request.generationConfig.temperature == 0.7)
        #expect(request.generationConfig.maxOutputTokens == 1000)
    }
    
    // MARK: - Response Parsing Tests
    
    @Test func geminiResponseParsing() throws {
        let jsonString = """
        {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "text": "{\\"question\\": \\"Test question\\", \\"answer\\": \\"Test answer\\", \\"options\\": [\\"word1\\", \\"word2\\"], \\"hints\\": [\\"hint1\\"], \\"explanation\\": \\"Test explanation\\", \\"tags\\": [\\"tag1\\"]}"
                            }
                        ]
                    }
                }
            ]
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        #expect(response.candidates.count == 1)
        #expect(response.candidates[0].content.parts.count == 1)
        #expect(response.candidates[0].content.parts[0].text != nil)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func geminiErrorDescriptions() {
        #expect(GeminiError.invalidURL.localizedDescription == "無効なURLです")
        #expect(GeminiError.noAPIKey.localizedDescription == "Gemini APIキーが設定されていません")
        #expect(GeminiError.noContent.localizedDescription == "コンテンツが取得できませんでした")
        #expect(GeminiError.parsingError.localizedDescription == "レスポンスの解析に失敗しました")
        
        // HTTPエラーのテスト
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        let serverError = GeminiError.serverError(response: mockResponse)
        #expect(serverError.localizedDescription == "サーバーエラー: 404")
    }
    
    // MARK: - VLMFeedback Tests
    
    @Test func vlmFeedbackParsing() throws {
        let jsonString = """
        {
            "score": 0.85,
            "feedback": "よくできています",
            "improvements": ["もう少し詳しく", "接続詞を使って"],
            "strengths": ["文法が正確", "語彙が豊富"],
            "grammarScore": 9,
            "vocabularyScore": 8,
            "contentScore": 8,
            "fluencyScore": 7
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let feedback = try JSONDecoder().decode(VLMFeedback.self, from: data)
        
        #expect(feedback.score == 0.85)
        #expect(feedback.feedback == "よくできています")
        #expect(feedback.improvements.count == 2)
        #expect(feedback.strengths.count == 2)
        #expect(feedback.grammarScore == 9)
        #expect(feedback.vocabularyScore == 8)
        #expect(feedback.contentScore == 8)
        #expect(feedback.fluencyScore == 7)
    }
    
    // MARK: - Mock Tests
    
    @Test func mockProblemGeneration() async throws {
        // 実際のAPIコールは行わず、ロジックのテストのみ
        let mockQuiz = ExtendedQuiz(
            problemID: "mock-123",
            language: .japanese,
            problemType: .wordArrangement,
            imageMode: .immediate,
            question: "この画像について説明してください",
            answer: "これは美しい風景です",
            imageUrl: "https://example.com/image.jpg",
            audioUrl: nil,
            options: ["これ", "は", "美しい", "風景", "です"],
            blankPositions: nil,
            hints: ["主語から始めましょう"],
            difficulty: 3,
            tags: ["nature", "description"],
            explanation: ["ja": "基本的な文章構造"],
            createdByGroup: "A",
            createdByParticipant: "test-user",
            createdAt: Date(),
            vlmGenerated: true,
            vlmModel: "gemini-1.5-flash"
        )
        
        #expect(mockQuiz.language == .japanese)
        #expect(mockQuiz.problemType == .wordArrangement)
        #expect(mockQuiz.options?.count == 5)
        #expect(mockQuiz.vlmModel == "gemini-1.5-flash")
    }
}