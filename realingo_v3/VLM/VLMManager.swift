//
//  VLMManager.swift
//  realingo_v3
//
//  オンデバイスVLM（Vision Language Model）の管理
//  参照: third_party/llama.cpp/examples/llama.swiftui
//  関連: VLMService.swift, ModelDownloadManager.swift
//

import Foundation
import SwiftUI
import Combine

// サポートされるVLMモデル
enum VLMModelType: String, CaseIterable {
    case llava_v1_5_7b_q4 = "llava-v1.5-7b-Q4_K_M"
    case llava_v1_5_7b_q8 = "llava-v1.5-7b-Q8_0"
    case llava_v1_6_mistral_7b_q4 = "llava-v1.6-mistral-7b-Q4_K_M"
    case gemma3_4b_q4 = "gemma-3-4b-it-Q4_K_M"
    case gemma3_4b_q8 = "gemma-3-4b-it-Q8_0"
    case heron_nvila_2b = "Heron-NVILA-Lite-2B"
    
    var displayName: String {
        switch self {
        case .llava_v1_5_7b_q4:
            return "LLaVA v1.5 7B (Q4_K_M, 3.8 GiB)"
        case .llava_v1_5_7b_q8:
            return "LLaVA v1.5 7B (Q8_0, 7.1 GiB)"
        case .llava_v1_6_mistral_7b_q4:
            return "LLaVA v1.6 Mistral 7B (Q4_K_M, 4.0 GiB)"
        case .gemma3_4b_q4:
            return "Gemma 3 4B (Q4_K_M, 2.5 GiB)"
        case .gemma3_4b_q8:
            return "Gemma 3 4B (Q8_0, 4.2 GiB)"
        case .heron_nvila_2b:
            return "Heron NVILA Lite 2B (1.8 GiB)"
        }
    }
    
    var filename: String {
        switch self {
        case .llava_v1_5_7b_q4:
            return "ggml-model-q4_k.gguf"
        case .llava_v1_5_7b_q8:
            return "ggml-model-q8_0.gguf"
        case .llava_v1_6_mistral_7b_q4:
            return "llava-v1.6-mistral-7b.Q4_K_M.gguf"
        case .gemma3_4b_q4:
            return "gemma-3-4b-it-Q4_K_M.gguf"
        case .gemma3_4b_q8:
            return "gemma-3-4b-it-Q8_0.gguf"
        case .heron_nvila_2b:
            return "heron-nvila-lite-2b.gguf"
        }
    }
    
    var downloadURL: String {
        switch self {
        case .llava_v1_5_7b_q4:
            return "https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/ggml-model-q4_k.gguf"
        case .llava_v1_5_7b_q8:
            return "https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/ggml-model-q8_0.gguf"
        case .llava_v1_6_mistral_7b_q4:
            return "https://huggingface.co/cjpais/llava-v1.6-mistral-7b-gguf/resolve/main/llava-v1.6-mistral-7b.Q4_K_M.gguf"
        case .gemma3_4b_q4:
            return "https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf"
        case .gemma3_4b_q8:
            return "https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q8_0.gguf"
        case .heron_nvila_2b:
            return "https://huggingface.co/turing-motors/Heron-NVILA-Lite-2B/resolve/main/heron-nvila-lite-2b.gguf"
        }
    }
    
    var projectionModelURL: String? {
        switch self {
        case .llava_v1_5_7b_q4, .llava_v1_5_7b_q8:
            return "https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/mmproj-model-f16.gguf"
        case .llava_v1_6_mistral_7b_q4:
            return "https://huggingface.co/cjpais/llava-v1.6-mistral-7b-gguf/resolve/main/mmproj-model-f16.gguf"
        case .gemma3_4b_q4, .gemma3_4b_q8:
            return "https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/mmproj-model-f16.gguf"
        case .heron_nvila_2b:
            // HeronモデルのプロジェクタはGGUF変換が必要
            // 変換済みのものがあれば、そのURLを指定
            return nil // TODO: 変換済みmmproj.ggufのURL
        }
    }
    
    var projectionModelFilename: String? {
        switch self {
        case .llava_v1_5_7b_q4, .llava_v1_5_7b_q8:
            return "mmproj-model-f16.gguf"
        case .llava_v1_6_mistral_7b_q4:
            return "mmproj-model-f16.gguf"
        case .gemma3_4b_q4, .gemma3_4b_q8:
            return "mmproj-gemma-f16.gguf"
        case .heron_nvila_2b:
            return "mmproj-heron-nvila.gguf"
        }
    }
    
    var requiresVisionTower: Bool {
        switch self {
        case .heron_nvila_2b:
            return true // HeronはSIGLIPビジョンタワーが必要
        default:
            return false
        }
    }
    
