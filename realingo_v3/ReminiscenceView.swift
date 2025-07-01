//
//  ReminiscenceView.swift
//  realingo_v3
//
//  レミニセンスモードのUI
//  過去の写真から生成された問題を表示
//

import SwiftUI
import Photos

struct ReminiscenceView: View {
    @StateObject private var reminiscenceManager = ReminiscenceManager.shared
    @State private var reminiscenceQuizzes: [ReminiscenceQuiz] = []
    @State private var isLoading = false
    @State private var showingQuiz = false
    @State private var selectedQuiz: ReminiscenceQuiz?
    @State private var showingPhotoPermission = false
    @State private var showingLimitedPhotoAccess = false
    @State private var errorMessage: String?
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @AppStorage("participantID") private var participantID = ""
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView(LocalizationHelper.getCommonText("loadingProblems", for: nativeLanguage))
                        .padding()
                } else if reminiscenceQuizzes.isEmpty {
                    emptyStateView
                } else {
                    quizListView
                }
            }
            .navigationTitle(LocalizationHelper.getCommonText("reminiscenceMode", for: nativeLanguage))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: generateNewQuizzes) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .onAppear {
                checkPhotoPermissionAndLoad()
            }
            .alert(LocalizationHelper.getCommonText("photoAccessRequired", for: nativeLanguage), isPresented: $showingPhotoPermission) {
                Button(LocalizationHelper.getCommonText("openSettings", for: nativeLanguage)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(LocalizationHelper.getCommonText("cancel", for: nativeLanguage), role: .cancel) {}
            } message: {
                Text(LocalizationHelper.getCommonText("photoAccessMessage", for: nativeLanguage))
            }
            .alert(LocalizationHelper.getCommonText("error", for: nativeLanguage), isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert(LocalizationHelper.getCommonText("limitedPhotoAccess", for: nativeLanguage), isPresented: $showingLimitedPhotoAccess) {
                Button(LocalizationHelper.getCommonText("selectMorePhotos", for: nativeLanguage)) {
                    if #available(iOS 14, *) {
                        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: UIApplication.shared.windows.first?.rootViewController ?? UIViewController())
                    }
                }
                Button(LocalizationHelper.getCommonText("continueWithSelected", for: nativeLanguage), role: .cancel) {}
            } message: {
                Text(LocalizationHelper.getCommonText("limitedPhotoAccessMessage", for: nativeLanguage))
            }
        }
    }
    
    private func showLimitedPhotoAccessAlert() {
        showingLimitedPhotoAccess = true
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(LocalizationHelper.getCommonText("noReminiscenceQuizzes", for: nativeLanguage))
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(LocalizationHelper.getCommonText("reminiscenceDescription", for: nativeLanguage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: generateNewQuizzes) {
                Label(LocalizationHelper.getCommonText("generateFromPhotos", for: nativeLanguage), systemImage: "sparkles")
                    .padding()
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var quizListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(reminiscenceQuizzes) { quiz in
                    ReminiscenceQuizRow(quiz: quiz) {
                        selectedQuiz = quiz
                        showingQuiz = true
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedQuiz) { quiz in
            // 問題タイプに応じて適切なビューを表示
            NavigationView {
                Group {
                    if let extendedQuiz = convertToExtendedQuiz(quiz) {
                        switch extendedQuiz.problemType {
                        case .wordArrangement:
                            ContentView(quiz: extendedQuiz)
                        case .fillInTheBlank:
                            FillInTheBlankView(quiz: extendedQuiz)
                        case .speaking:
                            SpeakingPracticeView(quiz: extendedQuiz)
                        case .writing:
                            WritingPracticeView(quiz: extendedQuiz)
                        }
                    } else {
                        Text(LocalizationHelper.getCommonText("errorLoadingQuiz", for: nativeLanguage))
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .navigationBarItems(
                    trailing: Button(LocalizationHelper.getCommonText("close", for: nativeLanguage)) {
                        selectedQuiz = nil
                    }
                )
            }
        }
    }
    
    private func checkPhotoPermissionAndLoad() {
        // iOS 14以降の新しい写真アクセス権限に対応
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        print("[写真アクセス] 完全なアクセスが許可されました")
                        self.loadReminiscenceQuizzes()
                    case .limited:
                        print("[写真アクセス] 限定的なアクセスが許可されました")
                        self.showLimitedPhotoAccessAlert()
                        self.loadReminiscenceQuizzes()
                    case .denied, .restricted:
                        print("[写真アクセス] アクセスが拒否されました")
                        self.showingPhotoPermission = true
                    case .notDetermined:
                        print("[写真アクセス] 未決定")
                        break
                    @unknown default:
                        break
                    }
                }
            }
        } else {
            // iOS 14未満の場合
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        self.loadReminiscenceQuizzes()
                    case .denied, .restricted:
                        self.showingPhotoPermission = true
                    case .notDetermined:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
    
    private func loadReminiscenceQuizzes() {
        isLoading = true
        
        Task {
            do {
                let quizzes = try await DataPersistenceManager.shared.getReminiscenceQuizzes(
                    participantID: participantID,
                    limit: 20
                )
                await MainActor.run {
                    self.reminiscenceQuizzes = quizzes
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func generateNewQuizzes() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await reminiscenceManager.processReminiscencePhotos()
                await MainActor.run {
                    loadReminiscenceQuizzes()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func convertToExtendedQuiz(_ reminiscenceQuiz: ReminiscenceQuiz) -> ExtendedQuiz? {
        // 画像URLの決定（Cloudinary URL または ローカル画像パス）
        let imageUrl: String?
        if let cloudinaryURL = reminiscenceQuiz.imageURL {
            imageUrl = cloudinaryURL
        } else if let localImagePath = reminiscenceQuiz.localImagePath {
            // ローカル画像の場合はファイルURLを使用
            imageUrl = "file://\(localImagePath)"
        } else {
            imageUrl = nil
        }
        
        // ReminiscenceQuizをExtendedQuizに変換
        return ExtendedQuiz(
            problemID: reminiscenceQuiz.id,
            language: reminiscenceQuiz.language,
            problemType: reminiscenceQuiz.problemType,
            imageMode: .reminiscence,
            question: reminiscenceQuiz.questionText,
            answer: reminiscenceQuiz.correctAnswers.joined(separator: " "),
            imageUrl: imageUrl,
            audioUrl: nil,
            options: reminiscenceQuiz.options,
            blankPositions: reminiscenceQuiz.blankPositions, // 正しくblankPositionsを渡す
            hints: nil,
            difficulty: reminiscenceQuiz.difficulty,
            tags: reminiscenceQuiz.tags,
            explanation: reminiscenceQuiz.explanation != nil ? ["ja": reminiscenceQuiz.explanation!] : nil,
            metadata: ["reminiscenceInterval": reminiscenceQuiz.timeInterval, "originalPhotoDate": ISO8601DateFormatter().string(from: reminiscenceQuiz.photoDate)],
            createdByGroup: "A",
            createdByParticipant: reminiscenceQuiz.participantID,
            createdAt: reminiscenceQuiz.createdAt,
            vlmGenerated: false,
            vlmModel: nil,
            notified: true
        )
    }
}

struct ReminiscenceQuizRow: View {
    let quiz: ReminiscenceQuiz
    let action: () -> Void
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 画像サムネイル
                Group {
                    if let imageURL = quiz.imageURL {
                        // Cloudinary画像の場合
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(10)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    ProgressView()
                                )
                        }
                    } else if let localImagePath = quiz.localImagePath,
                              let localImage = ReminiscenceManager.shared.loadLocalImage(path: localImagePath) {
                        // ローカル画像の場合
                        Image(uiImage: localImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(10)
                    } else {
                        // 画像がない場合
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: getProblemTypeIcon(quiz.problemType))
                            .foregroundColor(.purple)
                        Text(LocalizationHelper.getProblemTypeText(quiz.problemType, for: nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(quiz.questionText)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Text(quiz.timeInterval)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Preview

struct ReminiscenceView_Previews: PreviewProvider {
    static var previews: some View {
        ReminiscenceView()
    }
}