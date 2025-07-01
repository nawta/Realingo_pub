//
//  MainMenuView.swift
//  realingo_v3
//
//  メインメニュー画面 - 学習モードと設定へのアクセス
//  参照: specification.md - 回答方式の多様化、画像取得方式
//  関連: ContentView.swift, LanguageSelectionView.swift
//

import SwiftUI
import UniformTypeIdentifiers

struct MainMenuView: View {
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @AppStorage("isResearchMode") private var isResearchMode = false
    
    @State private var showLanguageSelection = false
    @State private var showResearchSettings = false
    @State private var showVLMModelManagement = false
    @State private var showVLMTest = false
    @State private var selectedProblemType: ProblemType?
    @State private var selectedImageMode: ImageMode = .immediate
    @State private var navigationPath = NavigationPath()
    @State private var showingCamera = false
    @State private var showingAPIKeySetup = false
    @State private var generatedQuiz: ExtendedQuiz?
    @State private var isGeneratingProblem = false
    @State private var errorMessage: String?
    @State private var showingProblemTypeSheet = false
    @State private var showingReminiscenceView = false
    @State private var showingPhotoDescription = false
    @State private var showingScriptInput = false
    @State private var scriptInputText = ""
    
    @StateObject private var apiKeyManager = APIKeyManager.shared
    @StateObject private var sharedImageHandler = SharedImageHandler.shared
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 20) {
                    // 言語表示と変更ボタン
                    HStack {
                        VStack(alignment: .leading) {
                            Text(LocalizationHelper.getCommonText("learningLanguage", for: nativeLanguage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(selectedLanguage.flag)
                                Text(selectedLanguage.displayName)
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showLanguageSelection = true
                        }) {
                            Text(LocalizationHelper.getCommonText("change", for: nativeLanguage))
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(15)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // 学習モード
                    VStack(alignment: .leading, spacing: 15) {
                        Text(LocalizationHelper.getCommonText("learningModes", for: nativeLanguage))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            // カメラで撮影
                            ModeButton(
                                title: LocalizationHelper.getCommonText("cameraMode", for: nativeLanguage),
                                subtitle: LocalizationHelper.getCommonText("createProblemsFromPhotos", for: nativeLanguage),
                                icon: "camera.fill",
                                action: {
                                    showingCamera = true
                                }
                            )
                            
                            // 思い出と学習
                            ModeButton(
                                title: LocalizationHelper.getCommonText("memoriesLearning", for: nativeLanguage),
                                subtitle: LocalizationHelper.getCommonText("generateFromPastPhotos", for: nativeLanguage),
                                icon: "photo.on.rectangle.angled",
                                action: {
                                    showingReminiscenceView = true
                                }
                            )
                            
                            // みんなの写真
                            NavigationLink(destination: CommunityPhotosView()) {
                                ModeButtonView(
                                    title: LocalizationHelper.getCommonText("everyonesPhotos", for: nativeLanguage),
                                    subtitle: LocalizationHelper.getCommonText("learnFromCommunityPhotos", for: nativeLanguage),
                                    icon: "person.3.fill",
                                    color: .orange
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 音声入力モード
                            NavigationLink(destination: AudioInputView()) {
                                ModeButtonView(
                                    title: LocalizationHelper.getCommonText("audioInputMode", for: nativeLanguage),
                                    subtitle: LocalizationHelper.getCommonText("audioInputDescription", for: nativeLanguage),
                                    icon: "mic.circle.fill",
                                    color: .red
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // スクリプトモード
                            Button(action: {
                                showingScriptInput = true
                            }) {
                                ModeButtonView(
                                    title: LocalizationHelper.getCommonText("scriptMode", for: nativeLanguage),
                                    subtitle: LocalizationHelper.getCommonText("scriptModeDescription", for: nativeLanguage),
                                    icon: "doc.text.fill",
                                    color: .indigo
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(10)
                    }
                    
                    // 出題形式別
                    VStack(alignment: .leading, spacing: 15) {
                        Text(LocalizationHelper.getCommonText("problemFormats", for: nativeLanguage))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            ForEach(ProblemType.allCases, id: \.self) { problemType in
                                ModeButton(
                                    title: LocalizationHelper.getProblemTypeText(problemType, for: nativeLanguage),
                                    subtitle: LocalizationHelper.getProblemTypeDescription(problemType, for: nativeLanguage),
                                    icon: getModeIcon(problemType),
                                    action: {
                                        selectedProblemType = problemType
                                        selectedImageMode = .immediate
                                        showingProblemTypeSheet = true
                                    }
                                )
                            }
                            
                            // 写真の説明
                            ModeButton(
                                title: LocalizationHelper.getCommonText("photoDescription", for: nativeLanguage),
                                subtitle: LocalizationHelper.getCommonText("photoDescriptionSubtitle", for: nativeLanguage),
                                icon: "photo.badge.magnifyingglass",
                                action: {
                                    showingPhotoDescription = true
                                }
                            )
                        }
                        .padding()
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(10)
                    }
                    
                    // 設定ボタン（第1行）
                    HStack(spacing: 15) {
                        Button(action: {
                            showResearchSettings = true
                        }) {
                            Label(LocalizationHelper.getCommonText("researchSettings", for: nativeLanguage), systemImage: "flask")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        NavigationLink(destination: VLMSettingsView()) {
                            Label("AI設定", systemImage: "cpu")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showVLMModelManagement = true
                        }) {
                            Label("VLMモデル", systemImage: "square.and.arrow.down")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    // 設定ボタン（第2行）
                    HStack(spacing: 15) {
                        NavigationLink(destination: KPIDashboardView()) {
                            Label(LocalizationHelper.getCommonText("learningAnalytics", for: nativeLanguage), systemImage: "chart.xyaxis.line")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            showVLMTest = true
                        }) {
                            Label("VLMテスト", systemImage: "testtube.2")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.mint.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        NavigationLink(destination: ReviewView()) {
                            Label(LocalizationHelper.getCommonText("learningHistory", for: nativeLanguage), systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    // 設定ボタン（第3行）
                    HStack(spacing: 15) {
                        NavigationLink(destination: MyPhotosView()) {
                            Label(LocalizationHelper.getCommonText("myPhotos", for: nativeLanguage), systemImage: "photo.on.rectangle")
                                .font(.caption)
                                .padding(10)
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Realingo")
            .navigationDestination(item: $generatedQuiz) { quiz in
                // 生成された問題に応じた画面に遷移
                switch quiz.problemType {
                case .wordArrangement:
                    ContentView(quiz: quiz)
                case .fillInTheBlank:
                    FillInTheBlankView(quiz: quiz)
                case .speaking:
                    SpeakingPracticeView(quiz: quiz)
                case .writing:
                    WritingPracticeView(quiz: quiz)
                }
            }
            .sheet(isPresented: $showLanguageSelection) {
                LanguageSelectionView(showLanguageSelection: $showLanguageSelection)
            }
            .sheet(isPresented: $showResearchSettings) {
                ResearchSettingsView()
            }
            .sheet(isPresented: $showVLMModelManagement) {
                VLMModelManagementView()
            }
            .sheet(isPresented: $showVLMTest) {
                VLMTestView()
            }
            .sheet(isPresented: $showingCamera) {
                CameraView()
            }
            .sheet(isPresented: $showingAPIKeySetup) {
                APIKeySetupView()
            }
            .sheet(isPresented: $showingProblemTypeSheet) {
                ProblemGenerationSheet(
                    problemType: selectedProblemType ?? .wordArrangement,
                    imageMode: selectedImageMode,
                    isGenerating: $isGeneratingProblem,
                    onGenerate: { imageUrl in
                        generateProblem(imageUrl: imageUrl)
                    },
                    onCancel: {
                        showingProblemTypeSheet = false
                        selectedProblemType = nil
                    }
                )
            }
            .alert(LocalizationHelper.getCommonText("error", for: nativeLanguage), isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingReminiscenceView) {
                NavigationView {
                    ReminiscenceView()
                        .navigationBarItems(
                            trailing: Button(LocalizationHelper.getCommonText("close", for: nativeLanguage)) {
                                showingReminiscenceView = false
                            }
                        )
                }
            }
            .sheet(isPresented: $showingPhotoDescription) {
                PhotoDescriptionView(imageSource: .library)
            }
            .sheet(isPresented: $showingScriptInput) {
                ScriptInputSheet(
                    scriptText: $scriptInputText,
                    isPresented: $showingScriptInput,
                    onSubmit: {
                        // スクリプトモードに遷移
                        navigationPath.append(ScriptDestination(text: scriptInputText))
                        scriptInputText = ""
                    }
                )
            }
            .navigationDestination(for: ScriptDestination.self) { destination in
                ScriptModeView(scriptText: destination.text, sourceType: .text)
            }
            .onAppear {
                // APIキーの初期設定が必要か確認
                if apiKeyManager.needsAPIKeySetup {
                    showingAPIKeySetup = true
                }
                
                // Share Extensionから共有された画像をチェック
                sharedImageHandler.checkForSharedImages()
                if sharedImageHandler.hasSharedImages {
                    // 共有画像処理画面に遷移
                    navigationPath.append(SharedImageDestination())
                }
            }
            .navigationDestination(for: SharedImageDestination.self) { _ in
                SharedImageProcessingView(
                    images: sharedImageHandler.sharedImages,
                    navigationPath: $navigationPath
                )
            }
        }
    }
    
    
    private func getModeIcon(_ type: ProblemType) -> String {
        switch type {
        case .wordArrangement:
            return "arrow.left.arrow.right"
        case .fillInTheBlank:
            return "square.and.pencil"
        case .speaking:
            return "mic.fill"
        case .writing:
            return "pencil.and.scribble"
        }
    }
    
    private func generateProblem(imageUrl: String?) {
        guard let problemType = selectedProblemType else { return }
        
        isGeneratingProblem = true
        errorMessage = nil
        
        Task {
            do {
                var finalImageUrl: String
                
                // みんなの写真モードの場合
                if selectedImageMode == .random {
                    // Firestoreからランダムな画像を取得
                    if let randomUrl = try await DataPersistenceManager.shared.getRandomImageURL() {
                        finalImageUrl = randomUrl
                    } else {
                        // 画像が見つからない場合はデフォルト画像を使用
                        finalImageUrl = "https://picsum.photos/400/300"
                    }
                } else {
                    // 通常モード（デフォルトの画像を使用）
                    finalImageUrl = imageUrl ?? "https://picsum.photos/400/300"
                }
                
                // ProblemGenerationServiceで問題生成（API/VLM自動選択）
                let quiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: finalImageUrl,
                    language: selectedLanguage,
                    problemType: problemType,
                    nativeLanguage: nativeLanguage
                )
                
                // 問題を保存
                try await DataPersistenceManager.shared.saveQuiz(quiz)
                
                DispatchQueue.main.async {
                    self.isGeneratingProblem = false
                    self.showingProblemTypeSheet = false
                    self.generatedQuiz = quiz
                    self.selectedProblemType = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.isGeneratingProblem = false
                    self.errorMessage = "\(LocalizationHelper.getCommonText("generating", for: self.nativeLanguage)) \(LocalizationHelper.getCommonText("error", for: self.nativeLanguage)): \(error.localizedDescription)"
                }
            }
        }
    }
}

// 問題生成シート
struct ProblemGenerationSheet: View {
    let problemType: ProblemType
    let imageMode: ImageMode
    @Binding var isGenerating: Bool
    let onGenerate: (String?) -> Void
    let onCancel: () -> Void
    
    @State private var useCustomImage = false
    @State private var customImageUrl = ""
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("\(problemType.displayName)\(LocalizationHelper.getCommonText("generateProblemType", for: nativeLanguage))")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 10) {
                    if imageMode == .random {
                        // みんなの写真モードの場合はランダム画像を使用
                        Text(LocalizationHelper.getCommonText("randomImageWillBeUsed", for: nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Toggle(LocalizationHelper.getCommonText("useCustomImage", for: nativeLanguage), isOn: $useCustomImage)
                        
                        if useCustomImage {
                            TextField(LocalizationHelper.getCommonText("imageUrl", for: nativeLanguage), text: $customImageUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            Text(LocalizationHelper.getCommonText("randomImageWillBeUsed", for: nativeLanguage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                if isGenerating {
                    ProgressView(LocalizationHelper.getCommonText("generating", for: nativeLanguage))
                        .padding()
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button(LocalizationHelper.getCommonText("cancel", for: nativeLanguage)) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(LocalizationHelper.getProblemGenerationText("startGeneration", for: nativeLanguage)) {
                        let imageUrl: String?
                        if imageMode == .random {
                            // みんなの写真モードは常にランダム画像を使用
                            imageUrl = nil
                        } else {
                            imageUrl = useCustomImage && !customImageUrl.isEmpty ? customImageUrl : nil
                        }
                        onGenerate(imageUrl)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || (useCustomImage && customImageUrl.isEmpty && imageMode != .random))
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModeButtonView: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// スクリプトモードへの遷移用構造体
struct ScriptDestination: Hashable {
    let text: String
}

// 共有画像処理への遷移用構造体
struct SharedImageDestination: Hashable {}

// スクリプト入力シート
struct ScriptInputSheet: View {
    @Binding var scriptText: String
    @Binding var isPresented: Bool
    let onSubmit: () -> Void
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    @State private var showingDocumentPicker = false
    @State private var errorMessage: String?
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizationHelper.getCommonText("enterScriptText", for: nativeLanguage))
                    .font(.headline)
                
                TextEditor(text: $scriptText)
                    .font(.body)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .frame(minHeight: 200)
                
                // ファイルアップロードボタン
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Label(LocalizationHelper.getCommonText("uploadTextFile", for: nativeLanguage), systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Text(LocalizationHelper.getCommonText("scriptInputHint", for: nativeLanguage))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle(LocalizationHelper.getCommonText("scriptMode", for: nativeLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationHelper.getCommonText("cancel", for: nativeLanguage)) {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationHelper.getCommonText("start", for: nativeLanguage)) {
                        if !scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSubmit()
                            isPresented = false
                        }
                    }
                    .disabled(scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        do {
                            // ファイルへのアクセス権を取得
                            if url.startAccessingSecurityScopedResource() {
                                defer { url.stopAccessingSecurityScopedResource() }
                                
                                // ファイルの内容を読み込む
                                let content = try String(contentsOf: url, encoding: .utf8)
                                scriptText = content
                                errorMessage = nil
                            }
                        } catch {
                            errorMessage = LocalizationHelper.getCommonText("fileReadError", for: nativeLanguage) + ": \(error.localizedDescription)"
                        }
                    }
                case .failure(let error):
                    errorMessage = LocalizationHelper.getCommonText("fileImportError", for: nativeLanguage) + ": \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    MainMenuView()
}