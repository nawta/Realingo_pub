//
//  ModelDownloadManager.swift
//  realingo_v3
//
//  VLMモデルのダウンロード管理
//  参照: specification.md - モデルダウンロード機能
//  関連: VLMManager.swift, VLMSettingsView.swift
//

import Foundation
import Combine

// ダウンロードエラー
enum DownloadError: LocalizedError {
    case invalidURL
    case networkError(String)
    case diskSpaceInsufficient
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なダウンロードURLです"
        case .networkError(let message):
            return "ネットワークエラー: \(message)"
        case .diskSpaceInsufficient:
            return "ディスク容量が不足しています"
        case .cancelled:
            return "ダウンロードがキャンセルされました"
        }
    }
}

// ダウンロードタスク
class DownloadTask: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: Double = 0
    @Published var bytesWritten: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var isDownloading = false
    @Published var error: Error?
    
    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession!
    private var continuation: CheckedContinuation<URL, Error>?
    
    let model: VLMModel
    private let destinationURL: URL
    
    init(model: VLMModel, destinationURL: URL) {
        self.model = model
        self.destinationURL = destinationURL
        super.init()
        
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // ダウンロード開始
    func start() async throws -> URL {
        guard let url = URL(string: model.downloadURL) else {
            throw DownloadError.invalidURL
        }
        
        // ディスク容量チェック
        if !checkDiskSpace(for: model) {
            throw DownloadError.diskSpaceInsufficient
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            DispatchQueue.main.async {
                self.isDownloading = true
                self.error = nil
            }
            
            let request = URLRequest(url: url)
            downloadTask = session.downloadTask(with: request)
            downloadTask?.resume()
        }
    }
    
    // ダウンロード一時停止
    func pause() {
        downloadTask?.suspend()
        DispatchQueue.main.async {
            self.isDownloading = false
        }
    }
    
    // ダウンロード再開
    func resume() {
        downloadTask?.resume()
        DispatchQueue.main.async {
            self.isDownloading = true
        }
    }
    
    // ダウンロードキャンセル
    func cancel() {
        downloadTask?.cancel()
        DispatchQueue.main.async {
            self.isDownloading = false
            self.progress = 0
        }
        continuation?.resume(throwing: DownloadError.cancelled)
    }
    
    // ディスク容量チェック
    private func checkDiskSpace(for model: VLMModel) -> Bool {
        do {
            let fileManager = FileManager.default
            let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            let values = try documentDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
                // 必要な容量（モデルサイズ + バッファ）
                let requiredSpace: Int64
                switch model.id {
                case VLMModelType.gemma3_4b_q4.rawValue:
                    requiredSpace = 3_000_000_000 // 3GB
                case VLMModelType.gemma3_4b_q8.rawValue:
                    requiredSpace = 5_000_000_000 // 5GB
                case VLMModelType.heron_nvila_2b.rawValue:
                    requiredSpace = 2_000_000_000 // 2GB
                default:
                    requiredSpace = 3_000_000_000 // デフォルト3GB
                }
                
                return availableCapacity >= requiredSpace
            }
        } catch {
            print("[DownloadTask] ディスク容量チェックエラー: \(error)")
        }
        
        return false
    }
    
    // URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // ファイルを目的地に移動
            let fileManager = FileManager.default
            
            // ディレクトリが存在しない場合は作成
            let directory = destinationURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            
            // 既存のファイルがある場合は削除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // ファイルを移動
            try fileManager.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                self.isDownloading = false
                self.progress = 1.0
            }
            
            continuation?.resume(returning: destinationURL)
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isDownloading = false
            }
            continuation?.resume(throwing: error)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            self.bytesWritten = totalBytesWritten
            self.totalBytes = totalBytesExpectedToWrite
            
            if totalBytesExpectedToWrite > 0 {
                self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.error = error
                self.isDownloading = false
            }
            continuation?.resume(throwing: DownloadError.networkError(error.localizedDescription))
        }
    }
}

// モデルダウンロードマネージャー
@MainActor
class ModelDownloadManager: ObservableObject {
    static let shared = ModelDownloadManager()
    
    @Published var downloadTasks: [VLMModel: DownloadTask] = [:]
    
    private init() {}
    
    // ダウンロード開始
    func downloadModel(_ model: VLMModel) async throws -> URL {
        // 既存のタスクがある場合はキャンセル
        if let existingTask = downloadTasks[model] {
            existingTask.cancel()
        }
        
        // ダウンロード先URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath
            .appendingPathComponent("VLMModels")
            .appendingPathComponent(model.filename)
        
        // 新しいダウンロードタスクを作成
        let task = DownloadTask(model: model, destinationURL: destinationURL)
        downloadTasks[model] = task
        
        // ダウンロード開始
        let url = try await task.start()
        
        // 完了したらタスクを削除
        downloadTasks.removeValue(forKey: model)
        
        return url
    }
    
    // ダウンロード一時停止
    func pauseDownload(_ model: VLMModel) {
        downloadTasks[model]?.pause()
    }
    
    // ダウンロード再開
    func resumeDownload(_ model: VLMModel) {
        downloadTasks[model]?.resume()
    }
    
    // ダウンロードキャンセル
    func cancelDownload(_ model: VLMModel) {
        downloadTasks[model]?.cancel()
        downloadTasks.removeValue(forKey: model)
    }
    
    // ダウンロード進捗を取得
    func getProgress(for model: VLMModel) -> Double {
        return downloadTasks[model]?.progress ?? 0
    }
    
    // フォーマット済みのダウンロードステータス
    func getStatusText(for model: VLMModel) -> String? {
        guard let task = downloadTasks[model] else { return nil }
        
        if task.isDownloading {
            let percentage = Int(task.progress * 100)
            let downloadedMB = Double(task.bytesWritten) / 1_000_000
            let totalMB = Double(task.totalBytes) / 1_000_000
            
            if totalMB > 0 {
                return String(format: "ダウンロード中 %d%% (%.1fMB / %.1fMB)", percentage, downloadedMB, totalMB)
            } else {
                return "ダウンロード中..."
            }
        } else if let error = task.error {
            return "エラー: \(error.localizedDescription)"
        } else {
            return nil
        }
    }
}