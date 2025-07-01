import SwiftUI

struct VLMModelManagementView: View {
    @StateObject private var downloadManager = VLMDownloadManager()
    @State private var selectedModel: VLMModel?
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: VLMModel?
    
    var body: some View {
        List {
            Section(header: Text("Available Models")) {
                ForEach(downloadManager.availableModels) { model in
                    VLMModelRow(model: model, downloadManager: downloadManager)
                }
            }
            
            Section(header: Text("Downloaded Models")) {
                ForEach(downloadManager.downloadedModels) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.name)
                                .font(.headline)
                            Text(model.size)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if downloadManager.activeModelID == model.id {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Button("Activate") {
                                downloadManager.activateModel(model)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button(action: {
                            modelToDelete = model
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Section(header: Text("Storage")) {
                HStack {
                    Text("Total Storage Used")
                    Spacer()
                    Text(downloadManager.totalStorageUsed)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("VLM Models")
        .alert("Delete Model", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    downloadManager.deleteModel(model)
                }
            }
        } message: {
            Text("Are you sure you want to delete this model? This action cannot be undone.")
        }
    }
}

struct VLMModelRow: View {
    let model: VLMModel
    @ObservedObject var downloadManager: VLMDownloadManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.name)
                    .font(.headline)
                HStack {
                    Text(model.size)
                    Text("•")
                    Text(model.description)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let task = downloadManager.downloadTasks[model.id] {
                // Downloading
                VStack {
                    ProgressView(value: task.progress)
                        .frame(width: 100)
                    Text("\(Int(task.progress * 100))%")
                        .font(.caption)
                }
                
                Button(action: {
                    downloadManager.cancelDownload(for: model)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else if downloadManager.isModelDownloaded(model) {
                // Downloaded
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                // Not downloaded
                Button(action: {
                    downloadManager.downloadModel(model)
                }) {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

// Download manager for VLM models
class VLMDownloadManager: ObservableObject {
    @Published var availableModels: [VLMModel] = []
    @Published var downloadedModels: [VLMModel] = []
    @Published var downloadTasks: [String: DownloadTask] = [:]
    @Published var activeModelID: String?
    @Published var totalStorageUsed: String = "0 MB"
    
    struct DownloadTask {
        let task: URLSessionDownloadTask
        var progress: Double
    }
    
    init() {
        loadAvailableModels()
        checkDownloadedModels()
    }
    
    private func loadAvailableModels() {
        availableModels = [
            VLMModel(
                id: "llava-v1.6-mistral-7b-q4",
                name: "LLaVA v1.6 Mistral 7B",
                filename: "llava-v1.6-mistral-7b.Q4_K_M.gguf",
                url: "https://huggingface.co/cjpais/llava-v1.6-mistral-7b-gguf/resolve/main/llava-v1.6-mistral-7b.Q4_K_M.gguf",
                size: "4.1 GB",
                description: "Best quality, recommended"
            ),
            VLMModel(
                id: "llava-v1.5-7b-q4",
                name: "LLaVA v1.5 7B",
                filename: "llava-v1.5-7b-q4_0.gguf",
                url: "https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/llava-v1.5-7b-q4_0.gguf",
                size: "3.8 GB",
                description: "Good quality, stable"
            ),
            VLMModel(
                id: "bakllava-1-q4",
                name: "BakLLaVA-1",
                filename: "bakllava-1-q4_0.gguf",
                url: "https://huggingface.co/mys/ggml_bakllava-1/resolve/main/bakllava-1-q4_0.gguf",
                size: "3.8 GB",
                description: "Alternative model"
            )
        ]
    }
    
    func checkDownloadedModels() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        downloadedModels = availableModels.filter { model in
            let modelPath = documentsPath.appendingPathComponent(model.filename)
            return FileManager.default.fileExists(atPath: modelPath.path)
        }
        
        updateStorageUsed()
        
        // Check active model
        if let activeModelFilename = UserDefaults.standard.string(forKey: "activeVLMModel") {
            activeModelID = availableModels.first { $0.filename == activeModelFilename }?.id
        }
    }
    
    func isModelDownloaded(_ model: VLMModel) -> Bool {
        return downloadedModels.contains { $0.id == model.id }
    }
    
    func downloadModel(_ model: VLMModel) {
        guard let url = URL(string: model.url) else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsPath.appendingPathComponent(model.filename)
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] location, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Download error: \(error)")
                DispatchQueue.main.async {
                    self.downloadTasks.removeValue(forKey: model.id)
                }
                return
            }
            
            guard let location = location else { return }
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)
                
                DispatchQueue.main.async {
                    self.downloadTasks.removeValue(forKey: model.id)
                    self.checkDownloadedModels()
                }
            } catch {
                print("File error: \(error)")
                DispatchQueue.main.async {
                    self.downloadTasks.removeValue(forKey: model.id)
                }
            }
        }
        
        // Create download task
        let task = DownloadTask(task: downloadTask, progress: 0)
        downloadTasks[model.id] = task
        
        // Observe progress
        let observation = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.downloadTasks[model.id]?.progress = progress.fractionCompleted
            }
        }
        
        downloadTask.resume()
    }
    
    func cancelDownload(for model: VLMModel) {
        downloadTasks[model.id]?.task.cancel()
        downloadTasks.removeValue(forKey: model.id)
    }
    
    func deleteModel(_ model: VLMModel) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent(model.filename)
        
        do {
            try FileManager.default.removeItem(at: modelPath)
            checkDownloadedModels()
        } catch {
            print("Delete error: \(error)")
        }
    }
    
    func activateModel(_ model: VLMModel) {
        UserDefaults.standard.set(model.filename, forKey: "activeVLMModel")
        activeModelID = model.id
        
        // Notify VLMService to load the new model
        Task {
            await VLMService.shared.loadModel()
        }
    }
    
    private func updateStorageUsed() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var totalSize: Int64 = 0
        
        for model in downloadedModels {
            let modelPath = documentsPath.appendingPathComponent(model.filename)
            if let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        totalStorageUsed = formatter.string(fromByteCount: totalSize)
    }
}