//
//  APIKeySetupView.swift
//  realingo_v3
//
//  Gemini APIキーの設定画面
//

import SwiftUI

struct APIKeySetupView: View {
    @StateObject private var apiKeyManager = APIKeyManager.shared
    @State private var apiKey: String = ""
    @State private var showingInfo = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(LocalizationHelper.getCommonText("geminiAPIKeySetup", for: nativeLanguage))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(LocalizationHelper.getCommonText("apiKeyRequired", for: nativeLanguage))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // 説明セクション
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("APIキーについて")
                                .fontWeight(.semibold)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Gemini APIキーはGoogleのAI Studioから無料で取得できます")
                            Text("• APIキーは安全にアプリ内に保存されます")
                            Text("• インターネット接続が必要です")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Button(action: { showingInfo = true }) {
                            Label("APIキーの取得方法", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // APIキー入力フィールド
                    VStack(alignment: .leading, spacing: 8) {
                        Text("APIキー")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        SecureField("APIキーを入力", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("例: AIza...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // アクションボタン
                    VStack(spacing: 12) {
                        Button(action: saveAPIKey) {
                            Text(LocalizationHelper.getCommonText("saveSettings", for: nativeLanguage))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(apiKey.isEmpty ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(apiKey.isEmpty)
                        
                        Button(action: skipSetup) {
                            Text(LocalizationHelper.getCommonText("setLater", for: nativeLanguage))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 研究モードの説明
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                                .foregroundColor(.orange)
                            Text("研究モードについて")
                                .fontWeight(.semibold)
                        }
                        
                        Text("研究参加者の方は、研究モードを有効にすることで、APIキーの設定なしでアプリを使用できます。メインメニューの研究設定から有効化してください。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitle("初期設定", displayMode: .inline)
            .sheet(isPresented: $showingInfo) {
                APIKeyInfoView()
            }
        }
    }
    
    private func saveAPIKey() {
        apiKeyManager.setUserAPIKey(apiKey)
        apiKeyManager.markAPIKeySetupShown()
        dismiss()
    }
    
    private func skipSetup() {
        apiKeyManager.markAPIKeySetupShown()
        dismiss()
    }
}

struct APIKeyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Gemini APIキーの取得方法")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        StepView(number: "1", title: "Google AI Studioにアクセス", 
                                description: "https://makersuite.google.com/app/apikey にアクセスします")
                        
                        StepView(number: "2", title: "Googleアカウントでログイン", 
                                description: "Googleアカウントでログインします")
                        
                        StepView(number: "3", title: "APIキーを作成", 
                                description: "「Create API Key」ボタンをクリックします")
                        
                        StepView(number: "4", title: "APIキーをコピー", 
                                description: "生成されたAPIキーをコピーします")
                        
                        StepView(number: "5", title: "アプリに貼り付け", 
                                description: "このアプリの設定画面にAPIキーを貼り付けます")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("注意事項", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                        
                        Text("• APIキーは他人と共有しないでください")
                        Text("• 無料枠には使用制限があります")
                        Text("• APIキーはいつでも再生成できます")
                    }
                    .font(.caption)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationBarTitle("取得方法", displayMode: .inline)
            .navigationBarItems(trailing: Button("閉じる") { dismiss() })
        }
    }
}

struct StepView: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// 設定画面用のAPIキー管理ビュー
struct APIKeySettingsView: View {
    @StateObject private var apiKeyManager = APIKeyManager.shared
    @State private var newAPIKey: String = ""
    @State private var showingEditSheet = false
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationHelper.getCommonText("apiSettings", for: nativeLanguage))
                .font(.headline)
            
            if apiKeyManager.hasValidAPIKey && !apiKeyManager.isResearchMode {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Gemini APIキー")
                            .font(.subheadline)
                        Text(LocalizationHelper.getCommonText("configured", for: nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    Button("変更") {
                        showingEditSheet = true
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else if apiKeyManager.isResearchMode {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("研究モードで動作中")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading) {
                    Text(LocalizationHelper.getCommonText("apiKeyNotSet", for: nativeLanguage))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Button(action: { showingEditSheet = true }) {
                        Label(LocalizationHelper.getCommonText("setAPIKey", for: nativeLanguage), systemImage: "key")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("APIキーの変更")
                        .font(.headline)
                    
                    SecureField("新しいAPIキー", text: $newAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Button("キャンセル") {
                            showingEditSheet = false
                            newAPIKey = ""
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("保存") {
                            apiKeyManager.setUserAPIKey(newAPIKey)
                            showingEditSheet = false
                            newAPIKey = ""
                        }
                        .disabled(newAPIKey.isEmpty)
                    }
                }
                .padding()
                .navigationBarTitle("APIキー変更", displayMode: .inline)
            }
        }
    }
}

#Preview {
    APIKeySetupView()
}