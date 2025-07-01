//
//  ReminiscenceManager.swift
//  realingo_v3
//
//  レミニセンスモードのバックグラウンド処理を管理
//  過去の写真から問題を生成し、通知でユーザーに学習を促す
//

import Foundation
import Photos
import UIKit
import UserNotifications
import BackgroundTasks
import Combine

class ReminiscenceManager: NSObject, ObservableObject {
    static let shared = ReminiscenceManager()
    
    // バックグラウンドタスクの識別子
    private let reminiscenceTaskIdentifier = "com.realingo.reminiscence.refresh"
    private let photoFetchTaskIdentifier = "com.realingo.reminiscence.fetchphotos"
    
    // 時間間隔の定義
    enum TimeInterval: Int, CaseIterable {
        case oneWeek = 7
        case oneMonth = 30
        case sixMonths = 180
        case oneYear = 365
        
        var description: String {
            switch self {
            case .oneWeek: return "1週間前"
            case .oneMonth: return "1ヶ月前"
            case .sixMonths: return "6ヶ月前"
            case .oneYear: return "1年前"
            }
        }
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let today = Date()
            let targetDate = calendar.date(byAdding: .day, value: -self.rawValue, to: today)!
            
            // ±1日の範囲で写真を取得
            let startDate = calendar.date(byAdding: .day, value: -1, to: targetDate)!
            let endDate = calendar.date(byAdding: .day, value: 1, to: targetDate)!
            
