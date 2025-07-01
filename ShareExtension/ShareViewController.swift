//
//  ShareViewController.swift
//  ShareExtension
//
//  他アプリから画像を受け取るShare Extension
//  参照: specification.md - 他アプリから自分のアプリへ画像を渡したい
//  関連: MainMenuView.swift, ContentView.swift
//

import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {
    
    override func isContentValid() -> Bool {
        // 画像が少なくとも1つ含まれているかチェック
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let itemProviders = extensionItem.attachments {
            return itemProviders.contains { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            }
        }
        return false
    }
    
    override func didSelectPost() {
        // 画像を処理
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let itemProviders = extensionItem.attachments {
            
            for provider in itemProviders {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL {
                            // URLから画像を保存
                            self?.saveImageFromURL(url)
                        } else if let image = item as? UIImage {
                            // UIImageを直接保存
                            self?.saveImage(image)
                        } else if let data = item as? Data {
                            // Dataから画像を作成して保存
                            if let image = UIImage(data: data) {
                                self?.saveImage(image)
                            }
                        }
                    }
                }
            }
        }
        
        // 完了を通知
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    override func configurationItems() -> [Any]! {
        // カスタム設定項目を追加可能
        return []
    }
    
    // MARK: - Private Methods
    
    private func saveImageFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let image = UIImage(data: data) {
                saveImage(image)
            }
        } catch {
            print("Failed to load image from URL: \(error)")
        }
    }
    
    private func saveImage(_ image: UIImage) {
        // App Groupsを使用して共有ストレージに保存
        let sharedDefaults = UserDefaults(suiteName: "group.com.realingo.shared")
        
        // 画像をJPEGデータに変換
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            // 一時的なファイル名を生成
            let fileName = "shared_image_\(Date().timeIntervalSince1970).jpg"
            
            // App Groups共有コンテナのパスを取得
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.realingo.shared") {
                let fileURL = containerURL.appendingPathComponent(fileName)
                
                do {
                    // ファイルに書き込み
                    try imageData.write(to: fileURL)
                    
                    // ファイルパスをUserDefaultsに保存
                    var sharedImages = sharedDefaults?.stringArray(forKey: "pendingSharedImages") ?? []
                    sharedImages.append(fileURL.path)
                    sharedDefaults?.set(sharedImages, forKey: "pendingSharedImages")
                    
                    // フラグを立てて、メインアプリ起動時に処理するように通知
                    sharedDefaults?.set(true, forKey: "hasNewSharedImages")
                    
                    print("Image saved successfully: \(fileName)")
                } catch {
                    print("Failed to save image: \(error)")
                }
            }
        }
    }
}