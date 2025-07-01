//
//  ResultModalView.swift
//  realingo_v3
//
//  回答結果を表示するモーダルビュー
//

import SwiftUI

struct ResultModalView: View {
    let isCorrect: Bool
    let correctAnswer: String
    let userAnswer: String
    let nativeLanguage: SupportedLanguage
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 結果アイコン
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(isCorrect ? .green : .red)
            
            // 結果テキスト
            Text(isCorrect ? LocalizationHelper.getCommonText("correct", for: nativeLanguage) : LocalizationHelper.getCommonText("incorrect", for: nativeLanguage))
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 回答内容
            if !isCorrect {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(LocalizationHelper.getCommonText("yourAnswer", for: nativeLanguage) + ":")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    Text(userAnswer)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    
                    HStack {
                        Text(LocalizationHelper.getCommonText("correctAnswer", for: nativeLanguage) + ":")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    Text(correctAnswer)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            // 次へボタン
            Button(action: onDismiss) {
                Text(LocalizationHelper.getCommonText("next", for: nativeLanguage))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct UploadModalView: View {
    let imageUrl: String
    let nativeLanguage: SupportedLanguage
    let onDismiss: () -> Void
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false
    
    var body: some View {
        VStack(spacing: 20) {
            // アップロードアイコン
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("「みんなの写真」に投稿")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Firebase Storageへアップロード")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 画像URL表示
//            VStack(alignment: .leading, spacing: 5) {
//                Text("画像URL:")
//                    .font(.caption)
//                    .fontWeight(.semibold)
//                Text(imageUrl)
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//                    .lineLimit(3)
//                    .padding()
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .background(Color.gray.opacity(0.1))
//                    .cornerRadius(8)
//            }
//            .padding(.horizontal)
            
            if isUploading {
                // プログレスバー
                VStack(spacing: 10) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("\(Int(uploadProgress * 100))%")
                        .font(.caption)
                }
                .padding(.horizontal)
            }
            
            // ボタン
            HStack(spacing: 15) {
                Button(action: onDismiss) {
                    Text(LocalizationHelper.getCommonText("cancel", for: nativeLanguage))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // モックアップロード処理
                    mockUpload()
                }) {
                    Text("アップロード")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isUploading)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    private func mockUpload() {
        isUploading = true
        uploadProgress = 0
        
        // モックアップロードのシミュレーション
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            uploadProgress += 0.1
            
            if uploadProgress >= 1.0 {
                timer.invalidate()
                isUploading = false
                
                // アップロード完了後に閉じる
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onDismiss()
                }
            }
        }
    }
}
