//
//  MyPhotosView.swift
//  realingo_v3
//
//  自分がアップロードした写真と感想を表示
//  参照: specification.md - みんなの写真モードの実装
//  関連: FirebaseStorageService.swift, CommunityPhotosView.swift
//

import SwiftUI
import FirebaseFirestore

struct MyPhotosView: View {
    @StateObject private var viewModel = MyPhotosViewModel()
    @State private var selectedPhoto: CommunityPhoto?
    @State private var showingComments = false
    
    @AppStorage("userID") private var userID = UUID().uuidString
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.photos.isEmpty {
                    ProgressView(LocalizationHelper.getCommonText("loading", for: nativeLanguage))
                        .padding()
                } else if viewModel.photos.isEmpty {
                    emptyStateView
                } else {
                    photosGrid
                }
            }
            .navigationTitle(LocalizationHelper.getCommonText("myPhotos", for: nativeLanguage))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // 写真アップロードボタン
                        NavigationLink(destination: CameraView()) {
                            Image(systemName: "camera.fill")
                        }
                        
                        // 更新ボタン
                        Button(action: {
                            Task {
                                await viewModel.refreshPhotos()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoCommentsView(photo: photo)
            }
        }
        .task {
            await viewModel.loadUserPhotos(userID: userID)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(LocalizationHelper.getCommonText("noUploadedPhotos", for: nativeLanguage))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(LocalizationHelper.getCommonText("uploadPhotosDescription", for: nativeLanguage))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // アップロードボタン
            NavigationLink(destination: CameraView()) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text(LocalizationHelper.getCommonText("takePhoto", for: nativeLanguage))
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(.vertical, 100)
    }
    
    private var photosGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 15) {
            ForEach(viewModel.photos) { photo in
                MyPhotoCard(
                    photo: photo,
                    commentsCount: viewModel.commentsCount[photo.id ?? ""] ?? 0,
                    onTap: {
                        selectedPhoto = photo
                    }
                )
            }
        }
        .padding()
    }
}

// MARK: - ViewModel

class MyPhotosViewModel: ObservableObject {
    @Published var photos: [CommunityPhoto] = []
    @Published var commentsCount: [String: Int] = [:]
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    @MainActor
    func loadUserPhotos(userID: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            // ユーザーの写真を取得
            let userPhotos = try await FirebaseStorageService.shared.getUserPhotos(userID: userID, limit: 50)
            self.photos = userPhotos
            
            // 各写真のコメント数を取得
            for photo in userPhotos {
                if let photoID = photo.id {
                    let count = await getCommentsCount(for: photoID)
                    commentsCount[photoID] = count
                }
            }
        } catch {
            print("Failed to load user photos: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func refreshPhotos() async {
        photos = []
        commentsCount = [:]
        if let userID = UserDefaults.standard.string(forKey: "userID") {
            await loadUserPhotos(userID: userID)
        }
    }
    
    private func getCommentsCount(for photoID: String) async -> Int {
        do {
            let snapshot = try await db.collection("photo_comments")
                .whereField("photoID", isEqualTo: photoID)
                .getDocuments()
            return snapshot.documents.count
        } catch {
            return 0
        }
    }
}

// MARK: - Components

struct MyPhotoCard: View {
    let photo: CommunityPhoto
    let commentsCount: Int
    let onTap: () -> Void
    
    @State private var isImageLoading = true
    @State private var loadedImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // 写真
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(1, contentMode: .fill)
                    
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .cornerRadius(12)
                    } else if isImageLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                }
                
                // コメント数バッジ
                if commentsCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right.fill")
                            .font(.caption)
                        Text("\(commentsCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(8)
                }
                
                // 公開/非公開インジケーター
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: photo.isPublic ? "globe" : "lock.fill")
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .padding(8)
                        Spacer()
                    }
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = URL(string: photo.url) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.loadedImage = image
                    self.isImageLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.isImageLoading = false
            }
        }
    }
}

// MARK: - Photo Comments View

struct PhotoCommentsView: View {
    let photo: CommunityPhoto
    @StateObject private var viewModel = PhotoCommentsViewModel()
    @State private var newComment = ""
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @AppStorage("userID") private var userID = UUID().uuidString
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 写真プレビュー
                AsyncImage(url: URL(string: photo.url)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                } placeholder: {
                    ProgressView()
                        .frame(height: 200)
                }
                .padding()
                
                // コメントリスト
                if viewModel.comments.isEmpty && !viewModel.isLoading {
                    Spacer()
                    Text(LocalizationHelper.getCommonText("noComments", for: nativeLanguage))
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }
                
                // コメント入力欄（公開写真のみ）
                if photo.isPublic {
                    HStack {
                        TextField(
                            LocalizationHelper.getCommonText("addComment", for: nativeLanguage),
                            text: $newComment
                        )
                        .textFieldStyle(.roundedBorder)
                        
                        Button(action: {
                            Task {
                                await viewModel.postComment(
                                    photoID: photo.id ?? "",
                                    userID: userID,
                                    comment: newComment
                                )
                                newComment = ""
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(newComment.isEmpty || viewModel.isPosting)
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizationHelper.getCommonText("photoComments", for: nativeLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationHelper.getCommonText("close", for: nativeLanguage)) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if let photoID = photo.id {
                await viewModel.loadComments(for: photoID)
            }
        }
    }
}

// MARK: - Comments ViewModel

class PhotoCommentsViewModel: ObservableObject {
    @Published var comments: [PhotoCommentWithUser] = []
    @Published var isLoading = false
    @Published var isPosting = false
    
    private let db = Firestore.firestore()
    
    @MainActor
    func loadComments(for photoID: String) async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("photo_comments")
                .whereField("photoID", isEqualTo: photoID)
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            var loadedComments: [PhotoCommentWithUser] = []
            
            for document in snapshot.documents {
                if let data = try? document.data(as: PhotoCommentData.self) {
                    // ユーザー名を取得（簡略化のためIDを使用）
                    let comment = PhotoCommentWithUser(
                        id: document.documentID,
                        userID: data.userID,
                        userName: "User \(data.userID.prefix(6))",
                        comment: data.comment,
                        createdAt: data.createdAt.dateValue()
                    )
                    loadedComments.append(comment)
                }
            }
            
            self.comments = loadedComments
        } catch {
            print("Failed to load comments: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func postComment(photoID: String, userID: String, comment: String) async {
        guard !comment.isEmpty else { return }
        
        isPosting = true
        
        do {
            let commentData: [String: Any] = [
                "photoID": photoID,
                "userID": userID,
                "comment": comment,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            _ = try await db.collection("photo_comments").addDocument(data: commentData)
            
            // リロード
            await loadComments(for: photoID)
        } catch {
            print("Failed to post comment: \(error)")
        }
        
        isPosting = false
    }
}

// MARK: - Data Models

struct PhotoCommentWithUser: Identifiable {
    let id: String
    let userID: String
    let userName: String
    let comment: String
    let createdAt: Date
}

struct PhotoCommentData: Codable {
    let photoID: String
    let userID: String
    let comment: String
    let createdAt: Timestamp
}

struct CommentRow: View {
    let comment: PhotoCommentWithUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.userName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(comment.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(comment.comment)
                .font(.subheadline)
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}