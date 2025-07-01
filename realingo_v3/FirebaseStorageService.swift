//
//  FirebaseStorageService.swift
//  realingo_v3
//
//  Firebase Storageへの画像アップロード機能
//  参照: specification.md - 写真のアップロードの実装
//  関連: DataPersistenceManager.swift, ServiceManager.swift
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import UIKit

class FirebaseStorageService {
    static let shared = FirebaseStorageService()
    
    private let storage = Storage.storage()
    private let storageRef: StorageReference
    private let db = Firestore.firestore()
    
    private init() {
        // デフォルトバケットを使用
        self.storageRef = storage.reference()
        print("[FirebaseStorageService] Initialized with bucket: \(storageRef.bucket)")
        print("[FirebaseStorageService] Storage app: \(storage.app.name)")
    }
    
    // MARK: - 画像アップロード
    
    /// 画像をFirebase Storageにアップロードし、FirestoreにメタデータPを保存
    func uploadImage(_ image: UIImage, problemID: String, userID: String) async throws -> (url: String, photoID: String) {
        print("[FirebaseStorageService] Starting upload - userID: \(userID), problemID: \(problemID)")
        
        // 画像をJPEGデータに変換（品質80%）
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[FirebaseStorageService] Failed to convert image to JPEG")
            throw FirebaseStorageError.imageConversionFailed
        }
        
        print("[FirebaseStorageService] Image converted to JPEG, size: \(imageData.count) bytes")
        
        // ユニークなファイル名を生成（UUID追加で重複防止）
        let timestamp = Date().timeIntervalSince1970
        let uniqueID = UUID().uuidString.prefix(8) // 短縮UUID
        let fileName = "\(problemID)_\(uniqueID)_\(timestamp).jpg"
        let fullPath = "photos/\(fileName)"
        
        print("[FirebaseStorageService] Generated file path: \(fullPath)")
        print("[FirebaseStorageService] Storage reference bucket: \(storageRef.bucket)")
        
        // Storage参照を作成
        let imageRef = storageRef.child(fullPath)
        print("[FirebaseStorageService] Image reference path: \(imageRef.fullPath)")
        
