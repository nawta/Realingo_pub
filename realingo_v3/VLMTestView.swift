//
//  VLMTestView.swift
//  realingo_v3
//
//  VLM推論テスト画面
//  参照: VLMManager.swift, LlamaContext.swift
//  関連: VLMModelManagementView.swift
//

import SwiftUI
import PhotosUI

struct VLMTestView: View {
    @StateObject private var vlmManager = VLMManager.shared
    @State private var selectedImage: UIImage?
    @State private var prompt = "この画像を説明してください。"
    @State private var result = ""
    @State private var isProcessing = false
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // モデル状態
                    modelStatusSection
                    
                    // 画像選択
                    imageSection
                    
                    // プロンプト入力
                    promptSection
                    
                    // 実行ボタン
                    executeButton
                    
                    // 結果表示
                    if !result.isEmpty {
                        resultSection
                    }
                    
                    if let error = vlmManager.errorMessage {
                        errorSection(error)
                    }
                }
                .padding()
            }
            .navigationTitle("VLM推論テスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .photosPicker(isPresented: $showingImagePicker,
                         selection: $selectedItem,
                         matching: .images)
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var modelStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("モデル状態")
                .font(.headline)
            
            if let currentModel = vlmManager.currentModel {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(currentModel.displayName) ロード済み")
                        .font(.subheadline)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("モデルがロードされていません")
                        .font(.subheadline)
                }
                
                Text("VLMモデル管理画面からモデルをダウンロード・ロードしてください")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("画像")
                .font(.headline)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(10)
                    .overlay(
                        Button(action: { selectedImage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
            } else {
                Button(action: { showingImagePicker = true }) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("画像を選択")
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
    }
    
    @ViewBuilder
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("プロンプト")
                .font(.headline)
            
            TextEditor(text: $prompt)
                .frame(height: 100)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // プリセットプロンプト
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    presetButton("この画像を説明してください。")
                    presetButton("画像の中に何が見えますか？")
                    presetButton("画像の雰囲気を教えてください。")
                    presetButton("この画像から物語を作ってください。")
                }
            }
        }
    }
    
    @ViewBuilder
    private func presetButton(_ text: String) -> some View {
        Button(action: { prompt = text }) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(15)
        }
    }
    
    @ViewBuilder
    private var executeButton: some View {
        Button(action: executeVLM) {
            if isProcessing {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("処理中...")
                }
            } else {
                Text("推論実行")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(canExecute ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(10)
        .disabled(!canExecute || isProcessing)
    }
    
    private var canExecute: Bool {
        vlmManager.currentModel != nil && selectedImage != nil && !prompt.isEmpty
    }
    
    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("結果")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { UIPasteboard.general.string = result }) {
                    Label("コピー", systemImage: "doc.on.doc")
                        .font(.caption)
                }
            }
            
            Text(result)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private func errorSection(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Actions
    
    private func executeVLM() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        result = ""
        
        Task {
            do {
                let startTime = Date()
                let response = try await vlmManager.processImageWithText(
                    image: image,
                    prompt: prompt
                )
                let elapsed = Date().timeIntervalSince(startTime)
                
                await MainActor.run {
                    self.result = response
                    print("[VLMTest] 推論完了: \(elapsed)秒")
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.result = "エラー: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}

#Preview {
    VLMTestView()
}