            return (startDate, endDate)
        }
    }
    
    // MARK: - 初期化
    
    override init() {
        super.init()
        setupBackgroundTasks()
        requestNotificationPermission()
    }
    
    // MARK: - バックグラウンドタスクの設定
    
    private func setupBackgroundTasks() {
        // アプリ起動時にバックグラウンドタスクを登録
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: reminiscenceTaskIdentifier,
            using: nil
        ) { task in
            self.handleReminiscenceRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: photoFetchTaskIdentifier,
            using: nil
        ) { task in
            self.handlePhotoFetch(task: task as! BGProcessingTask)
        }
    }
    
    // MARK: - 通知の権限リクエスト
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    // MARK: - バックグラウンドタスクのスケジューリング
    
    func scheduleReminiscenceTasks() {
        scheduleAppRefreshTask()
        schedulePhotoProcessingTask()
    }
    
    private func scheduleAppRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: reminiscenceTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1時間後
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Reminiscence refresh task scheduled")
        } catch {
            print("Could not schedule reminiscence refresh: \(error)")
        }
    }
    
    private func schedulePhotoProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: photoFetchTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 7200) // 2時間後
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Photo processing task scheduled")
        } catch {
            print("Could not schedule photo processing: \(error)")
        }
    }
    
    // MARK: - バックグラウンドタスクハンドラー
    
    private func handleReminiscenceRefresh(task: BGAppRefreshTask) {
        // 次回のタスクをスケジュール
        scheduleAppRefreshTask()
        
        task.expirationHandler = {
            // タスクが期限切れになった場合の処理
            task.setTaskCompleted(success: false)
        }
        
        // 簡単なチェックと通知のスケジューリング
        Task {
            do {
                try await checkAndScheduleNotifications()
                task.setTaskCompleted(success: true)
            } catch {
                print("Reminiscence refresh error: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func handlePhotoFetch(task: BGProcessingTask) {
        // 次回のタスクをスケジュール
        schedulePhotoProcessingTask()
        
        task.expirationHandler = {
            // タスクが期限切れになった場合の処理
            task.setTaskCompleted(success: false)
        }
        
        // 写真の取得と問題生成
        Task {
            do {
                try await processReminiscencePhotos()
                task.setTaskCompleted(success: true)
            } catch {
                print("Photo processing error: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - 写真の取得と処理
    
    func processReminiscencePhotos() async throws {
        print("[ReminiscenceManager] processReminiscencePhotos started")
        
        let photoAssets = try await fetchPhotosFromTimeIntervals()
        
        print("[ReminiscenceManager] Found \(photoAssets.count) time intervals with photos")
        
        if photoAssets.isEmpty {
            print("[ReminiscenceManager] No photos found in any time interval")
            throw ReminiscenceError.noPhotosFound
        }
        
        // 全ての時間間隔から1枚ずつランダムに選択
        var selectedPhotos: [(TimeInterval, PHAsset)] = []
        
        for (interval, assets) in photoAssets {
            // 各時間間隔から1枚ランダムに選択
            if let randomAsset = assets.randomElement() {
                selectedPhotos.append((interval, randomAsset))
                print("[ReminiscenceManager] Selected 1 random photo from \(interval.description)")
            }
        }
        
        // 選択した写真から1枚だけランダムに選んで問題を生成
        if let (interval, asset) = selectedPhotos.randomElement() {
            print("[ReminiscenceManager] Generating problem from 1 photo (\(interval.description))")
            
            if let image = await loadImage(from: asset) {
                try await generateAndSaveProblem(
                    from: image,
                    timeInterval: interval,
                    assetDate: asset.creationDate ?? Date()
                )
            } else {
                print("[ReminiscenceManager] Failed to load image from asset")
            }
        } else {
            print("[ReminiscenceManager] No photos selected for problem generation")
        }
    }
    
    private func fetchPhotosFromTimeIntervals() async throws -> [(TimeInterval, [PHAsset])] {
        var results: [(TimeInterval, [PHAsset])] = []
        
        print("[ReminiscenceManager] Fetching photos from time intervals")
        
        for interval in TimeInterval.allCases {
            do {
                let assets = try await fetchPhotos(for: interval)
                if !assets.isEmpty {
                    print("[ReminiscenceManager] Found \(assets.count) photos for \(interval.description)")
                    results.append((interval, assets))
                } else {
                    print("[ReminiscenceManager] No photos found for \(interval.description)")
                }
            } catch {
                print("[ReminiscenceManager] Error fetching photos for \(interval.description): \(error)")
                // 続行
            }
        }
        
        return results
    }
    
    private func fetchPhotos(for interval: TimeInterval) async throws -> [PHAsset] {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else {
                    continuation.resume(throwing: ReminiscenceError.photoAccessDenied)
                    return
                }
                
                let fetchOptions = PHFetchOptions()
                let dateRange = interval.dateRange
                
                // スクリーンショットを除外するための複合述語
                fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(
                        format: "creationDate > %@ AND creationDate < %@",
                        dateRange.start as NSDate,
                        dateRange.end as NSDate
                    ),
                    // スクリーンショットを明示的に除外
                    NSPredicate(
                        format: "NOT ((mediaSubtype & %d) == %d)",
                        PHAssetMediaSubtype.photoScreenshot.rawValue,
                        PHAssetMediaSubtype.photoScreenshot.rawValue
                    )
                ])
                fetchOptions.sortDescriptors = [
                    NSSortDescriptor(key: "creationDate", ascending: false)
                ]
                
                let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                var assets: [PHAsset] = []
                
                fetchResult.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }
                
                continuation.resume(returning: assets)
            }
        }
    }
    
    private func loadImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    // MARK: - 問題の生成と保存
    
    private func generateAndSaveProblem(
        from image: UIImage,
        timeInterval: TimeInterval,
        assetDate: Date
    ) async throws {
        print("[ReminiscenceManager] generateAndSaveProblem started")
        
        // ユーザーの研究同意状況を確認
        // getUserProfileはユーザーIDを期待するので、currentUserIDを使用
        let userID = UserDefaults.standard.string(forKey: "currentUserID") ?? ""
        let participantID = UserDefaults.standard.string(forKey: "participantID") ?? ""
        print("[ReminiscenceManager] Current user ID: \(userID)")
        print("[ReminiscenceManager] Participant ID: \(participantID)")
        
        var hasConsent = false
        do {
            // userIDが空の場合はparticipantIDを使用
            let profileID = userID.isEmpty ? participantID : userID
            print("[ReminiscenceManager] Fetching user profile for ID: \(profileID)")
            
            let userProfile = try await DataPersistenceManager.shared.getUserProfile(participantID: profileID)
            hasConsent = userProfile?.consentGiven ?? false
            
            print("[ReminiscenceManager] User profile retrieved: \(userProfile != nil)")
            print("[ReminiscenceManager] User consent status: \(hasConsent)")
        } catch {
            print("[ReminiscenceManager] Error fetching user profile: \(error)")
            print("[ReminiscenceManager] Proceeding without consent (base64 mode)")
            // エラー時は同意なしとして処理を続行
            hasConsent = false
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[ReminiscenceManager] Failed to convert image to JPEG data")
            throw ReminiscenceError.imageProcessingFailed
        }
        
        print("[ReminiscenceManager] Image data size: \(imageData.count) bytes")
        
        // 研究同意がある場合はCloudinaryを使用
        if hasConsent {
            // 研究同意済み: Cloudinaryにアップロードしてから問題生成
            print("[ReminiscenceManager] Research consent given - uploading to Cloudinary")
            try await generateProblemsWithCloudinaryUpload(imageData: imageData, assetDate: assetDate, timeInterval: timeInterval)
        } else {
            // 研究同意なし: base64で直接Geminiに送信
            print("[ReminiscenceManager] No research consent - using direct base64 approach")
            try await generateProblemsDirectly(imageData: imageData, assetDate: assetDate, timeInterval: timeInterval)
        }
    }
    
    private func generateProblemsWithCloudinaryUpload(
        imageData: Data,
        assetDate: Date,
        timeInterval: TimeInterval
    ) async throws {
        let base64String = imageData.base64EncodedString()
        let cloudinaryURL = "https://api.cloudinary.com/v1_1/\(ServiceManager.shared.cloudinaryCloudName)/image/upload"
        
        print("[ReminiscenceManager] Uploading to Cloudinary: \(cloudinaryURL)")
        
        var request = URLRequest(url: URL(string: cloudinaryURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let uploadData = [
            "file": "data:image/jpeg;base64,\(base64String)",
            "upload_preset": ServiceManager.shared.cloudinaryUploadPreset
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: uploadData)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("[ReminiscenceManager] Cloudinary response status: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("[ReminiscenceManager] Cloudinary response: \(responseString)")
            }
            
            let cloudinaryResponse = try JSONDecoder().decode(CloudinaryResponse.self, from: data)
            print("[ReminiscenceManager] Image uploaded successfully: \(cloudinaryResponse.secure_url)")
            
            // 問題生成処理を続行（Cloudinary URL使用）
            await generateProblemsFromCloudinaryURL(cloudinaryResponse.secure_url, assetDate: assetDate, timeInterval: timeInterval)
            
        } catch {
            print("[ReminiscenceManager] Cloudinary upload failed: \(error)")
            throw ReminiscenceError.networkError
        }
    }
    
    private func generateProblemsDirectly(
        imageData: Data,
        assetDate: Date,
        timeInterval: TimeInterval
    ) async throws {
        print("[ReminiscenceManager] Starting direct problem generation (no Cloudinary)")
        
        // ユーザーの学習言語を取得（AppStorageから直接取得）
        let selectedLanguageRaw = UserDefaults.standard.string(forKey: "selectedLanguage") ?? SupportedLanguage.finnish.rawValue
        let nativeLanguageRaw = UserDefaults.standard.string(forKey: "nativeLanguage") ?? SupportedLanguage.japanese.rawValue
        let selectedLanguage = SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
        let nativeLanguage = SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
        
        print("[ReminiscenceManager] Using languages - Target: \(selectedLanguage.displayName), Native: \(nativeLanguage.displayName)")
        
        let userID = UserDefaults.standard.string(forKey: "currentUserID") ?? ""
        let participantID = UserDefaults.standard.string(forKey: "participantID") ?? ""
        let profileID = userID.isEmpty ? participantID : userID
        
        let userProfile = try await DataPersistenceManager.shared.getUserProfile(
            participantID: profileID
        )
        
        print("[ReminiscenceManager] User profile retrieved: \(userProfile?.userID ?? "unknown")")
        
        // 各問題タイプから1つランダムに選択
        let problemTypes: [ProblemType] = userProfile?.preferredProblemTypes ?? ProblemType.allCases
        guard let selectedProblemType = problemTypes.randomElement() else {
            print("[ReminiscenceManager] No problem types available")
            return
        }
        
        print("[ReminiscenceManager] Selected problem type: \(selectedProblemType.rawValue)")
        
        do {
            print("[ReminiscenceManager] Generating problem for type: \(selectedProblemType.rawValue)")
            
            // 画像データを直接Geminiに送信（AppStorageの言語設定を使用）
            let extendedQuiz = try await ProblemGenerationService.shared.generateProblemFromImageData(
                imageData: imageData,
                language: selectedLanguage,
                problemType: selectedProblemType,
                nativeLanguage: nativeLanguage
            )
            
            print("[ReminiscenceManager] Problem generated: \(extendedQuiz.problemID)")
            
            // ExtendedQuizからReminiscenceQuizに変換（imageURLはnil）
            // correctAnswersの処理を問題タイプに応じて変更
            let correctAnswers: [String]
            if extendedQuiz.problemType == .fillInTheBlank {
                // fillInTheBlankの場合は、空欄部分の単語のみを取得
                let words = extendedQuiz.answer.components(separatedBy: " ")
                var answers: [String] = []
                if let blankPositions = extendedQuiz.blankPositions {
                    for position in blankPositions {
                        if position < words.count {
                            answers.append(words[position])
                        }
                    }
                }
                correctAnswers = answers.isEmpty ? [extendedQuiz.answer] : answers
            } else {
                // 他の問題タイプは全体をスペースで分割
                correctAnswers = extendedQuiz.answer.components(separatedBy: " ")
            }
            
            // 研究同意なしの場合、画像を一時的にローカル保存
            let quizID = UUID().uuidString
            let localImagePath = try saveImageToLocalStorage(imageData: imageData, quizID: quizID)
            
            let reminiscenceQuiz = ReminiscenceQuiz(
                id: quizID,
                participantID: userProfile?.participantID ?? profileID, // participantIDを使用
                imageURL: nil, // Cloudinaryにアップロードしていないのでnil
                localImagePath: localImagePath, // ローカル画像パスを追加
                photoDate: assetDate,
                timeInterval: timeInterval.description,
                language: extendedQuiz.language,
                problemType: extendedQuiz.problemType,
                questionText: extendedQuiz.question,
                correctAnswers: correctAnswers,
                options: extendedQuiz.options ?? [],
                blankPositions: extendedQuiz.blankPositions, // 穴埋め位置を追加
                explanation: extendedQuiz.explanation?["ja"],
                difficulty: extendedQuiz.difficulty,
                tags: extendedQuiz.tags ?? [],
                generatedBy: "GeminiAPI"
            )
            
            print("[ReminiscenceManager] Saving reminiscence quiz: \(reminiscenceQuiz.id)")
            
            // レミニセンス問題を保存
            try await DataPersistenceManager.shared.saveReminiscenceQuiz(reminiscenceQuiz)
            
            print("[ReminiscenceManager] Quiz saved successfully")
            
            // 通知をスケジュール
            scheduleNotification(for: reminiscenceQuiz, interval: timeInterval)
            print("[ReminiscenceManager] Notification scheduled for quiz: \(reminiscenceQuiz.id)")
            
        } catch {
            print("[ReminiscenceManager] Error generating problem: \(error)")
        }
        
        print("[ReminiscenceManager] Direct problem generation completed")
    }
    
    private func generateProblemsFromCloudinaryURL(
        _ imageURL: String,
        assetDate: Date,
        timeInterval: TimeInterval
    ) async {
        do {
            print("[ReminiscenceManager] Starting problem generation from Cloudinary URL: \(imageURL)")
            
            // ユーザーの学習言語を取得（AppStorageから直接取得）
            let selectedLanguageRaw = UserDefaults.standard.string(forKey: "selectedLanguage") ?? SupportedLanguage.finnish.rawValue
            let nativeLanguageRaw = UserDefaults.standard.string(forKey: "nativeLanguage") ?? SupportedLanguage.japanese.rawValue
            let selectedLanguage = SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
            let nativeLanguage = SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
            
            print("[ReminiscenceManager] Using languages - Target: \(selectedLanguage.displayName), Native: \(nativeLanguage.displayName)")
            
            let userID = UserDefaults.standard.string(forKey: "currentUserID") ?? ""
            let participantID = UserDefaults.standard.string(forKey: "participantID") ?? ""
            let profileID = userID.isEmpty ? participantID : userID
            
            let userProfile = try await DataPersistenceManager.shared.getUserProfile(
                participantID: profileID
            )
            
            print("[ReminiscenceManager] User profile retrieved: \(userProfile?.userID ?? "unknown")")
            
            // 各問題タイプから1つランダムに選択
            let problemTypes: [ProblemType] = userProfile?.preferredProblemTypes ?? ProblemType.allCases
            guard let selectedProblemType = problemTypes.randomElement() else {
                print("[ReminiscenceManager] No problem types available")
                return
            }
            
            print("[ReminiscenceManager] Selected problem type: \(selectedProblemType.rawValue)")
            
            let extendedQuiz = try await ProblemGenerationService.shared.generateProblemFromImageURL(
                imageURL: imageURL,
                language: selectedLanguage,
                problemType: selectedProblemType,
                nativeLanguage: nativeLanguage
            )
            
            print("[ReminiscenceManager] Problem generated: \(extendedQuiz.problemID)")
            
            // ExtendedQuizからReminiscenceQuizに変換
            // correctAnswersの処理を問題タイプに応じて変更
            let correctAnswers: [String]
            if extendedQuiz.problemType == .fillInTheBlank {
                // fillInTheBlankの場合は、空欄部分の単語のみを取得
                let words = extendedQuiz.answer.components(separatedBy: " ")
                var answers: [String] = []
                if let blankPositions = extendedQuiz.blankPositions {
                    for position in blankPositions {
                        if position < words.count {
                            answers.append(words[position])
                        }
                    }
                }
                correctAnswers = answers.isEmpty ? [extendedQuiz.answer] : answers
            } else {
                // 他の問題タイプは全体をスペースで分割
                correctAnswers = extendedQuiz.answer.components(separatedBy: " ")
            }
            
            let reminiscenceQuiz = ReminiscenceQuiz(
                id: UUID().uuidString,
                participantID: userProfile?.participantID ?? profileID, // participantIDを使用
                imageURL: imageURL,
                localImagePath: nil, // Cloudinary使用時はnil
                photoDate: assetDate,
                timeInterval: timeInterval.description,
                language: extendedQuiz.language,
                problemType: extendedQuiz.problemType,
                questionText: extendedQuiz.question,
                correctAnswers: correctAnswers,
                options: extendedQuiz.options ?? [],
                blankPositions: extendedQuiz.blankPositions, // 穴埋め位置を追加
                explanation: extendedQuiz.explanation?["ja"],
                difficulty: extendedQuiz.difficulty,
                tags: extendedQuiz.tags ?? [],
                generatedBy: "GeminiAPI"
            )
            
            print("[ReminiscenceManager] Saving reminiscence quiz: \(reminiscenceQuiz.id)")
            
            // レミニセンス問題を保存
            try await DataPersistenceManager.shared.saveReminiscenceQuiz(reminiscenceQuiz)
            
            print("[ReminiscenceManager] Quiz saved successfully")
            
            // 通知をスケジュール
            scheduleNotification(for: reminiscenceQuiz, interval: timeInterval)
            print("[ReminiscenceManager] Notification scheduled for quiz: \(reminiscenceQuiz.id)")
            
            print("[ReminiscenceManager] All problems generated successfully for image: \(imageURL)")
            
        } catch {
            print("[ReminiscenceManager] Error generating problems from Cloudinary URL: \(error)")
            print("[ReminiscenceManager] Error details: \(error.localizedDescription)")
            
            // Gemini APIエラーの詳細ログ
            if let nsError = error as NSError? {
                print("[ReminiscenceManager] NSError domain: \(nsError.domain)")
                print("[ReminiscenceManager] NSError code: \(nsError.code)")
                print("[ReminiscenceManager] NSError userInfo: \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - 通知の管理
    
    private func checkAndScheduleNotifications() async throws {
        // 保存されているレミニセンス問題を確認（現在のユーザーのもの）
        let participantID = UserDefaults.standard.string(forKey: "participantID") ?? ""
        let quizzes = try await DataPersistenceManager.shared.getReminiscenceQuizzes(
            participantID: participantID,
            limit: 50
        )
        
        // まだ通知されていない問題に対して通知をスケジュール
        for quiz in quizzes {
            if !isNotificationScheduled(for: quiz.id) {
                // timeIntervalからTimeIntervalを取得
                let interval = TimeInterval.allCases.first { $0.description == quiz.timeInterval } ?? .oneWeek
                scheduleNotification(
                    for: quiz,
                    interval: interval
                )
            }
        }
    }
    
    private func scheduleNotification(for quiz: ReminiscenceQuiz, interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "思い出の写真から学習しましょう！"
        content.body = "\(interval.description)の写真から\(quiz.language.displayName)の問題を作成しました"
        content.sound = .default
        content.userInfo = ["problemID": quiz.id]
        
        // 今日の午後3時に通知
        var dateComponents = DateComponents()
        dateComponents.hour = 15
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "reminiscence-\(quiz.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling error: \(error)")
            }
        }
    }
    
    private func isNotificationScheduled(for problemID: String) -> Bool {
        // 実装の簡略化のため、UserDefaultsで管理
        let key = "notified-\(problemID)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    // MARK: - エラー定義
    
    enum ReminiscenceError: LocalizedError {
        case photoAccessDenied
        case imageProcessingFailed
        case networkError
        case noPhotosFound
        
        var errorDescription: String? {
            switch self {
            case .photoAccessDenied:
                return "写真へのアクセスが許可されていません"
            case .imageProcessingFailed:
                return "画像の処理に失敗しました"
            case .networkError:
                return "ネットワークエラーが発生しました"
            case .noPhotosFound:
                return "指定された期間に写真が見つかりませんでした"
            }
        }
    }
    
    // MARK: - ローカル画像保存（研究同意なしの場合）
    
    private func saveImageToLocalStorage(imageData: Data, quizID: String) throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reminiscenceImagesPath = documentsPath.appendingPathComponent("reminiscence_images")
        
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: reminiscenceImagesPath.path) {
            try FileManager.default.createDirectory(at: reminiscenceImagesPath, withIntermediateDirectories: true)
        }
        
        let fileName = "\(quizID).jpg"
        let filePath = reminiscenceImagesPath.appendingPathComponent(fileName)
        
        try imageData.write(to: filePath)
        
        print("[ReminiscenceManager] Saved image locally: \(filePath.path)")
        return filePath.path
    }
    
    func loadLocalImage(path: String) -> UIImage? {
        guard FileManager.default.fileExists(atPath: path) else {
            print("[ReminiscenceManager] Local image not found at path: \(path)")
            return nil
        }
        
        return UIImage(contentsOfFile: path)
    }
}

// MARK: - CloudinaryResponse

struct CloudinaryResponse: Codable {
    let secure_url: String
}