        // メタデータを設定
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "userID": userID,
            "problemID": problemID,
            "uploadTimestamp": "\(timestamp)"
        ]
        
        do {
            // Firebase Auth状態確認
            if let currentUser = Auth.auth().currentUser {
                print("[FirebaseStorageService] Authenticated user: \(currentUser.uid)")
                print("[FirebaseStorageService] User isAnonymous: \(currentUser.isAnonymous)")
                print("[FirebaseStorageService] Auth provider: \(currentUser.providerData.map { $0.providerID })")
            } else {
                print("[FirebaseStorageService] Warning: No authenticated user, attempting anonymous sign-in...")
                let result = try await Auth.auth().signInAnonymously()
                print("[FirebaseStorageService] Anonymous sign-in successful: \(result.user.uid)")
                print("[FirebaseStorageService] New user isAnonymous: \(result.user.isAnonymous)")
            }
            
            // 追加デバッグ: Storage アクセステスト
            print("[FirebaseStorageService] Testing Storage access...")
            let testRef = storageRef.child("test-access.txt")
            let testData = "access test".data(using: .utf8)!
            
            do {
                let testMetadata = StorageMetadata()
                testMetadata.contentType = "text/plain"
                let testUpload = try await testRef.putData(testData, metadata: testMetadata)
                print("[FirebaseStorageService] Storage access test SUCCESSFUL")
                
                // テストファイルを削除
                try? await testRef.delete()
            } catch {
                print("[FirebaseStorageService] Storage access test FAILED: \(error)")
                print("[FirebaseStorageService] This indicates a permission or configuration issue")
            }
            
            // アップロード
            print("[FirebaseStorageService] Starting upload to Storage...")
            print("[FirebaseStorageService] Upload path: \(imageRef.fullPath)")
            print("[FirebaseStorageService] Upload bucket: \(imageRef.bucket)")
            
            let uploadTask = imageRef.putData(imageData, metadata: metadata)
            
            // アップロード完了を待つ
            let uploadResult = try await uploadTask
            print("[FirebaseStorageService] Upload completed successfully.")
            
            // ダウンロードURLを取得
            print("[FirebaseStorageService] Getting download URL...")
            let downloadURL = try await imageRef.downloadURL()
            print("[FirebaseStorageService] Download URL obtained: \(downloadURL.absoluteString)")
            
            // Firestoreにメタデータを保存
            let photoData: [String: Any] = [
                "url": downloadURL.absoluteString,
                "fileName": fileName,
                "fullPath": fullPath,  // フルパスも保存
                "userID": userID,
                "problemID": problemID,
                "uploadedAt": FieldValue.serverTimestamp(),
                "isPublic": false,  // デフォルトは非公開
                "nsfwChecked": false,  // NSFW確認前
                "blocked": false
            ]
            
            print("[FirebaseStorageService] Saving metadata to Firestore...")
            print("[FirebaseStorageService] Firestore collection: 'uploaded_photos'")
            print("[FirebaseStorageService] Firestore app: \(db.app.name)")
            print("[FirebaseStorageService] Photo data to save: \(photoData)")
            
            let docRef = try await db.collection("uploaded_photos").addDocument(data: photoData)
            print("[FirebaseStorageService] Metadata saved with document ID: \(docRef.documentID)")
            
            // 保存確認のため再度読み取り
            let savedDoc = try await docRef.getDocument()
            if savedDoc.exists {
                print("[FirebaseStorageService] Verification: Document successfully saved and readable")
                print("[FirebaseStorageService] Saved data: \(savedDoc.data() ?? [:])")
            } else {
                print("[FirebaseStorageService] WARNING: Document was not properly saved!")
            }
            
            return (url: downloadURL.absoluteString, photoID: docRef.documentID)
            
        } catch {
            print("[FirebaseStorageService] Upload failed with error: \(error)")
            print("[FirebaseStorageService] Error description: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 画像をFirebase Storageにアップロードし、公開設定も同時に行う
    func uploadImage(_ image: UIImage, problemID: String, userID: String, isPublic: Bool) async throws -> (url: String, photoID: String) {
        print("[FirebaseStorageService] Starting upload with public setting - userID: \(userID), problemID: \(problemID), isPublic: \(isPublic)")
        
        // 画像をJPEGデータに変換（品質80%）
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[FirebaseStorageService] Failed to convert image to JPEG")
            throw FirebaseStorageError.imageConversionFailed
        }
        
        print("[FirebaseStorageService] Image converted to JPEG, size: \(imageData.count) bytes")
        
        // ユニークなファイル名を生成（UUID追加で重複防止）
        let timestamp = Date().timeIntervalSince1970
        let uniqueID = UUID().uuidString.prefix(8) // 短縮UUID
        let fileName = "\(problemID)_\(uniqueID)_\(timestamp).jpg"
        let fullPath = "photos/\(fileName)"
        
        print("[FirebaseStorageService] Generated file path: \(fullPath)")
        print("[FirebaseStorageService] Storage reference bucket: \(storageRef.bucket)")
        
        // Storage参照を作成
        let imageRef = storageRef.child(fullPath)
        print("[FirebaseStorageService] Image reference path: \(imageRef.fullPath)")
        
        // メタデータを設定
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "userID": userID,
            "problemID": problemID,
            "uploadTimestamp": "\(timestamp)"
        ]
        
        do {
            // Firebase Auth状態確認
            if let currentUser = Auth.auth().currentUser {
                print("[FirebaseStorageService] Authenticated user: \(currentUser.uid)")
                print("[FirebaseStorageService] User isAnonymous: \(currentUser.isAnonymous)")
            } else {
                print("[FirebaseStorageService] Warning: No authenticated user, attempting anonymous sign-in...")
                let result = try await Auth.auth().signInAnonymously()
                print("[FirebaseStorageService] Anonymous sign-in successful: \(result.user.uid)")
            }
            
            // アップロード
            print("[FirebaseStorageService] Starting upload to Storage...")
            let uploadTask = imageRef.putData(imageData, metadata: metadata)
            
            // アップロード完了を待つ
            let uploadResult = try await uploadTask
            print("[FirebaseStorageService] Upload completed successfully.")
            
            // ダウンロードURLを取得
            print("[FirebaseStorageService] Getting download URL...")
            let downloadURL = try await imageRef.downloadURL()
            print("[FirebaseStorageService] Download URL obtained: \(downloadURL.absoluteString)")
            
            // Firestoreにメタデータを保存
            var photoData: [String: Any] = [
                "url": downloadURL.absoluteString,
                "fileName": fileName,
                "fullPath": fullPath,  // フルパスも保存
                "userID": userID,
                "problemID": problemID,
                "uploadedAt": FieldValue.serverTimestamp(),
                "isPublic": isPublic,
                "nsfwChecked": false,  // NSFW確認前
                "blocked": false
            ]
            
            // 公開設定の場合はタイムスタンプも追加
            if isPublic {
                photoData["madePublicAt"] = FieldValue.serverTimestamp()
            }
            
            print("[FirebaseStorageService] Saving metadata to Firestore...")
            print("[FirebaseStorageService] Firestore collection: 'uploaded_photos'")
            print("[FirebaseStorageService] Firestore app: \(db.app.name)")
            print("[FirebaseStorageService] Photo data to save: \(photoData)")
            
            let docRef = try await db.collection("uploaded_photos").addDocument(data: photoData)
            print("[FirebaseStorageService] Metadata saved with document ID: \(docRef.documentID)")
            
            // 保存確認のため再度読み取り
            let savedDoc = try await docRef.getDocument()
            if savedDoc.exists {
                print("[FirebaseStorageService] Verification: Document successfully saved and readable")
                print("[FirebaseStorageService] Saved data: \(savedDoc.data() ?? [:])")
            } else {
                print("[FirebaseStorageService] WARNING: Document was not properly saved!")
            }
            
            return (url: downloadURL.absoluteString, photoID: docRef.documentID)
            
        } catch {
            print("[FirebaseStorageService] Upload failed with error: \(error)")
            print("[FirebaseStorageService] Error description: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - コミュニティ写真の取得
    
    /// ランダムな公開写真を取得（みんなの写真モード用）
    func getRandomCommunityPhoto() async throws -> CommunityPhoto? {
        // 公開写真のみ取得（NSFWチェックとブロック条件を緩和）
        let query = db.collection("uploaded_photos")
            .whereField("isPublic", isEqualTo: true)
            .whereField("blocked", isEqualTo: false)
            .limit(to: 50)  // パフォーマンスのため50件に制限
        
        let snapshot = try await query.getDocuments()
        
        guard !snapshot.documents.isEmpty else {
            return nil
        }
        
        // ランダムに1枚選択
        let randomIndex = Int.random(in: 0..<snapshot.documents.count)
        let document = snapshot.documents[randomIndex]
        
        return try document.data(as: CommunityPhoto.self)
    }
    
    // MARK: - 写真の公開設定
    
    /// 写真を公開設定に変更
    func makePhotoPublic(photoID: String) async throws {
        try await db.collection("uploaded_photos").document(photoID).updateData([
            "isPublic": true,
            "madePublicAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - ユーザーの写真一覧取得
    
    /// ユーザーがアップロードした写真一覧を取得
    func getUserPhotos(userID: String, limit: Int = 20) async throws -> [CommunityPhoto] {
        let query = db.collection("uploaded_photos")
            .whereField("userID", isEqualTo: userID)
            .order(by: "uploadedAt", descending: true)
            .limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: CommunityPhoto.self)
        }
    }
    
    // MARK: - コミュニティ写真の取得（ページネーション対応）
    
    /// コミュニティ写真を取得（ページネーション対応）
    func getCommunityPhotos(limit: Int = 20, lastDocument: DocumentSnapshot? = nil) async throws -> (photos: [CommunityPhoto], lastDocument: DocumentSnapshot?) {
        var query = db.collection("uploaded_photos")
            .whereField("isPublic", isEqualTo: true)
            .whereField("blocked", isEqualTo: false)
            .order(by: "uploadedAt", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        let snapshot = try await query.getDocuments()
        
        let photos = try snapshot.documents.compactMap { document in
            try document.data(as: CommunityPhoto.self)
        }
        
        return (photos: photos, lastDocument: snapshot.documents.last)
    }
    
    // MARK: - 写真の報告機能
    
    /// 写真を報告
    func reportPhoto(photoID: String, reason: String, reporterID: String) async throws {
        let reportData: [String: Any] = [
            "photoID": photoID,
            "reason": reason,
            "reporterID": reporterID,
            "reportedAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        try await db.collection("photo_reports").addDocument(data: reportData)
        
        // 写真のレポート数を増加
        try await db.collection("uploaded_photos").document(photoID).updateData([
            "reportCount": FieldValue.increment(Int64(1))
        ])
    }
}

// MARK: - エラー定義

enum FirebaseStorageError: LocalizedError {
    case imageConversionFailed
    case uploadFailed(String)
    case urlRetrievalFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "画像の変換に失敗しました"
        case .uploadFailed(let message):
            return "アップロードに失敗しました: \(message)"
        case .urlRetrievalFailed:
            return "画像URLの取得に失敗しました"
        }
    }
}

// MARK: - データモデル

struct CommunityPhoto: Codable, Identifiable {
    @DocumentID var id: String?
    let url: String
    let fileName: String
    let fullPath: String?  // 追加: 実際に保存されているフィールド
    let userID: String
    let problemID: String?
    let uploadedAt: Timestamp
    let isPublic: Bool
    let nsfwChecked: Bool?  // Optional: デフォルトfalseだが必須ではない
    let blocked: Bool?      // Optional: デフォルトfalseだが必須ではない
    let madePublicAt: Timestamp?
    
    // 感想やコメント用（将来的に実装）
    let comments: [PhotoComment]?
    
    // Computed properties for safer access to optional fields
    var isNsfwChecked: Bool { nsfwChecked ?? false }
    var isBlocked: Bool { blocked ?? false }
}

struct PhotoComment: Codable {
    let userID: String
    let comment: String
    let createdAt: Timestamp
}