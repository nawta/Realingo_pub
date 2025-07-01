//
//  AuthManager.swift
//  realingo_v3
//
//  Firebase認証（匿名認証）の管理
//

import Foundation
import FirebaseAuth
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var authError: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        // 認証状態の監視
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                if let user = user {
                    // ユーザーIDを保存
                    UserDefaults.standard.set(user.uid, forKey: "currentUserID")
                    print("Authenticated with UID: \(user.uid)")
                }
            }
        }
    }
    
    // 匿名認証でサインイン
    func signInAnonymously() async throws {
        isAuthenticating = true
        authError = nil
        
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("Successfully signed in anonymously with UID: \(result.user.uid)")
            
            // 初回ログイン時にユーザープロファイルを作成
            if let isNewUser = result.additionalUserInfo?.isNewUser, isNewUser {
                await createInitialUserProfile(uid: result.user.uid)
            }
            
            isAuthenticating = false
        } catch {
            isAuthenticating = false
            authError = error.localizedDescription
            throw error
        }
    }
    
    // アカウントのアップグレード（将来的な実装用）
    func linkWithEmailPassword(email: String, password: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw AuthError.noCurrentUser
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await currentUser.link(with: credential)
    }
    
    // サインアウト
    func signOut() throws {
        try Auth.auth().signOut()
        UserDefaults.standard.removeObject(forKey: "currentUserID")
    }
    
    // 初期ユーザープロファイルの作成
    private func createInitialUserProfile(uid: String) async {
        let profile = UserProfile(
            userID: uid,
            participantID: UUID().uuidString,
            groupID: "",
            nativeLanguage: .japanese,
            learningLanguages: [.finnish],
            currentLanguage: .finnish,
            proficiencyLevels: [:],
            dailyGoalMinutes: 15,
            reminderTime: nil,
            preferredProblemTypes: ProblemType.allCases,
            totalLearningMinutes: 0,
            currentStreak: 0,
            longestStreak: 0,
            totalProblemsCompleted: 0,
            consentGiven: false,
            studyStartDate: Date()
        )
        
        do {
            try await DataPersistenceManager.shared.saveUserProfile(profile)
        } catch {
            print("Failed to create initial user profile: \(error)")
        }
    }
    
    // アプリ起動時の自動サインイン
    func checkAuthenticationStatus() async {
        if Auth.auth().currentUser == nil {
            // 現在のユーザーがいない場合は匿名認証
            do {
                try await signInAnonymously()
            } catch {
                print("Failed to sign in anonymously: \(error)")
            }
        } else {
            // 既にサインイン済み
            isAuthenticated = true
        }
    }
}

// カスタムエラー
enum AuthError: LocalizedError {
    case noCurrentUser
    
    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return "現在のユーザーが見つかりません"
        }
    }
}