    var modelSize: String {
        switch self {
        case .llava_v1_5_7b_q4:
            return "3.8 GiB"
        case .llava_v1_5_7b_q8:
            return "7.1 GiB"
        case .llava_v1_6_mistral_7b_q4:
            return "4.0 GiB"
        case .gemma3_4b_q4:
            return "2.5 GiB"
        case .gemma3_4b_q8:
            return "4.2 GiB"
        case .heron_nvila_2b:
            return "1.8 GiB"
        }
    }
    
    var description: String {
        switch self {
        case .llava_v1_5_7b_q4:
            return "高品質・標準VLMモデル"
        case .llava_v1_5_7b_q8:
            return "高精度・標準VLMモデル"
        case .llava_v1_6_mistral_7b_q4:
            return "最新版・高性能VLMモデル"
        case .gemma3_4b_q4:
            return "高速・省メモリ版"
        case .gemma3_4b_q8:
            return "高精度版"
        case .heron_nvila_2b:
            return "軽量・日本語対応"
        }
    }
}

// モデルの状態
struct VLMModelState {
    let model: VLMModel
    var isDownloaded: Bool
    var isLoaded: Bool
    var downloadProgress: Double
    var status: String
    var isProjectionModelDownloaded: Bool = false
    var projectionModelProgress: Double = 0
}

// VLMエラー
enum VLMError: LocalizedError {
    case modelNotFound
    case contextInitializationFailed
    case inferenceError(String)
    case imageProcessingError
    case unsupportedModel
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "モデルファイルが見つかりません"
        case .contextInitializationFailed:
            return "モデルの初期化に失敗しました"
        case .inferenceError(let message):
            return "推論エラー: \(message)"
        case .imageProcessingError:
            return "画像の処理に失敗しました"
        case .unsupportedModel:
            return "サポートされていないモデルです"
        }
    }
}

// VLM管理クラス
@MainActor
class VLMManager: ObservableObject {
    static let shared = VLMManager()
    
    @Published var modelStates: [VLMModelState] = []
    @Published var currentModel: VLMModel?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    // llama.cpp context
    private var llamaContext: LlamaContext?
    
    // ダウンロードマネージャー
    private let downloadManager = ModelDownloadManager.shared
    
    private init() {
        initializeModelStates()
        observeDownloadProgress()
    }
    
    private func initializeModelStates() {
        modelStates = VLMModelType.allCases.map { modelType in
            let model = VLMModel(
                id: modelType.rawValue,
                name: modelType.displayName,
                filename: modelType.filename,
                url: modelType.downloadURL,
                size: modelType.modelSize,
                description: modelType.description,
                projectionModelURL: modelType.projectionModelURL,
                projectionModelFilename: modelType.projectionModelFilename,
                requiresVisionTower: modelType.requiresVisionTower
            )
            return VLMModelState(
                model: model,
                isDownloaded: checkModelExists(modelType),
                isLoaded: false,
                downloadProgress: 0,
                status: checkModelExists(modelType) ? "ダウンロード済み" : "未ダウンロード"
            )
        }
    }
    
