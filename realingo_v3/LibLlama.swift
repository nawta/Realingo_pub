import Foundation
import UIKit

// MARK: - Error Types
enum LlamaError: Error {
    case couldNotInitializeContext
    case couldNotLoadModel
    case couldNotLoadClipModel
    case invalidImageData
    case couldNotCreateImageEmbed
    case evaluationFailed
    case modelNotFound
    case invalidInput
    case inferenceError(String)
}

// MARK: - LlamaContext Actor using VLMWrapper
actor LlamaContext {
    private var wrapper: VLMWrapper?
    private var modelPath: String?
    private var clipModelPath: String?
    
    var is_done: Bool = false
    var n_len: Int32 = 1024
    var n_cur: Int32 = 0
    var n_decode: Int32 = 0
    
    init() {
        // Empty init for compatibility
    }
    
    // MARK: - Model Loading
    
    static func create_context(path: String, clipPath: String? = nil) async throws -> LlamaContext {
        let context = LlamaContext()
        try await context.loadModel(path: path, clipPath: clipPath)
        return context
    }
    
    // Legacy method for compatibility
    static func create_context(path: String) async throws -> LlamaContext {
        return try await create_context(path: path, clipPath: nil)
    }
    
    private func loadModel(path: String, clipPath: String? = nil) async throws {
        self.modelPath = path
        self.clipModelPath = clipPath
        
        // Create wrapper on main thread
        let wrapper = await MainActor.run {
            VLMWrapper(modelPath: path, clipPath: clipPath ?? "")
        }
        
        guard let wrapper = wrapper else {
            throw LlamaError.couldNotLoadModel
        }
        
        self.wrapper = wrapper
        print("Model loaded successfully")
        
        if clipPath != nil && wrapper.clipContext != nil {
            print("CLIP model loaded successfully")
        } else if clipPath != nil {
            print("Warning: CLIP model failed to load")
        }
    }
    
    // MARK: - VLM Methods
    
    func generate_with_image(prompt: String, imageData: Data) async throws -> String {
        guard let wrapper = wrapper else {
            throw LlamaError.couldNotInitializeContext
        }
        
        guard wrapper.clipContext != nil else {
            // Fallback to dummy response if no CLIP model
            print("[LlamaContext] Warning: No CLIP model loaded, returning dummy response")
            return """
            {
                "sentence": "Tämä on kaunis kuva",
                "translation": "これは美しい写真です",
                "words": ["Tämä", "on", "kaunis", "kuva"],
                "translations": ["これは", "です", "美しい", "写真"]
            }
            """
        }
        
        // Generate response using wrapper
        let response = await MainActor.run {
            wrapper.generateResponse(withPrompt: prompt, imageData: imageData)
        }
        
        return response ?? "Error: No response generated"
    }
    
    // MARK: - Text Generation Methods (for compatibility)
    
    func completion_init(text: String) async {
        guard let wrapper = wrapper else { return }
        
        print("attempting to complete \"\(text)\"")
        
        // Tokenize and evaluate
        let tokens = await MainActor.run {
            wrapper.tokenize(text, addBos: true)
        }
        
        guard let tokens = tokens else {
            print("Failed to tokenize text")
            return
        }
        
        let success = await MainActor.run {
            wrapper.evaluateTokens(tokens)
        }
        
        if !success {
            print("Failed to evaluate initial tokens")
        }
        
        n_cur = Int32(tokens.count)
    }
    
    func completion_loop() async -> String {
        // This would need a more complex implementation
        // For now, return dummy response
        n_cur += 1
        if n_cur >= 10 {
            is_done = true
            return "\n"
        }
        return "Token \(n_cur) "
    }
    
    func clear() async {
        guard let wrapper = wrapper else { return }
        
        await MainActor.run {
            wrapper.clearContext()
        }
        
        is_done = false
        n_cur = 0
        n_decode = 0
    }
    
    func model_info() async -> String {
        guard let wrapper = wrapper else { 
            return "No model loaded"
        }
        
        return await MainActor.run {
            wrapper.modelInfo() ?? "No model info available"
        }
    }
    
    func bench(pp: Int, tg: Int, pl: Int, nr: Int = 1) async -> String {
        // Benchmark implementation
        return "Benchmark not implemented for VLM mode"
    }
    
    // MARK: - Compatibility methods
    
    func setModelPath(_ path: String) {
        modelPath = path
    }
    
    func setClipModelPath(_ path: String) {
        clipModelPath = path
    }
    
    deinit {
        // Wrapper will be deallocated automatically
    }
}

// MARK: - Helper structures for compatibility

struct llama_batch {
    var n_tokens: Int32 = 0
}

typealias llama_token = Int32
typealias llama_pos = Int32
typealias llama_seq_id = Int32

func llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}

func llama_batch_add(_ batch: inout llama_batch, _ id: llama_token, _ pos: llama_pos, _ seq_ids: [llama_seq_id], _ logits: Bool) {
    batch.n_tokens += 1
}