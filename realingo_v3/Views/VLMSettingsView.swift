//
//  VLMSettingsView.swift
//  realingo_v3
//
//  オンデバイスVLMの設定画面
//  参照: specification.md - VLM設定機能
//  関連: VLMManager.swift, ProblemGenerationService.swift
//

import SwiftUI

struct VLMSettingsView: View {
    @StateObject private var vlmManager = VLMManager.shared
    @StateObject private var problemService = ProblemGenerationService.shared
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: VLMModel?
    @State private var downloadingModel: VLMModel?
    @State private var errorMessage: String?
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            List {
                // 現在のモード表示
                Section {
                    HStack {
                        Label(
                            problemService.currentMode.rawValue,
                            systemImage: problemService.currentMode.icon
                        )
                        Spacer()
                        if problemService.currentMode == .onDeviceVLM {
                            if let model = vlmManager.currentModel {
                                Text(model.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("モデル未選択")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // モード切り替えピッカー
                    Picker("問題生成モード", selection: $problemService.currentMode) {
                        ForEach(ProblemGenerationMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: problemService.currentMode) { newMode in
                        let validation = problemService.canSwitchToMode(newMode)
                        if !validation.canSwitch {
                            errorMessage = validation.reason
                            // 切り替えを元に戻す
                            problemService.currentMode = (newMode == .geminiAPI) ? .onDeviceVLM : .geminiAPI
                        }
                    }
                } header: {
                    Text("問題生成モード")
                } footer: {
                    Text(problemService.currentMode.description)
                        .font(.caption)
                }
                
                // VLMモデル管理
                if problemService.currentMode == .onDeviceVLM {
                    Section {
                        ForEach(vlmManager.modelStates, id: \.model) { state in
                            VLMModelRowView(
                                state: state,
                                onDownload: { model in
                                    downloadModel(model)
                                },
                                onLoad: { model in
                                    loadModel(model)
                                },
                                onDelete: { model in
                                    modelToDelete = model
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    } header: {
                        Text("利用可能なVLMモデル")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("注意事項:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("• モデルのダウンロードには時間がかかります")
                                .font(.caption)
                            Text("• デバイスのストレージ容量を確認してください")
                                .font(.caption)
                            Text("• オンデバイスVLMはネットワーク接続不要です")
                                .font(.caption)
                        }
                    }
                }
                
                // エラーメッセージ
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("AI設定")
            .navigationBarTitleDisplayMode(.inline)
            .alert("モデルを削除", isPresented: $showingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除", role: .destructive) {
                    if let model = modelToDelete {
                        deleteModel(model)
                    }
                }
            } message: {
                Text("このモデルをデバイスから削除しますか？")
            }
        }
    }
    
    // モデルのダウンロード
    private func downloadModel(_ model: VLMModel) {
        downloadingModel = model
        
        Task {
            do {
                try await vlmManager.downloadModel(model)
                downloadingModel = nil
            } catch {
                errorMessage = "ダウンロードエラー: \(error.localizedDescription)"
                downloadingModel = nil
            }
        }
    }
    
    // モデルのロード
    private func loadModel(_ model: VLMModel) {
        Task {
            do {
                try await vlmManager.loadModel(model)
                errorMessage = nil
            } catch {
                errorMessage = "ロードエラー: \(error.localizedDescription)"
            }
        }
    }
    
    // モデルの削除
    private func deleteModel(_ model: VLMModel) {
        do {
            try vlmManager.deleteModel(model)
            errorMessage = nil
        } catch {
            errorMessage = "削除エラー: \(error.localizedDescription)"
        }
    }
}

// VLMモデル行
struct VLMModelRowView: View {
    let state: VLMModelState
    let onDownload: (VLMModel) -> Void
    let onLoad: (VLMModel) -> Void
    let onDelete: (VLMModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.model.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(state.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // アクションボタン
                if state.isLoaded {
                    Label("使用中", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if state.isDownloaded {
                    HStack(spacing: 8) {
                        Button("読込") {
                            onLoad(state.model)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button {
                            onDelete(state.model)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button("取得") {
                        onDownload(state.model)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // ダウンロード進捗
            if state.downloadProgress > 0 && state.downloadProgress < 1 {
                ProgressView(value: state.downloadProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// プレビュー
#Preview {
    VLMSettingsView()
}