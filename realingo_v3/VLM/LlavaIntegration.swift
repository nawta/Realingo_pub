//
//  LlavaIntegration.swift
//  realingo_v3
//
//  llama.cppのllava API統合のための実装ガイド
//  参照: https://github.com/ggerganov/llama.cpp/tree/master/examples/llava
//  関連: LlamaContext.swift, VLMManager.swift
//

import Foundation
import UIKit

// MARK: - llava API統合の実装ガイド

/*
 llama.cppでVLM（Vision Language Model）を使用するための統合手順：
 
 1. 必要なファイル:
    - メインモデル (.gguf)
    - プロジェクションモデル (mmproj.gguf)
    - (オプション) ビジョンタワー設定
 
 2. llava APIの主要関数:
    - llava_image_embed_make_from_file()
    - llava_image_embed_make_from_data()
    - llava_eval_image_embed()
    - llava_image_embed_free()
 
 3. 実装手順:
    a. 画像の前処理
    b. 画像埋め込みの作成
    c. モデルへの画像埋め込みの評価
    d. テキストプロンプトとの結合
 */

// MARK: - 画像前処理

extension UIImage {
    /// VLM用に画像を前処理
    func preprocessForVLM(targetSize: CGSize = CGSize(width: 336, height: 336)) -> Data? {
        // アスペクト比を保持しながらリサイズ
        let scale = min(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // 背景を黒で塗りつぶし（パディング）
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))
        
        // 中央に画像を配置
        let origin = CGPoint(
            x: (targetSize.width - newSize.width) / 2,
            y: (targetSize.height - newSize.height) / 2
        )
        draw(in: CGRect(origin: origin, size: newSize))
        
        guard let processedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        // RGB形式のピクセルデータを取得
        return processedImage.rgbPixelData()
    }
    
    /// RGB形式のピクセルデータを取得
    private func rgbPixelData() -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 3 // RGB
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return Data(pixelData)
    }
}

// MARK: - llava APIブリッジ（実装例）

/*
 実際のllava API統合時は、以下のような関数を実装：
 
 ```c
 // C側のブリッジ関数（llama.xcframeworkに含まれる必要がある）
 
 struct llava_image_embed {
     void * data;
     int width;
     int height;
     int n_channels;
 };
 
 struct llava_image_embed * llava_image_embed_make_from_data(
     const void * image_data,
     int width,
     int height,
     int channels,
     struct llama_context * ctx_llama,
     struct clip_ctx * ctx_clip
 );
 
 bool llava_eval_image_embed(
     struct llama_context * ctx_llama,
     const struct llava_image_embed * embed,
     int n_batch,
     int * n_past
 );
 
 void llava_image_embed_free(struct llava_image_embed * embed);
 ```
 */

// MARK: - Swift側の実装例

class LlavaImageProcessor {
    
    /// 画像をVLMトークンに変換（実装例）
    static func encodeImage(_ image: UIImage, modelType: VLMModel) async throws -> [Int32] {
        // 1. 画像を前処理
        let targetSize: CGSize
        switch modelType.id {
        case VLMModelType.gemma3_4b_q4.rawValue, VLMModelType.gemma3_4b_q8.rawValue:
            targetSize = CGSize(width: 336, height: 336)
        case VLMModelType.heron_nvila_2b.rawValue:
            targetSize = CGSize(width: 448, height: 448) // SIGLIPの入力サイズ
        default:
            targetSize = CGSize(width: 336, height: 336) // デフォルトサイズ
        }
        
        guard let imageData = image.preprocessForVLM(targetSize: targetSize) else {
            throw VLMError.imageProcessingError
        }
        
        // 2. 実際のllava API呼び出し（現在は仮実装）
        // 本来は以下のような処理：
        /*
        let embed = llava_image_embed_make_from_data(
            imageData.bytes,
            Int32(targetSize.width),
            Int32(targetSize.height),
            3, // RGB channels
            llamaContext,
            clipContext
        )
        
        defer { llava_image_embed_free(embed) }
        
        var n_past: Int32 = 0
        let success = llava_eval_image_embed(
            llamaContext,
            embed,
            512, // batch size
            &n_past
        )
        
        if !success {
            throw VLMError.inferenceError("Image embedding evaluation failed")
        }
        */
        
        // 3. 仮のトークン列を返す（実際はllava_evalの結果）
        return generateMockImageTokens(for: modelType)
    }
    
    private static func generateMockImageTokens(for model: VLMModel) -> [Int32] {
        switch model.id {
        case VLMModelType.gemma3_4b_q4.rawValue, VLMModelType.gemma3_4b_q8.rawValue:
            // Gemmaの画像トークン形式
            return [32000] + Array(repeating: Int32.random(in: 1000...31999), count: 576) + [32001]
        case VLMModelType.heron_nvila_2b.rawValue:
            // Heronの画像トークン形式（SIGLIP）
            return [32002] + Array(repeating: Int32.random(in: 1000...31999), count: 729) + [32003]
        default:
            // デフォルトの画像トークン形式
            return [32000] + Array(repeating: Int32.random(in: 1000...31999), count: 576) + [32001]
        }
    }
}

// MARK: - プロンプトテンプレート

extension VLMModel {
    /// モデル固有のプロンプトテンプレートを適用
    func formatPrompt(userPrompt: String, withImage: Bool = true) -> String {
        switch self.id {
        case VLMModelType.gemma3_4b_q4.rawValue, VLMModelType.gemma3_4b_q8.rawValue:
            return """
            <start_of_turn>user
            \(withImage ? "<image>" : "")
            \(userPrompt)
            <end_of_turn>
            <start_of_turn>model
            """
            
        case VLMModelType.heron_nvila_2b.rawValue:
            return """
            \(withImage ? "[IMG]" : "")
            USER: \(userPrompt)
            ASSISTANT:
            """
            
        default:
            // デフォルトフォーマット
            return """
            \(withImage ? "<image>" : "")
            \(userPrompt)
            """
        }
    }
}

// MARK: - 統合のための設定

struct LlavaConfig {
    let imageSize: CGSize
    let patchSize: Int
    let numPatches: Int
    let projectionDim: Int
    let hiddenDim: Int
    
    static let gemmaConfig = LlavaConfig(
        imageSize: CGSize(width: 336, height: 336),
        patchSize: 14,
        numPatches: 576, // (336/14)^2
        projectionDim: 2048,
        hiddenDim: 2048
    )
    
    static let heronConfig = LlavaConfig(
        imageSize: CGSize(width: 448, height: 448),
        patchSize: 14,
        numPatches: 1024, // (448/14)^2, ただし2x2ダウンサンプリング
        projectionDim: 2048,
        hiddenDim: 1536 // Qwen2.5-1.5Bの次元
    )
}