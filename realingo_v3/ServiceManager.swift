//
//  ServiceManager.swift
//  realingo_v3
//
//  Created by 西田直人 on 3/9/25.
//


import Foundation
import FirebaseCore
import FirebaseFirestore
import Photos
import AVFoundation
import SwiftUI

class ServiceManager: ObservableObject {
    static let shared = ServiceManager()
    private init() {}
    
    // MARK: - Configuration
    let cloudinaryCloudName = "dy53z9iup"
    let cloudinaryPreset = "ml_default"
    let cloudinaryUploadPreset = "ml_default"
    
    // MARK: - Cloudinary Upload
    
    func uploadToCloudinary(imageData: Data, preset: String, cloudName: String, completion: @escaping (String?) -> Void) {
        let uploadUrl = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"
        guard let url = URL(string: uploadUrl) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // POST body
        var body = Data()
        // upload_preset
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(preset)\r\n".data(using: .utf8)!)
        
        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // end
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            guard let data = data, err == nil else {
                completion(nil)
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let url = json["secure_url"] as? String {
                    completion(url)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - Firebase Problem Save
    
    func saveProblemToFirebase(_ quiz: Quiz, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let docRef = db.collection("problems").document(quiz.problemID)
        
        do {
            let dict = try JSONEncoder().encode(quiz)
            if let json = try JSONSerialization.jsonObject(with: dict) as? [String: Any] {
                docRef.setData(json) { err in
                    DispatchQueue.main.async {
                        if let err = err {
                            print("Failed to save problem: \(err)")
                            completion(false)
                        } else {
                            completion(true)
                        }
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    // 研究モードで "A" が作ったデータを読み取る
    func fetchProblemsFromFirebase(group: String, completion: @escaping ([Quiz]) -> Void) {
        let db = Firestore.firestore()
        db.collection("problems")
            .whereField("createdByGroup", isEqualTo: group)
            .getDocuments { snapshot, err in
                var quizzes: [Quiz] = []
                if let docs = snapshot?.documents {
                    for doc in docs {
                        if let quizObj = self.decodeQuiz(from: doc.data()) {
                            quizzes.append(quizObj)
                        }
                    }
                }
                completion(quizzes)
            }
    }
    
    private func decodeQuiz(from dict: [String: Any]) -> Quiz? {
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: [])
            let quiz = try JSONDecoder().decode(Quiz.self, from: data)
            return quiz
        } catch {
            return nil
        }
    }
    
    // MARK: - Log保存
    func saveProblemLogToFirebase(_ log: ProblemLog) {
        let db = Firestore.firestore()
        let docRef = db.collection("answers").document(log.logID)
        
        do {
            let data = try JSONEncoder().encode(log)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                docRef.setData(dict) { err in
                    if let err = err {
                        print("Failed to save log: \(err)")
                    }
                }
            }
        } catch {
            print("Failed to encode ProblemLog")
        }
    }
    
    // ローカル(CSV/JSON)に保存する例
    func saveLogToLocal(_ log: ProblemLog) {
        // Documents配下に "answers_{participantID}.json" を追記する
        let filename = "answers_\(log.participantID).json"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        
        var existing: [ProblemLog] = []
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([ProblemLog].self, from: data) {
            existing = decoded
        }
        existing.append(log)
        
        if let newData = try? JSONEncoder().encode(existing) {
            try? newData.write(to: fileURL)
            print("Saved log locally at: \(fileURL)")
        }
    }
    
    // MARK: - テキスト読み上げ(発音)
    func speakFinnish(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fi-FI")
        let synth = AVSpeechSynthesizer()
        synth.speak(utterance)
    }
}
