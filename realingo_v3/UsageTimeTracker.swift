//
//  UsageTimeTracker.swift
//  realingo_v3
//
//  Created by 西田直人 on 3/14/25.
//


//
//  UsageTimeTracker.swift
//  realingo_v3
//
//  Created by Nishida on 3/9/25.
//

import Foundation
import Firebase
import FirebaseFirestore

/// アプリの滞在時間を計測し、1日ごとに送信するクラス
class UsageTimeTracker: ObservableObject {
    
    // 1日の累計使用時間(秒)
    @Published var dailyUsageSeconds: Double = 0
    
    // アプリがアクティブになった時刻
    private var lastActive: Date?
    
    // 端末日付が変わったかどうかを判定するために保存しておく
    private var currentDayString: String = UsageTimeTracker.dayString(from: Date())
    
    // ユーザID (Firebaseへの送信時に使う)
    var userID: String = "0"
    
    /// アプリがActiveになったタイミング
    func appDidBecomeActive() {
        // もし日付が変わっていたら、一旦前日の使用を送信する
        startNewDayIfNeeded()
        
        lastActive = Date()
    }
    
    /// アプリがInactive/Backgroundになるタイミング
    func appWillResignActive() {
        guard let la = lastActive else { return }
        let diff = Date().timeIntervalSince(la)
        dailyUsageSeconds += diff
        lastActive = nil
        // ここではまだ送信せず、日付が切り替わった時などにまとめて送る
    }
    
    /// 日付が変わっていれば前日のログをFirebaseに送信し、カウンターをリセット
    func startNewDayIfNeeded() {
        let nowDay = UsageTimeTracker.dayString(from: Date())
        if nowDay != currentDayString {
            // 日付が変わった → 前日分を送信
            uploadDailyUsage(dateString: currentDayString)
            
            // リセット
            dailyUsageSeconds = 0
            currentDayString = nowDay
        }
    }
    
    /// 1日ぶんの使用時間を Firebase にアップロード
    private func uploadDailyUsage(dateString: String) {
        let db = Firestore.firestore()
        
        // ユーザIDが設定されていないなら何もしない
        if userID.isEmpty { return }
        
        // "dailyUsage" コレクションに dateString+userID をキーとして書き込む
        let docID = "\(dateString)_\(userID)"
        let data: [String: Any] = [
            "userID": userID,
            "dateString": dateString,
            "usageSeconds": dailyUsageSeconds,
            "uploadedAt": Date().timeIntervalSince1970
        ]
        
        db.collection("dailyUsage").document(docID).setData(data) { err in
            if let err = err {
                print("Failed to upload daily usage for \(docID): \(err)")
            } else {
                print("Daily usage uploaded for \(docID). usageSeconds=\(self.dailyUsageSeconds)")
            }
        }
    }
    
    /// ユーザフレンドリな形式ではなくYYYYMMDD形式で日付を取得
    static func dayString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        return df.string(from: date)
    }
}