    private func observeDownloadProgress() {
        // ダウンロード進捗を監視
        downloadManager.$downloadTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateDownloadProgress(tasks)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func updateDownloadProgress(_ tasks: [VLMModel: DownloadTask]) {
        for (model, task) in tasks {
            if let index = modelStates.firstIndex(where: { $0.model == model }) {
                // タスクの進捗を監視
                task.$progress
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] progress in
                        self?.modelStates[index].downloadProgress = progress
                    }
                    .store(in: &cancellables)
                
                // ステータステキストを更新
                if let statusText = downloadManager.getStatusText(for: model) {
                    modelStates[index].status = statusText
                }
            }
        }
    }
    
    private func checkModelExists(_ model: VLMModel) -> Bool {
        let fileURL = getModelURL(for: model)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    private func checkModelExists(_ modelType: VLMModelType) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("VLMModels").appendingPathComponent(modelType.filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    private func getModelURL(for model: VLMModel) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("VLMModels").appendingPathComponent(model.filename)
    }
    
    // モデルのダウンロード
    func downloadModel(_ model: VLMModel) async throws {
        guard let index = modelStates.firstIndex(where: { $0.model == model }) else { return }
        
        do {
            // メインモデルをダウンロード
            let fileURL = try await downloadManager.downloadModel(model)
            
            // ダウンロード完了後の処理
            modelStates[index].isDownloaded = true
            modelStates[index].status = "モデルダウンロード完了"
            modelStates[index].downloadProgress = 1.0
            
            print("[VLMManager] モデルダウンロード完了: \(fileURL)")
            
            // プロジェクションモデルもダウンロード（必要な場合）
            if let projectionURL = model.projectionModelURL,
               let projectionFilename = model.projectionModelFilename {
                
                modelStates[index].status = "プロジェクションモデルをダウンロード中..."
                
                let projectionPath = getModelURL(for: model).deletingLastPathComponent()
                    .appendingPathComponent(projectionFilename)
                
                // プロジェクションモデルのダウンロード
                try await downloadProjectionModel(from: projectionURL, to: projectionPath, modelIndex: index)
                
                modelStates[index].isProjectionModelDownloaded = true
                modelStates[index].status = "全てのダウンロード完了"
            }
            
        } catch {
            modelStates[index].status = "ダウンロードエラー: \(error.localizedDescription)"
            modelStates[index].downloadProgress = 0
            throw error
        }
    }
    
    // プロジェクションモデルのダウンロード
    private func downloadProjectionModel(from urlString: String, to localURL: URL, modelIndex: Int) async throws {
        guard let url = URL(string: urlString) else {
            throw VLMError.modelNotFound
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        try data.write(to: localURL)
        
        modelStates[modelIndex].projectionModelProgress = 1.0
        print("[VLMManager] プロジェクションモデルダウンロード完了: \(localURL)")
    }
    
    // モデルのロード
    func loadModel(_ model: VLMModel) async throws {
        guard checkModelExists(model) else {
            throw VLMError.modelNotFound
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 現在のモデルをアンロード
        if let currentModel = currentModel {
            await unloadModel(currentModel)
        }
        
        let modelPath = getModelURL(for: model).path
        var projectionPath: String? = nil
        
        // プロジェクションモデルのパスを取得
        if let projectionFilename = model.projectionModelFilename {
            let projectionURL = getModelURL(for: model).deletingLastPathComponent()
                .appendingPathComponent(projectionFilename)
            if FileManager.default.fileExists(atPath: projectionURL.path) {
                projectionPath = projectionURL.path
                print("[VLMManager] プロジェクションモデル検出: \(projectionPath!)")
            }
        }
        
        do {
            // llama.cpp context初期化
            llamaContext = try await LlamaContext.create_context(path: modelPath)
            
            currentModel = model
            if let index = modelStates.firstIndex(where: { $0.model == model }) {
                modelStates[index].isLoaded = true
                modelStates[index].status = "ロード済み"
            }
            
            // モデル情報をログ出力
            if let context = llamaContext {
                let modelInfo = await context.model_info()
                print("[VLMManager] モデル情報: \(modelInfo)")
            }
        } catch {
            errorMessage = "モデルのロードに失敗しました: \(error.localizedDescription)"
            throw VLMError.contextInitializationFailed
        }
    }
    
    // モデルのアンロード
    private func unloadModel(_ model: VLMModel) async {
        llamaContext = nil
        if let index = modelStates.firstIndex(where: { $0.model == model }) {
            modelStates[index].isLoaded = false
            modelStates[index].status = "ダウンロード済み"
        }
    }
    
    // VLM推論の実行
    func processImageWithText(image: UIImage, prompt: String) async throws -> String {
        guard let model = currentModel else {
            throw VLMError.modelNotFound
        }
        
        guard let context = llamaContext else {
            throw VLMError.contextInitializationFailed
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 画像の前処理
        guard let imageData = prepareImageForVLM(image) else {
            throw VLMError.imageProcessingError
        }
        
        // VLMプロンプトの構築
        let vlmPrompt = buildVLMPrompt(model: model, userPrompt: prompt)
        
        do {
            // 実際の推論処理
            let result = try await context.generate_with_image(
                prompt: vlmPrompt,
                imageData: imageData
            )
            
            // 結果のクリーンアップ
            await context.clear()
            
            return result
        } catch {
            print("[VLMManager] 推論エラー: \(error)")
            throw VLMError.inferenceError(error.localizedDescription)
        }
    }
    
    // 画像の前処理
    private func prepareImageForVLM(_ image: UIImage) -> Data? {
        // 画像サイズの調整（VLMモデルに合わせて）
        let maxSize: CGFloat = 448 // 一般的なVLMの入力サイズ
        
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage?.jpegData(compressionQuality: 0.9)
    }
    
    // VLMプロンプトの構築
    private func buildVLMPrompt(model: VLMModel, userPrompt: String) -> String {
        // モデルに応じたプロンプトフォーマット
        switch model.id {
        case VLMModelType.gemma3_4b_q4.rawValue, VLMModelType.gemma3_4b_q8.rawValue:
            return """
            <start_of_turn>user
            <image>
            \(userPrompt)
            <end_of_turn>
            <start_of_turn>model
            """
        case VLMModelType.heron_nvila_2b.rawValue:
            return """
            [IMG]
            USER: \(userPrompt)
            ASSISTANT:
            """
        default:
            // デフォルトフォーマット
            return """
            <image>
            \(userPrompt)
            """
        }
    }
    
    // モデルの削除
    func deleteModel(_ model: VLMModel) throws {
        let fileURL = getModelURL(for: model)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        if let index = modelStates.firstIndex(where: { $0.model == model }) {
            modelStates[index].isDownloaded = false
            modelStates[index].isLoaded = false
            modelStates[index].status = "未ダウンロード"
            modelStates[index].downloadProgress = 0
        }
        
        if currentModel == model {
            currentModel = nil
            llamaContext = nil
        }
    }
}