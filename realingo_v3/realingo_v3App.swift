//
//  realingo_v3App.swift
//  realingo_v3
//
//  Created by 西田直人 on 3/9/25.
//

import SwiftUI
import Firebase // Firebaseを使う場合
import FirebaseCore
import FirebaseAppCheck
import BackgroundTasks


@main
struct realingo_v3App: App {
    // シーンフェーズ監視 (アプリがactive/background切り替えを検知)
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var usageTracker = UsageTimeTracker()
    @StateObject private var sharedImageHandler = SharedImageHandler.shared

    init() {
        // Firebase 初期化
        FirebaseApp.configure()
        
        // App Checkの設定
        #if DEBUG
        // デバッグ時はデバッグプロバイダーを使用
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        // リリース時はDeviceCheckを使用（iOS 11.0+）
        let providerFactory = DeviceCheckProviderFactory()
        #endif
        
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        // App Checkトークンの自動更新を有効化
        AppCheck.appCheck().isTokenAutoRefreshEnabled = true
        
        // 非同期で重い処理を実行
        Task {
            // レミニセンスモードのバックグラウンドタスクをスケジュール
            ReminiscenceManager.shared.scheduleReminiscenceTasks()
            
            // 匿名認証でサインイン（バックグラウンドで実行）
            await AuthManager.shared.checkAuthenticationStatus()
        }
    }
    
    
    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .onAppear {
                    usageTracker.startNewDayIfNeeded()
                }
                .environmentObject(sharedImageHandler)
                .onOpenURL { url in
                    // 他のアプリから画像が共有された時の処理
                    handleIncomingURL(url)
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                usageTracker.appDidBecomeActive()
            case .inactive, .background:
                usageTracker.appWillResignActive()
            @unknown default:
                break
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // 画像ファイルかどうかを確認
        if url.isFileURL {
            let pathExtension = url.pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif"]
            
            if imageExtensions.contains(pathExtension) {
                // 画像を読み込んで処理
                if let imageData = try? Data(contentsOf: url),
                   let image = UIImage(data: imageData) {
                    sharedImageHandler.handleSharedImage(image)
                }
            }
        }
    }
}

// MARK: - App Check Debug Support
// デバッグ時にFirebase Consoleでデバッグトークンを登録する必要があります
// コンソールに表示されるデバッグトークンをFirebase ConsoleのApp Check設定で登録してください

