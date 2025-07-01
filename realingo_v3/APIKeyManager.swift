//
//  APIKeyManager.swift
//  realingo_v3
//
//  APIキーの管理（研究モードと通常モードの切り替え）
//

import Foundation
import SwiftUI

class APIKeyManager: ObservableObject {
    static let shared = APIKeyManager()
    
    @AppStorage("userGeminiAPIKey") private var userGeminiAPIKey: String = ""
    @AppStorage("isResearchMode") var isResearchMode: Bool = false
    @AppStorage("hasShownAPIKeySetup") private var hasShownAPIKeySetup: Bool = false
    @AppStorage("userGoogleAPIKey") private var userGoogleAPIKey: String = ""
    
    // Gemini APIキーの取得
    var geminiAPIKey: String {
        if isResearchMode {
            // 研究モードでは.envのAPIキーを使用
            // 注意: iOSアプリでは環境変数が読み込めないため、開発用にハードコードしています
            // 本番環境では適切な方法でAPIキーを管理してください
            let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
            let defaultKey = "AIzaSyDWpOgz56jjOCM5ckLzIkysdAs6QpZ4bQ8"
            let selectedKey = envKey ?? defaultKey
            print("[APIKeyManager] Research mode - using key: \(String(selectedKey.prefix(10)))...")
            return selectedKey
        } else {
            // 通常モードではユーザーが入力したAPIキーを使用
            print("[APIKeyManager] User mode - using key: \(String(userGeminiAPIKey.prefix(10)))...")
            return userGeminiAPIKey
        }
    }
    
    // Google APIキーの取得（App Check用）
    var googleAPIKey: String {
        // ユーザーが設定したGoogle APIキーがあればそれを使用
        if !userGoogleAPIKey.isEmpty {
            return userGoogleAPIKey
        }
        // なければ環境変数またはデフォルト値を使用
        return ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? "AIzaSyC6fR98x0LNgiar8cE9pufuP62rhgND_CM"
    }
    
    // CloudinaryのAPIキー（環境変数から取得）
    var cloudinaryCloudName: String {
        ProcessInfo.processInfo.environment["CLOUDINARY_CLOUD_NAME"] ?? "dy53z9iup"
    }
    
    var cloudinaryUploadPreset: String {
        ProcessInfo.processInfo.environment["CLOUDINARY_UPLOAD_PRESET"] ?? "ml_default"
    }
    
    // APIキーが設定されているかチェック
    var hasValidAPIKey: Bool {
        !geminiAPIKey.isEmpty
    }
    
    // 初回セットアップが必要かチェック
    var needsAPIKeySetup: Bool {
        !isResearchMode && userGeminiAPIKey.isEmpty && !hasShownAPIKeySetup
    }
    
    // ユーザーのAPIキーを設定
    func setUserAPIKey(_ key: String) {
        userGeminiAPIKey = key
    }
    
    // Google APIキーを設定
    func setGoogleAPIKey(_ key: String) {
        userGoogleAPIKey = key
    }
    
    // セットアップ完了をマーク
    func markAPIKeySetupShown() {
        hasShownAPIKeySetup = true
    }
    
    // APIキーをクリア
    func clearUserAPIKey() {
        userGeminiAPIKey = ""
    }
    
    private init() {}
}
