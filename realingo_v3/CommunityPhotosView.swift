//
//  CommunityPhotosView.swift
//  realingo_v3
//
//  みんなの写真モード - コミュニティで共有された写真を使って学習
//  参照: specification.md - みんなの写真モードの実装
//  関連: MainMenuView.swift, FirebaseStorageService.swift
//

import SwiftUI
import FirebaseFirestore

struct CommunityPhotosView: View {
    @StateObject private var viewModel = CommunityPhotosViewModel()
    @State private var selectedPhoto: CommunityPhoto?
    @State private var showingProblemTypeSheet = false
    @State private var selectedProblemType: ProblemType = .wordArrangement
    @State private var isGeneratingProblem = false
    @State private var generatedQuiz: ExtendedQuiz?
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 検索バー
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField(LocalizationHelper.getCommonText("searchPhotos", for: nativeLanguage), text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    if !searchText.isEmpty {
                        Button(LocalizationHelper.getCommonText("cancel", for: nativeLanguage)) {
                            searchText = ""
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                ScrollView {
                if viewModel.isLoading && viewModel.photos.isEmpty {
                    ProgressView(LocalizationHelper.getCommonText("loading", for: nativeLanguage))
                        .padding()
                } else if viewModel.photos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text(LocalizationHelper.getCommonText("noCommunityPhotos", for: nativeLanguage))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(LocalizationHelper.getCommonText("communityPhotosDescription", for: nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 100)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 15) {
                        ForEach(viewModel.photos) { photo in
                            CommunityPhotoCard(
                                photo: photo,
                                onTap: {
                                    selectedPhoto = photo
                                    showingProblemTypeSheet = true
                                }
                            )
                        }
                    }
                    .padding()
                    
                    if viewModel.hasMore {
                        Button(action: {
                            Task {
                                await viewModel.loadMorePhotos()
                            }
                        }) {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text(LocalizationHelper.getCommonText("loadMore", for: nativeLanguage))
                            }
                        }
                        .padding()
                    }
                }
            }
            }
            .navigationTitle(LocalizationHelper.getCommonText("everyonesPhotos", for: nativeLanguage))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refreshPhotos()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingProblemTypeSheet) {
                ProblemTypeSelectionSheet(
                    photo: selectedPhoto,
                    selectedProblemType: $selectedProblemType,
                    isGenerating: $isGeneratingProblem,
                    onGenerate: generateProblem,
                    onCancel: {
                        showingProblemTypeSheet = false
                        selectedPhoto = nil
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
        .task {
            await viewModel.loadPhotos()
        }
    }
    
    private func generateProblem() {
        guard let photo = selectedPhoto else { return }
        
        isGeneratingProblem = true
        errorMessage = nil
        
        Task {
            do {
                // 問題生成
                let quiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                    imageURL: photo.url,
                    language: selectedLanguage,
                    problemType: selectedProblemType,
                    nativeLanguage: nativeLanguage
                )
                
                // コミュニティ写真のIDを記録
                var modifiedQuiz = quiz
                modifiedQuiz.communityPhotoID = photo.id
                
                // 問題を保存
                try await DataPersistenceManager.shared.saveQuiz(modifiedQuiz)
                
                DispatchQueue.main.async {
                    self.isGeneratingProblem = false
                    self.showingProblemTypeSheet = false
                    self.generatedQuiz = modifiedQuiz
                    self.selectedPhoto = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.isGeneratingProblem = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - ViewModel

class CommunityPhotosViewModel: ObservableObject {
    @Published var photos: [CommunityPhoto] = []
    @Published var isLoading = false
    @Published var hasMore = true
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 20
    
    @MainActor
    func loadPhotos() async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            // ページング形式で写真を取得（より確実な方法）
            let result = try await fetchPhotos()
            self.photos = result.photos
            self.hasMore = result.hasMore
            self.lastDocument = result.lastDoc
            
            print("[CommunityPhotosViewModel] Initial load completed: \(photos.count) photos loaded")
            
            // バックアップとしてランダム写真も試す
            if photos.isEmpty {
                print("[CommunityPhotosViewModel] No photos found via pagination, trying random photo...")
                if let randomPhoto = try await FirebaseStorageService.shared.getRandomCommunityPhoto() {
                    self.photos = [randomPhoto]
                    print("[CommunityPhotosViewModel] Found 1 random photo")
                } else {
                    print("[CommunityPhotosViewModel] No random photo found either")
                }
            }
        } catch {
            print("[CommunityPhotosViewModel] Failed to load photos: \(error)")
            print("[CommunityPhotosViewModel] Error details: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadMorePhotos() async {
        guard !isLoading && hasMore else { return }
        
        isLoading = true
        
        do {
            let result = try await fetchPhotos()
            self.photos.append(contentsOf: result.photos)
            self.hasMore = result.hasMore
            self.lastDocument = result.lastDoc
        } catch {
            print("Failed to load more photos: \(error)")
        }
        
        isLoading = false
    }
    
    @MainActor
    func refreshPhotos() async {
        lastDocument = nil
        hasMore = true
        photos = [] // 既存の写真をクリア
        await loadPhotos()
    }
    
    private func fetchPhotos() async throws -> (photos: [CommunityPhoto], hasMore: Bool, lastDoc: DocumentSnapshot?) {
        print("[CommunityPhotosViewModel] Fetching photos from Firestore...")
        
        // 完全デバッグ: まず全てのドキュメントを確認
        print("[CommunityPhotosViewModel] === FULL DEBUG: Checking all documents ===")
        let totalQuery = db.collection("uploaded_photos")
        let totalSnapshot = try await totalQuery.getDocuments()
        print("[CommunityPhotosViewModel] Total documents in uploaded_photos: \(totalSnapshot.documents.count)")
        
        for (index, doc) in totalSnapshot.documents.enumerated() {
            let data = doc.data()
            print("[CommunityPhotosViewModel] Document \(index + 1):")
            print("  - ID: \(doc.documentID)")
            print("  - isPublic: \(data["isPublic"] ?? "nil")")
            print("  - blocked: \(data["blocked"] ?? "nil")")
            print("  - nsfwChecked: \(data["nsfwChecked"] ?? "nil")")
            print("  - url: \(data["url"] ?? "nil")")
            print("  - userID: \(data["userID"] ?? "nil")")
        }
        print("[CommunityPhotosViewModel] === END DEBUG ===")
        
        // テスト用: 既存のFirebase Storage写真用のFirestoreドキュメントを作成
        if totalSnapshot.documents.count == 0 {
            print("[CommunityPhotosViewModel] No documents found. Creating test document for existing Storage photo...")
            
            let testPhotoData: [String: Any] = [
                "url": "https://firebasestorage.googleapis.com/v0/b/realingo-e7a54.firebasestorage.app/o/photos%2F174E9FF0-B6A0-4593-AD9E-49A6D020DA01_1751326380.680726.jpg?alt=media&token=cdf23f68-a267-409e-a38c-0ddb3f07def8",
                "fileName": "174E9FF0-B6A0-4593-AD9E-49A6D020DA01_1751326380.680726.jpg",
                "fullPath": "photos/174E9FF0-B6A0-4593-AD9E-49A6D020DA01_1751326380.680726.jpg",
                "userID": "test-user",
                "problemID": "174E9FF0-B6A0-4593-AD9E-49A6D020DA01",
                "uploadedAt": FieldValue.serverTimestamp(),
                "isPublic": true,  // テスト用に公開設定
                "nsfwChecked": false,
                "blocked": false
            ]
            
            do {
                let docRef = try await db.collection("uploaded_photos").addDocument(data: testPhotoData)
                print("[CommunityPhotosViewModel] Test document created with ID: \(docRef.documentID)")
                
                // 再度クエリして確認
                let recheck = try await db.collection("uploaded_photos").getDocuments()
                print("[CommunityPhotosViewModel] After test document creation: \(recheck.documents.count) documents")
            } catch {
                print("[CommunityPhotosViewModel] Failed to create test document: \(error)")
            }
        }
        
        // まず全ての写真を取得してデバッグ
        var allPhotosQuery = db.collection("uploaded_photos")
            .order(by: "uploadedAt", descending: true)
            .limit(to: pageSize)
        
        if let lastDoc = lastDocument {
            allPhotosQuery = allPhotosQuery.start(afterDocument: lastDoc)
        }
        
        let snapshot = try await allPhotosQuery.getDocuments()
        print("[CommunityPhotosViewModel] Found \(snapshot.documents.count) total photos in Firestore")
        
        // まず生のデータを確認
        for (index, document) in snapshot.documents.enumerated() {
            let data = document.data()
            print("[CommunityPhotosViewModel] Document \(index): \(document.documentID)")
            print("  Data: \(data)")
        }
        
        let photos = try snapshot.documents.compactMap { document -> CommunityPhoto? in
            do {
                let photo = try document.data(as: CommunityPhoto.self)
                print("[CommunityPhotosViewModel] Successfully decoded photo: \(photo.id ?? "no-id")")
                print("  URL: \(photo.url)")
                print("  isPublic: \(photo.isPublic)")
                print("  blocked: \(photo.isBlocked)")
                print("  nsfwChecked: \(photo.isNsfwChecked)")
                
                // 条件を緩和: isPublicのみチェック、blocked状態も考慮
                return (photo.isPublic && !photo.isBlocked) ? photo : nil
            } catch {
                print("[CommunityPhotosViewModel] Failed to decode photo: \(error)")
                print("  Document ID: \(document.documentID)")
                print("  Raw data: \(document.data())")
                return nil
            }
        }
        
        print("[CommunityPhotosViewModel] Filtered to \(photos.count) valid public photos")
        
        let hasMorePhotos = snapshot.documents.count >= pageSize
        let lastDocument = snapshot.documents.last
        
        return (photos: photos, hasMore: hasMorePhotos, lastDoc: lastDocument)
    }
}

// MARK: - Components

struct CommunityPhotoCard: View {
    let photo: CommunityPhoto
    let onTap: () -> Void
    
    @State private var isImageLoading = true
    @State private var loadedImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
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

struct ProblemTypeSelectionSheet: View {
    let photo: CommunityPhoto?
    @Binding var selectedProblemType: ProblemType
    @Binding var isGenerating: Bool
    let onGenerate: () -> Void
    let onCancel: () -> Void
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(LocalizationHelper.getCommonText("selectProblemType", for: nativeLanguage))
                    .font(.headline)
                    .padding(.top)
                
                VStack(spacing: 10) {
                    ForEach(ProblemType.allCases, id: \.self) { type in
                        Button(action: {
                            selectedProblemType = type
                        }) {
                            HStack {
                                Image(systemName: getProblemTypeIcon(type))
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading) {
                                    Text(LocalizationHelper.getProblemTypeText(type, for: nativeLanguage))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    Text(LocalizationHelper.getProblemTypeDescription(type, for: nativeLanguage))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedProblemType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedProblemType == type ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                
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
                        onGenerate()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func getProblemTypeIcon(_ type: ProblemType) -> String {
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
}