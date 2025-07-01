//
//  ResearchSettingsView.swift
//  realingo_v3
//
//  研究設定画面
//  参照: specification.md - 研究モード設定
//  関連: ConsentView.swift, ReviewView.swift
//

import SwiftUI

struct ResearchSettingsView: View {
    @AppStorage("isResearchMode") private var isResearchMode = false
    @AppStorage("participantID") private var participantID = ""
    @AppStorage("groupID") private var groupID = ""
    @AppStorage("researchConsentGiven") private var consentGiven = false
    
    @State private var showingConsentView = false
    @State private var showingDataExport = false
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var vlmManager = VLMManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                // 研究モード設定
                researchModeSection()
                
                // APIキー設定（研究モード時は非表示）
                if !isResearchMode {
                    Section(header: Text("API設定")) {
                        APIKeySettingsView()
                    }
                }
                
                // VLMモデル設定
                vlmModelSection()
                
                // データ管理
                dataManagementSection()
                
                // 研究情報
                researchInfoSection()
                
                // お問い合わせ
                Section(header: Text("お問い合わせ")) {
                    Link(destination: URL(string: "mailto:research@example.com")!) {
                        Label("研究に関するお問い合わせ", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("研究設定")
            .navigationBarItems(trailing: Button("完了") { dismiss() })
            .sheet(isPresented: $showingConsentView) {
                ConsentView(isPresented: $showingConsentView)
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .onAppear {
                // Firebase上の同意状態と同期
                Task {
                    if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
                        do {
                            let profile = try await DataPersistenceManager.shared.getUserProfile(participantID: userID)
                            if let profileConsent = profile?.consentGiven {
                                await MainActor.run {
                                    consentGiven = profileConsent
                                    UserDefaults.standard.set(profileConsent, forKey: "researchConsentGiven")
                                }
                            }
                        } catch {
                            print("[ResearchSettings] プロファイル読み込みエラー: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func researchModeSection() -> some View {
        Section(header: Text("研究モード")) {
            Toggle("研究モードを有効にする", isOn: $isResearchMode)
                .onChange(of: isResearchMode) { oldValue, newValue in
                    if newValue && !consentGiven {
                        showingConsentView = true
                    }
                }
            
            if isResearchMode {
                HStack {
                    Text("参加者ID")
                    Spacer()
                    Text(participantID.isEmpty ? "未設定" : participantID)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("グループID")
                    Spacer()
                    Text(groupID.isEmpty ? "未設定" : groupID)
                        .foregroundColor(.secondary)
                }
                
                if consentGiven {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("研究参加に同意済み")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func vlmModelSection() -> some View {
        Section(header: Text("VLMモデル設定")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("使用するVLMモデル")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                vlmModelPicker()
                
                vlmModelStatus()
                
                vlmModelDescription()
            }
        }
    }
    
    @ViewBuilder
    private func vlmModelPicker() -> some View {
        let availableModels = getAvailableModels()
        if !availableModels.isEmpty {
            Picker("モデル選択", selection: Binding(
                get: { vlmManager.currentModel ?? availableModels.first! },
                set: { newValue in
                    Task {
                        try? await vlmManager.loadModel(newValue)
                    }
                }
            )) {
                ForEach(availableModels, id: \.id) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        } else {
            Text("利用可能なモデルがありません")
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func vlmModelStatus() -> some View {
        if vlmManager.currentModel == nil {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("モデルがロードされていません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("モデルロード済み")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    @ViewBuilder
    private func vlmModelDescription() -> some View {
        if let currentModel = vlmManager.currentModel {
            Text(getModelDescription(for: currentModel))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func getModelDescription(for model: VLMModel) -> String {
        // model.idからVLMModelTypeに変換して説明を取得
        if let modelType = VLMModelType(rawValue: model.id) {
            switch modelType {
            case .gemma3_4b_q4, .gemma3_4b_q8:
                return "Gemmaは高速で軽量なVLMモデルです"
            case .heron_nvila_2b:
                return "Heron NVILAは高精度なVLMモデルです"
            case .llava_v1_5_7b_q4, .llava_v1_5_7b_q8, .llava_v1_6_mistral_7b_q4:
                return "LLaVAは高性能なVLMモデルです"
            }
        } else {
            return model.description
        }
    }
    
    // 利用可能なVLMModelリストを取得
    private func getAvailableModels() -> [VLMModel] {
        return VLMModelType.allCases.map { modelType in
            VLMModel(
                id: modelType.rawValue,
                name: modelType.displayName,
                filename: modelType.filename,
                url: modelType.downloadURL,
                size: "", // サイズ情報は表示名に含まれている
                description: modelType.displayName,
                projectionModelURL: modelType.projectionModelURL,
                projectionModelFilename: modelType.projectionModelFilename
            )
        }
    }
    
    @ViewBuilder
    private func dataManagementSection() -> some View {
        Section(header: Text("データ管理")) {
            Button(action: { showingDataExport = true }) {
                Label("研究データをエクスポート", systemImage: "square.and.arrow.up")
            }
            .disabled(!isResearchMode)
            
            if consentGiven {
                Button(action: revokeConsent) {
                    Label("研究参加の同意を取り消す", systemImage: "xmark.circle")
                        .foregroundColor(.orange)
                }
            }
            
            Button(action: clearLocalData) {
                Label("ローカルデータをクリア", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    @ViewBuilder
    private func researchInfoSection() -> some View {
        Section(header: Text("研究について")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("研究目的")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("画像を活用した言語学習の効果測定")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("研究期間")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("2025年6月〜2026年3月")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showingConsentView = true }) {
                Label("同意書を確認", systemImage: "doc.text")
            }
        }
    }
    
    private func revokeConsent() {
        // 研究参加の同意を取り消す
        Task {
            if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
                do {
                    // UserProfileのconsentGivenをfalseに更新
                    var profile = try await DataPersistenceManager.shared.getUserProfile(participantID: userID)
                    profile?.consentGiven = false
                    if let profile = profile {
                        try await DataPersistenceManager.shared.saveUserProfile(profile)
                    }
                    
                    // UserDefaultsも更新
                    await MainActor.run {
                        consentGiven = false
                        UserDefaults.standard.set(false, forKey: "researchConsentGiven")
                    }
                    
                    print("[ResearchSettings] 研究参加の同意を取り消しました")
                } catch {
                    print("[ResearchSettings] 同意取り消しエラー: \(error)")
                }
            }
        }
    }
    
    private func clearLocalData() {
        // ローカルデータのクリア処理
        let alert = UIAlertController(
            title: "データクリアの確認",
            message: "ローカルに保存されたデータを削除しますか？この操作は取り消せません。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { _ in
            // データクリア処理
            UserDefaults.standard.removeObject(forKey: "participantID")
            UserDefaults.standard.removeObject(forKey: "groupID")
            UserDefaults.standard.removeObject(forKey: "researchConsentGiven")
            isResearchMode = false
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}

// データエクスポート画面
struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportComplete = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("研究データのエクスポート")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("学習履歴と統計データをJSON形式でエクスポートします")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isExporting {
                    ProgressView("エクスポート中...")
                        .padding()
                } else if exportComplete {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("エクスポート完了")
                            .foregroundColor(.green)
                    }
                    .padding()
                } else {
                    Button(action: exportData) {
                        Text("エクスポート開始")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationBarTitle("データエクスポート", displayMode: .inline)
            .navigationBarItems(trailing: Button("閉じる") { dismiss() })
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            // ReviewViewModelのエクスポート機能を使用
            let viewModel = ReviewViewModel()
            viewModel.loadReviewData()
            viewModel.exportReviewData()
            
            isExporting = false
            exportComplete = true
            
            // 2秒後に画面を閉じる
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }
}

#Preview {
    ResearchSettingsView()
}