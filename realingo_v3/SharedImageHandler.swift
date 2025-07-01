//
//  SharedImageHandler.swift
//  realingo_v3
//
//  Share Extensionから受け取った画像を処理
//  参照: specification.md - 他アプリから自分のアプリへ画像を渡したい
//  関連: ShareViewController.swift, MainMenuView.swift
//

import Foundation
import UIKit
import SwiftUI

class SharedImageHandler: ObservableObject {
    static let shared = SharedImageHandler()
    
    @Published var hasSharedImages = false
    @Published var sharedImages: [UIImage] = []
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.realingo.shared")
    private let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.realingo.shared")
    
    private init() {
        checkForSharedImages()
    }
    
    /// Share Extensionから共有された画像をチェック
    func checkForSharedImages() {
        guard let hasNewImages = sharedDefaults?.bool(forKey: "hasNewSharedImages"),
              hasNewImages else {
            return
        }
        
        loadSharedImages()
    }
    
    /// 共有された画像を読み込む
    private func loadSharedImages() {
        guard let imagePaths = sharedDefaults?.stringArray(forKey: "pendingSharedImages"),
              !imagePaths.isEmpty else {
            return
        }
        
        var loadedImages: [UIImage] = []
        
        for path in imagePaths {
            let fileURL = URL(fileURLWithPath: path)
            
            if FileManager.default.fileExists(atPath: path),
               let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                loadedImages.append(image)
                
                // 読み込み後にファイルを削除（一時ファイルなので）
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        
        DispatchQueue.main.async {
            self.sharedImages = loadedImages
            self.hasSharedImages = !loadedImages.isEmpty
            
            // 処理済みフラグをクリア
            self.sharedDefaults?.set(false, forKey: "hasNewSharedImages")
            self.sharedDefaults?.removeObject(forKey: "pendingSharedImages")
        }
    }
    
    /// 共有画像をクリア
    func clearSharedImages() {
        sharedImages = []
        hasSharedImages = false
    }
    
    /// 直接共有された画像を追加（onOpenURL経由）
    func handleSharedImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.sharedImages.append(image)
            self.hasSharedImages = true
        }
    }
    
    /// 共有画像から問題を生成するためのビューを表示
    func presentSharedImageView(from navigationPath: Binding<NavigationPath>) -> some View {
        SharedImageProcessingView(images: sharedImages, navigationPath: navigationPath)
    }
}

// MARK: - 共有画像処理ビュー

struct SharedImageProcessingView: View {
    let images: [UIImage]
    @Binding var navigationPath: NavigationPath
    
    @State private var selectedImageIndex = 0
    @State private var selectedProblemType: ProblemType = .wordArrangement
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var generatedQuiz: ExtendedQuiz?
    
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !images.isEmpty {
                    // 画像プレビュー
                    TabView(selection: $selectedImageIndex) {
                        ForEach(0..<images.count, id: \.self) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .frame(height: 300)
                    
                    // 問題タイプ選択
                    VStack(alignment: .leading) {
                        Text(LocalizationHelper.getCommonText("selectProblemType", for: nativeLanguage))
                            .font(.headline)
                        
                        Picker("", selection: $selectedProblemType) {
                            ForEach(ProblemType.allCases, id: \.self) { type in
                                Text(LocalizationHelper.getProblemTypeText(type, for: nativeLanguage))
                                    .tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding()
                    
                    // 生成ボタン
                    Button(action: generateProblem) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(LocalizationHelper.getProblemGenerationText("startGeneration", for: nativeLanguage))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                    
                    Spacer()
                } else {
                    Text(LocalizationHelper.getCommonText("noSharedImages", for: nativeLanguage))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle(LocalizationHelper.getCommonText("sharedImages", for: nativeLanguage))
            .navigationBarItems(
                trailing: Button(LocalizationHelper.getCommonText("close", for: nativeLanguage)) {
                    SharedImageHandler.shared.clearSharedImages()
                    navigationPath.removeLast()
                }
            )
            .alert(LocalizationHelper.getCommonText("error", for: nativeLanguage), isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
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
        }
    }
    
    private func generateProblem() {
        guard selectedImageIndex < images.count else { return }
        
        let selectedImage = images[selectedImageIndex]
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                // 画像をCloudinaryにアップロード
                let imageUrl = try await uploadImageToCloudinary(selectedImage)
                
                // 問題生成
                let quiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: imageUrl,
                    language: selectedLanguage,
                    problemType: selectedProblemType,
                    nativeLanguage: nativeLanguage
                )
                
                // 問題を保存
                try await DataPersistenceManager.shared.saveQuiz(quiz)
                
                DispatchQueue.main.async {
                    self.isGenerating = false
                    self.generatedQuiz = quiz
                    SharedImageHandler.shared.clearSharedImages()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func uploadImageToCloudinary(_ image: UIImage) async throws -> String {
        // UIImageをDataに変換
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "SharedImageHandler", code: 0, userInfo: [NSLocalizedDescriptionKey: "画像のデータ変換に失敗しました"])
        }
        
        // ServiceManagerのuploadToCloudinaryを使用
        return try await withCheckedThrowingContinuation { continuation in
            ServiceManager.shared.uploadToCloudinary(
                imageData: imageData,
                preset: "ml_default",
                cloudName: "dy53z9iup"
            ) { url in
                if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "SharedImageHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "画像のアップロードに失敗しました"]))
                }
            }
        }
    }
}