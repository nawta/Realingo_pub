//
//  PhotoDescriptionView.swift
//  realingo_v3
//
//  写真の説明モード - 画像の情景を詳しく説明し、音声で読み上げる
//  参照: specification.md - 新しい学習モード
//  関連: TTSManager.swift, GeminiService.swift
//

import SwiftUI
import PhotosUI

struct PhotoDescriptionView: View {
    let imageSource: ImageSource
    
    @State private var selectedImage: UIImage?
    @State private var imageURL: String?
    @State private var isGenerating = false
    @State private var descriptions: [LanguageDescription] = []
    @State private var errorMessage: String?
    @State private var selectedDescriptionIndex = 0
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    @StateObject private var ttsManager = TTSManager.shared
    @Environment(\.dismiss) private var dismiss
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    enum ImageSource {
        case camera
        case library
        case url(String)
        case reminiscence(UIImage)
    }
    
    struct LanguageDescription {
        let language: SupportedLanguage
        let description: String
        let translation: String?
    }
    
    // カメラ撮影後の画像を直接受け取るためのイニシャライザ
    init(image: UIImage) {
        self.imageSource = .reminiscence(image)
        self._selectedImage = State(initialValue: image)
    }
    
    // 既存のイニシャライザ
    init(imageSource: ImageSource) {
        self.imageSource = imageSource
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isGenerating {
                    ProgressView("画像を分析中...")
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                } else if !descriptions.isEmpty {
                    descriptionView
                } else {
                    imageSelectionView
                }
            }
            .navigationTitle("写真の説明モード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                if !descriptions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("新しい画像") {
                            resetView()
                        }
                    }
                }
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .sheet(isPresented: $showingCamera) {
                // CameraViewから必要な部分を持ってくる
                CameraPickerWrapper(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if newValue != nil {
                    generateDescriptions()
                }
            }
            .onAppear {
                setupInitialImage()
            }
        }
    }
    
    private var imageSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("画像を選択してください")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button(action: {
                    showingCamera = true
                }) {
                    Label("写真を撮る", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    Label("ライブラリから選択", systemImage: "photo.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
    
    private var descriptionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 画像表示
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                } else if let urlString = imageURL,
                          let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    } placeholder: {
                        ProgressView()
                            .frame(height: 300)
                    }
                }
                
                // 言語選択タブ
                if descriptions.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(descriptions.indices, id: \.self) { index in
                                languageTab(for: index)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 説明文表示
                if selectedDescriptionIndex < descriptions.count {
                    let description = descriptions[selectedDescriptionIndex]
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 学習言語での説明
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(description.language.flag)
                                Text(description.language.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // 音声再生ボタン
                                Button(action: {
                                    speakDescription(description)
                                }) {
                                    Image(systemName: ttsManager.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Text(description.description)
                                .font(.body)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        // 翻訳（母国語）
                        if let translation = description.translation {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(nativeLanguage.flag)
                                    Text("翻訳")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(translation)
                                    .font(.body)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                        
                        // アクションボタン
                        HStack(spacing: 12) {
                            Button(action: {
                                copyToClipboard(description.description)
                            }) {
                                Label("コピー", systemImage: "doc.on.doc")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                shareDescription(description)
                            }) {
                                Label("共有", systemImage: "square.and.arrow.up")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
                
                // 学習モードへの転換ボタン
                VStack(spacing: 12) {
                    Text("この画像で問題を作成")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(ProblemType.allCases, id: \.self) { problemType in
                            Button(action: {
                                createProblem(type: problemType)
                            }) {
                                Text(LocalizationHelper.getProblemTypeText(problemType, for: nativeLanguage))
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.05))
                .cornerRadius(10)
                .padding()
            }
        }
    }
    
    private func languageTab(for index: Int) -> some View {
        let isSelected = selectedDescriptionIndex == index
        let language = descriptions[index].language
        
        return Button(action: {
            selectedDescriptionIndex = index
            // 言語を切り替えたら音声を停止
            ttsManager.stopSpeaking()
        }) {
            HStack {
                Text(language.flag)
                Text(language.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
    
    private func setupInitialImage() {
        switch imageSource {
        case .camera:
            showingCamera = true
        case .library:
            showingImagePicker = true
        case .url(let url):
            imageURL = url
            generateDescriptions()
        case .reminiscence(let image):
            selectedImage = image
            generateDescriptions()
        }
    }
    
    private func generateDescriptions() {
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                var generatedDescriptions: [LanguageDescription] = []
                
                // 学習言語での説明を生成
                let learningDescription = try await generateDescription(
                    for: selectedLanguage,
                    includeTranslation: true
                )
                generatedDescriptions.append(learningDescription)
                
                // 必要に応じて他の言語での説明も生成（将来的な拡張用）
                // 例: 英語での説明も追加
                if selectedLanguage != .english {
                    let englishDescription = try await generateDescription(
                        for: .english,
                        includeTranslation: false
                    )
                    generatedDescriptions.append(englishDescription)
                }
                
                await MainActor.run {
                    self.descriptions = generatedDescriptions
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "説明の生成に失敗しました: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func generateDescription(
        for language: SupportedLanguage,
        includeTranslation: Bool
    ) async throws -> LanguageDescription {
        let prompt = createDescriptionPrompt(for: language, includeTranslation: includeTranslation)
        
        // 画像データまたはURLを使用してGemini APIを呼び出す
        let response: String
        if let image = selectedImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            // 画像データから生成
            response = try await ProblemGenerationService.shared.generateImageDescription(
                imageData: imageData,
                prompt: prompt,
                language: language
            )
        } else if let url = imageURL {
            // URLから生成
            // URLから画像データを取得してgenerateImageDescriptionを使用
            guard let url = URL(string: url) else {
                throw PhotoDescriptionError.networkError
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            response = try await ProblemGenerationService.shared.generateImageDescription(
                imageData: data,
                prompt: prompt,
                language: language
            )
        } else {
            throw PhotoDescriptionError.noImageAvailable
        }
        
        // レスポンスを解析
        let parsed = parseDescriptionResponse(response, language: language)
        return parsed
    }
    
    private func createDescriptionPrompt(
        for language: SupportedLanguage,
        includeTranslation: Bool
    ) -> String {
        let languageName = language.displayName
        let nativeLanguageName = nativeLanguage.displayName
        
        var prompt = """
        この画像を見て、\(languageName)で詳細な説明文を作成してください。
        
        要件：
        1. 画像に写っているものを具体的に描写
        2. 色、形、位置関係、雰囲気などを含める
        3. 3-5文程度の自然な文章
        4. 学習者向けの分かりやすい表現
        """
        
        if includeTranslation {
            prompt += """
            
            以下のJSON形式で回答してください：
            {
                "description": "\(languageName)での説明文",
                "translation": "\(nativeLanguageName)での翻訳"
            }
            """
        } else {
            prompt += """
            
            以下のJSON形式で回答してください：
            {
                "description": "\(languageName)での説明文"
            }
            """
        }
        
        return prompt
    }
    
    private func parseDescriptionResponse(
        _ response: String,
        language: SupportedLanguage
    ) -> LanguageDescription {
        // JSON形式のレスポンスをパース
        if let data = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let description = json["description"] as? String {
            let translation = json["translation"] as? String
            return LanguageDescription(
                language: language,
                description: description,
                translation: translation
            )
        } else {
            // パースに失敗した場合はレスポンス全体を説明として使用
            return LanguageDescription(
                language: language,
                description: response,
                translation: nil
            )
        }
    }
    
    private func speakDescription(_ description: LanguageDescription) {
        if ttsManager.isSpeaking {
            ttsManager.stopSpeaking()
        } else {
            ttsManager.speak(
                text: description.description,
                language: description.language
            )
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        // フィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func shareDescription(_ description: LanguageDescription) {
        var shareText = "\(description.language.flag) \(description.language.displayName):\n\(description.description)"
        if let translation = description.translation {
            shareText += "\n\n\(nativeLanguage.flag) 翻訳:\n\(translation)"
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func createProblem(type: ProblemType) {
        // 問題作成画面への遷移
        // TODO: 実装
    }
    
    private func resetView() {
        selectedImage = nil
        imageURL = nil
        descriptions = []
        selectedDescriptionIndex = 0
        ttsManager.stopSpeaking()
    }
}

enum PhotoDescriptionError: LocalizedError {
    case noImageAvailable
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noImageAvailable:
            return "画像が選択されていません"
        case .networkError:
            return "ネットワークエラーが発生しました"
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                if let image = image as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image
                    }
                }
            }
        }
    }
}

// MARK: - Camera Picker Wrapper

struct CameraPickerWrapper: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerWrapper
        
        init(_ parent: CameraPickerWrapper) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    PhotoDescriptionView(imageSource: .library)
}