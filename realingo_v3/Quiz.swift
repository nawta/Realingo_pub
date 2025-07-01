//
//  Quiz.swift
//  realingo_v3
//
//  Created by 西田直人 on 3/9/25.
//


import Foundation

/// 問題情報
struct Quiz: Codable, Identifiable {
    var id: String { problemID } // SwiftUIのForEachなどで使いやすいように
    let problemID: String
    
    // 問題文
    let question: String     // ex) "Arrange the Finnish sentence..."
    let answer: String       // ex) "Tämä on kissa ikkunan vieressä"
    
    // 画像URL (オプション)
    var imageUrl: String?
    
    // 解説
    let explanation: [String: String]?
    
    // ボキャブラリ問題用の選択肢 or 並べ替え用の単語リスト
    // 必要に応じて
    var options: [String]?
    let problemType: String  // "vocabulary" or "sentence" etc
    
    // どのグループが作成したか
    let createdByGroup: String
    let createdByParticipant: String
}

/// 回答ログ
struct ProblemLog: Codable, Identifiable {
    var id: String { logID }
    let logID: String
    let problemID: String
    
    let participantID: String  // 回答者
    let groupID: String        // 回答者のグループ
    let imageUrl: String?
    let question: String
    let correctAnswer: String
    let userAnswer: String
    let isCorrect: Bool
    
    let timestamp: Double   // timeIntervalSince1970
}
