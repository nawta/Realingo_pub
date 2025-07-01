//
//  AudioInputView.swift
//  realingo_v3
//
//  音声入力モードのUI
//  日常会話の録音を文字起こしして学習素材にする
//

import SwiftUI
import Speech
import AVFoundation
import UniformTypeIdentifiers

struct AudioInputView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var transcribedText = ""
    @State private var showingScriptMode = false
    @State private var errorMessage: String?
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingLanguagePicker = false
    @State private var showingFileImporter = false
    @State private var transcriptionLanguage: SupportedLanguage = .finnish
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    private var selectedLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 言語選択
                VStack(alignment: .leading, spacing: 10) {
                    Text("音声認識言語")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showingLanguagePicker = true
                    }) {
                        HStack {
                            Text(transcriptionLanguage.flag)
                            Text(transcriptionLanguage.displayName)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .foregroundColor(.primary)
                    
                    Text("録音した音声は\(transcriptionLanguage.displayName)として文字起こしされます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // 入力方法選択
                HStack(spacing: 16) {
                    // ファイル読み込みボタン
                    Button(action: {
                        showingFileImporter = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("ファイル")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.green)
                        .cornerRadius(20)
                    }
                    
                    Text("または")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("録音")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 録音ボタン
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 150, height: 150)
                    
                    if isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 8)
                            .frame(width: 150, height: 150)
                            .scaleEffect(1.2)
                            .opacity(0.7)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: isRecording
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        
                        if isRecording {
                            Text(formatTime(recordingTime))
                                .font(.caption)
                                .foregroundColor(.white)
                        } else {
                            Text(LocalizationHelper.getCommonText("tapToRecord", for: nativeLanguage))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                .onTapGesture {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .disabled(isTranscribing)
                
                // 文字起こし結果
                if !transcribedText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizationHelper.getCommonText("transcriptionResult", for: nativeLanguage))
                            .font(.headline)
                        
                        ScrollView {
                            Text(transcribedText)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .frame(maxHeight: 200)
                        
                        Button(action: {
                            showingScriptMode = true
                        }) {
                            Label(LocalizationHelper.getCommonText("proceedToLearning", for: nativeLanguage), 
                                  systemImage: "arrow.right.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // プログレス表示
                if isTranscribing {
                    ProgressView(LocalizationHelper.getCommonText("transcribing", for: nativeLanguage))
                        .padding()
                }
            }
            .navigationTitle(LocalizationHelper.getCommonText("audioInputMode", for: nativeLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .alert(LocalizationHelper.getCommonText("error", for: nativeLanguage), 
                   isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView(selectedLanguage: $transcriptionLanguage)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        transcribeAudioFile(url: url)
                    }
                case .failure(let error):
                    errorMessage = "ファイル読み込みエラー: \(error.localizedDescription)"
                }
            }
            .sheet(isPresented: $showingScriptMode) {
                ScriptModeView(scriptText: transcribedText, sourceType: .audio)
            }
        }
    }
    
    private func startRecording() {
        requestPermissions { granted in
            if granted {
                isRecording = true
                recordingTime = 0
                audioRecorder.startRecording()
                
                // タイマー開始
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    recordingTime += 0.1
                }
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        guard let audioURL = audioRecorder.stopRecording() else {
            errorMessage = "録音の保存に失敗しました"
            return
        }
        
        isTranscribing = true
        transcribeAudio(url: audioURL)
    }
    
    private func transcribeAudio(url: URL) {
        let recognizer = SFSpeechRecognizer(locale: transcriptionLanguage.locale)
        let request = SFSpeechURLRecognitionRequest(url: url)
        
        recognizer?.recognitionTask(with: request) { result, error in
            DispatchQueue.main.async {
                isTranscribing = false
                
                if let error = error {
                    errorMessage = "文字起こしエラー: \(error.localizedDescription)"
                    return
                }
                
                if let result = result {
                    transcribedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        // 文字起こし完了時に効果音
                        SoundEffectManager.shared.playAchievementSound()
                    }
                }
            }
        }
    }
    
    private func transcribeAudioFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "ファイルへのアクセスが拒否されました"
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        isTranscribing = true
        transcribeAudio(url: url)
    }
    
    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        completion(status == .authorized)
                        if status != .authorized {
                            errorMessage = "音声認識の権限が必要です"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "マイクへのアクセスが必要です"
                    completion(false)
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Recorder

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioRecorder] Failed to setup audio session: \(error)")
        }
    }
    
    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = documentsPath.appendingPathComponent(fileName)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
        } catch {
            print("[AudioRecorder] Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        return recordingURL
    }
}

// MARK: - Language Picker View

struct LanguagePickerView: View {
    @Binding var selectedLanguage: SupportedLanguage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(SupportedLanguage.allCases, id: \.self) { language in
                Button(action: {
                    selectedLanguage = language
                    dismiss()
                }) {
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                        Spacer()
                        if selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("音声認識言語")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AudioInputView()
}