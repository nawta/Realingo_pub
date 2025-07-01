//
//  PhotoUploadButton.swift
//  realingo_v3
//
//  写真をFirebase Storageにアップロードするボタンコンポーネント
//  参照: specification.md - 写真のアップロードの実装
//  関連: WritingPracticeView.swift, SpeakingPracticeView.swift, FirebaseStorageService.swift
//

import SwiftUI

struct PhotoUploadButton: View {
    let quiz: ExtendedQuiz
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var showShareOptions = false
    @State private var errorMessage: String?
    
    @AppStorage("userID") private var userID = UUID().uuidString
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        if let imageUrl = quiz.imageUrl, !uploadSuccess {
            // 全ての画像でアップロードボタンを表示（Firebase Storageにアップロード）
            HStack {
                    Spacer()
                    
                    Button(action: {
                        if !isUploading {
                            showShareOptions = true
                        }
                    }) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: uploadSuccess ? "checkmark.icloud" : "icloud.and.arrow.up")
                            }
                            
                            Text(uploadSuccess 
                                ? LocalizationHelper.getCommonText("uploadComplete", for: nativeLanguage)
                                : LocalizationHelper.getCommonText("uploadPhoto", for: nativeLanguage)
                            )
                            .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(uploadSuccess ? Color.gray : Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isUploading || uploadSuccess)
                }
                .padding(.horizontal)
                .alert(LocalizationHelper.getCommonText("uploadError", for: nativeLanguage), isPresented: .constant(errorMessage != nil)) {
                    Button("OK") {
                        errorMessage = nil
                    }
                } message: {
                    Text(errorMessage ?? "")
                }
                .confirmationDialog(
                    LocalizationHelper.getCommonText("uploadPhotoTitle", for: nativeLanguage),
                    isPresented: $showShareOptions,
                    titleVisibility: .visible
                ) {
                    Button(LocalizationHelper.getCommonText("uploadPrivate", for: nativeLanguage)) {
                        Task {
                            await uploadImage(isPublic: false)
                        }
                    }
                    
                    Button(LocalizationHelper.getCommonText("uploadPublic", for: nativeLanguage)) {
                        Task {
                            await uploadImage(isPublic: true)
                        }
                    }
                    
                    Button(LocalizationHelper.getCommonText("cancel", for: nativeLanguage), role: .cancel) {}
                } message: {
                    Text(LocalizationHelper.getCommonText("uploadPhotoDescription", for: nativeLanguage))
                }
        }
    }
    
    private func uploadImage(isPublic: Bool) async {
        // 重複アップロード防止
        guard !isUploading && !uploadSuccess else {
            print("[PhotoUploadButton] Upload already in progress or completed, skipping")
            return
        }
        
        guard let imageUrlString = quiz.imageUrl else {
            errorMessage = LocalizationHelper.getCommonText("invalidImageUrl", for: nativeLanguage)
            return
        }
        
        print("[PhotoUploadButton] Starting upload process...")
        isUploading = true
        errorMessage = nil
        
        do {
            let image: UIImage
            
            if imageUrlString.hasPrefix("file://") {
                // ローカル画像の場合
                let localPath = String(imageUrlString.dropFirst(7)) // "file://" を除去
                guard let localImage = ReminiscenceManager.shared.loadLocalImage(path: localPath) else {
                    throw FirebaseStorageError.imageConversionFailed
                }
                image = localImage
            } else {
                // リモート画像の場合
                guard let imageUrl = URL(string: imageUrlString) else {
                    errorMessage = LocalizationHelper.getCommonText("invalidImageUrl", for: nativeLanguage)
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: imageUrl)
                guard let downloadedImage = UIImage(data: data) else {
                    throw FirebaseStorageError.imageConversionFailed
                }
                image = downloadedImage
            }
            
            // Firebase Storageにアップロード
            print("[PhotoUploadButton] Starting Firebase Storage upload...")
            let uploadResult = try await FirebaseStorageService.shared.uploadImage(
                image,
                problemID: quiz.problemID,
                userID: userID,
                isPublic: isPublic
            )
            
            print("[PhotoUploadButton] Upload successful - URL: \(uploadResult.url)")
            print("[PhotoUploadButton] PhotoID: \(uploadResult.photoID)")
            if isPublic {
                print("[PhotoUploadButton] 写真を公開設定でアップロードしました")
            }
            
            await MainActor.run {
                self.isUploading = false
                self.uploadSuccess = true
            }
            
            // 成功をユーザーに通知
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } catch {
            print("[PhotoUploadButton] Upload failed with error: \(error)")
            print("[PhotoUploadButton] Error type: \(type(of: error))")
            
            await MainActor.run {
                self.isUploading = false
                // エラーマスキングを一時的に無効化してデバッグ
                print("[PhotoUploadButton] UPLOAD FAILED - showing actual error to user")
                print("[PhotoUploadButton] Error details: \(error)")
                self.errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PhotoUploadButton(quiz: ExtendedQuiz(
            problemID: "test-123",
            language: .finnish,
            problemType: .writing,
            imageMode: .immediate,
            question: "Test question",
            answer: "Test answer",
            imageUrl: "https://picsum.photos/400/300",
            audioUrl: nil,
            options: [],
            blankPositions: nil,
            hints: nil,
            difficulty: 3,
            tags: nil,
            explanation: nil,
            metadata: nil,
            createdByGroup: "preview",
            createdByParticipant: "preview-user",
            createdAt: Date(),
            vlmGenerated: false,
            vlmModel: nil,
            notified: nil,
            communityPhotoID: nil
        ))
    }
    .padding()
}