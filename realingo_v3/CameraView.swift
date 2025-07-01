//
//  CameraView.swift
//  realingo_v3
//
//  カメラ撮影機能（即時モード）
//  参照: specification.md - 即時モード
//  関連: PhotoFetcher.swift, GeminiService.swift (画像から問題生成)
//

import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var generatedQuiz: ExtendedQuiz?
    @State private var errorMessage: String?
    @State private var showingProblemTypeSheet = false
    @State private var selectedProblemType: ProblemType = .wordArrangement
    @State private var showingPhotoDescription = false
    
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @Environment(\.dismiss) private var dismiss
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = capturedImage {
                    capturedImageView(image: image)
                } else {
                    cameraLaunchView
                }
                
                Spacer()
            }
            .navigationTitle(LocalizationHelper.getCommonText("immediateMode", for: nativeLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationHelper.getCommonText("cancel", for: nativeLanguage)) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPickerView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingPhotoDescription) {
                if let image = capturedImage {
                    PhotoDescriptionView(image: image)
                }
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
    
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        errorMessage = LocalizationHelper.getCommonText("cameraAccessDenied", for: nativeLanguage)
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = LocalizationHelper.getCommonText("allowCameraInSettings", for: nativeLanguage)
        @unknown default:
            errorMessage = LocalizationHelper.getCommonText("cannotCheckCameraAccess", for: nativeLanguage)
        }
    }
    
    private func generateProblem() {
        guard let image = capturedImage else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // 画像をCloudinaryにアップロード
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw CameraError.imageEncodingFailed
                }
                
                let cloudinaryURL = try await uploadToCloudinary(imageData: imageData)
                
                // ProblemGenerationServiceで問題生成（API/VLM自動選択）
                let quiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: cloudinaryURL,
                    language: selectedLanguage,
                    problemType: selectedProblemType,
                    nativeLanguage: nativeLanguage
                )
                
                // 生成された問題を保存
                try await DataPersistenceManager.shared.saveQuiz(quiz)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.generatedQuiz = quiz
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "\(LocalizationHelper.getCommonText("generating", for: self.nativeLanguage)) \(LocalizationHelper.getCommonText("error", for: self.nativeLanguage)): \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func uploadToCloudinary(imageData: Data) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            ServiceManager.shared.uploadToCloudinary(
                imageData: imageData,
                preset: "testtttt",
                cloudName: "dy53z9iup"
            ) { url in
                if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: CameraError.uploadFailed)
                }
            }
        }
    }
    
    private func getIcon(for type: ProblemType) -> String {
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
    
    // MARK: - View Components
    
    @ViewBuilder
    private func capturedImageView(image: UIImage) -> some View {
        VStack(spacing: 20) {
            // 撮影した画像のプレビュー
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // 問題タイプ選択
            problemTypeSelector
            
            // アクションボタン
            actionButtons
            
            if isProcessing {
                ProgressView(LocalizationHelper.getCommonText("generating", for: nativeLanguage))
                    .padding()
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
    }
    
    private var cameraLaunchView: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text(LocalizationHelper.getCommonText("takePhotoToCreateProblems", for: nativeLanguage))
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(LocalizationHelper.getCommonText("generateProblemsFromPhoto", for: nativeLanguage).replacingOccurrences(of: "{LANGUAGE}", with: selectedLanguage.displayName))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                checkCameraPermission()
            }) {
                Label(LocalizationHelper.getCommonText("launchCamera", for: nativeLanguage), systemImage: "camera")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
    
    private var problemTypeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizationHelper.getCommonText("selectProblemType", for: nativeLanguage))
                .font(.headline)
            
            ForEach(ProblemType.allCases, id: \.self) { type in
                problemTypeRow(for: type)
            }
        }
        .padding()
    }
    
    private func problemTypeRow(for type: ProblemType) -> some View {
        HStack {
            Image(systemName: getIcon(for: type))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(LocalizationHelper.getProblemTypeText(type, for: nativeLanguage))
            
            Spacer()
            
            if selectedProblemType == type {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(selectedProblemType == type ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onTapGesture {
            selectedProblemType = type
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                Button(LocalizationHelper.getCommonText("retake", for: nativeLanguage)) {
                    capturedImage = nil
                    showingCamera = true
                }
                .buttonStyle(.bordered)
                
                Button(LocalizationHelper.getCommonText("generateProblem", for: nativeLanguage)) {
                    generateProblem()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            
            // 写真の説明ボタン
            Button(action: {
                showingPhotoDescription = true
            }) {
                Label(LocalizationHelper.getCommonText("describePhotos", for: nativeLanguage), systemImage: "text.bubble")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Camera Picker
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
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
        let parent: CameraPickerView
        
        init(_ parent: CameraPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Errors
enum CameraError: LocalizedError {
    case imageEncodingFailed
    case uploadFailed
    
    var errorDescription: String? {
        // エラーメッセージは呼び出し元でローカライズする
        switch self {
        case .imageEncodingFailed:
            return "Image encoding failed"
        case .uploadFailed:
            return "Image upload failed"
        }
    }
}

#Preview {
    CameraView()
}