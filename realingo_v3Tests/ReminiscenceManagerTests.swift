//
//  ReminiscenceManagerTests.swift
//  realingo_v3Tests
//
//  ReminiscenceManager の単体テスト
//

import Testing
import Foundation
import Photos
@testable import realingo_v3

struct ReminiscenceManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func reminiscenceManagerSingleton() {
        let manager1 = ReminiscenceManager.shared
        let manager2 = ReminiscenceManager.shared
        
        // シングルトンインスタンスが同一であることを確認
        #expect(manager1 === manager2)
    }
    
    // MARK: - TimeInterval Tests
    
    @Test func timeIntervalDescriptions() {
        #expect(ReminiscenceManager.TimeInterval.oneWeek.description == "1週間前")
        #expect(ReminiscenceManager.TimeInterval.oneMonth.description == "1ヶ月前")
        #expect(ReminiscenceManager.TimeInterval.sixMonths.description == "6ヶ月前")
        #expect(ReminiscenceManager.TimeInterval.oneYear.description == "1年前")
    }
    
    @Test func timeIntervalDateRanges() {
        let calendar = Calendar.current
        let today = Date()
        
        // 1週間前のテスト
        let oneWeekRange = ReminiscenceManager.TimeInterval.oneWeek.dateRange
        let expectedOneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let oneWeekDiff = abs(oneWeekRange.start.timeIntervalSince(
            calendar.date(byAdding: .day, value: -1, to: expectedOneWeekAgo)!
        ))
        #expect(oneWeekDiff < 86400) // 1日以内の差
        
        // 1ヶ月前のテスト
        let oneMonthRange = ReminiscenceManager.TimeInterval.oneMonth.dateRange
        let expectedOneMonthAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let oneMonthDiff = abs(oneMonthRange.start.timeIntervalSince(
            calendar.date(byAdding: .day, value: -1, to: expectedOneMonthAgo)!
        ))
        #expect(oneMonthDiff < 86400) // 1日以内の差
        
        // 6ヶ月前のテスト
        let sixMonthsRange = ReminiscenceManager.TimeInterval.sixMonths.dateRange
        let expectedSixMonthsAgo = calendar.date(byAdding: .day, value: -180, to: today)!
        let sixMonthsDiff = abs(sixMonthsRange.start.timeIntervalSince(
            calendar.date(byAdding: .day, value: -1, to: expectedSixMonthsAgo)!
        ))
        #expect(sixMonthsDiff < 86400) // 1日以内の差
        
        // 1年前のテスト
        let oneYearRange = ReminiscenceManager.TimeInterval.oneYear.dateRange
        let expectedOneYearAgo = calendar.date(byAdding: .day, value: -365, to: today)!
        let oneYearDiff = abs(oneYearRange.start.timeIntervalSince(
            calendar.date(byAdding: .day, value: -1, to: expectedOneYearAgo)!
        ))
        #expect(oneYearDiff < 86400) // 1日以内の差
    }
    
    // MARK: - Error Tests
    
    @Test func reminiscenceErrorDescriptions() {
        #expect(ReminiscenceManager.ReminiscenceError.photoAccessDenied.errorDescription == "写真へのアクセスが許可されていません")
        #expect(ReminiscenceManager.ReminiscenceError.imageProcessingFailed.errorDescription == "画像の処理に失敗しました")
        #expect(ReminiscenceManager.ReminiscenceError.networkError.errorDescription == "ネットワークエラーが発生しました")
    }
    
    // MARK: - CloudinaryResponse Tests
    
    @Test func cloudinaryResponseParsing() throws {
        let jsonString = """
        {
            "secure_url": "https://res.cloudinary.com/test/image/upload/v123/test.jpg"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(CloudinaryResponse.self, from: data)
        
        #expect(response.secure_url == "https://res.cloudinary.com/test/image/upload/v123/test.jpg")
    }
    
    // MARK: - Mock Tests
    
    @Test func mockPhotoAssetProcessing() {
        // 実際のPhotos frameworkの機能はテストできないため、ロジックのみテスト
        let intervals = ReminiscenceManager.TimeInterval.allCases
        
        #expect(intervals.count == 4)
        #expect(intervals.contains(.oneWeek))
        #expect(intervals.contains(.oneMonth))
        #expect(intervals.contains(.sixMonths))
        #expect(intervals.contains(.oneYear))
    }
    
    @Test func notificationSchedulingLogic() {
        // UserDefaultsを使った通知スケジューリングのテスト
        let problemID = "test-problem-123"
        let key = "notified-\(problemID)"
        
        // 初期状態
        UserDefaults.standard.removeObject(forKey: key)
        #expect(UserDefaults.standard.bool(forKey: key) == false)
        
        // 通知済みとしてマーク
        UserDefaults.standard.set(true, forKey: key)
        #expect(UserDefaults.standard.bool(forKey: key) == true)
        
        // クリーンアップ
        UserDefaults.standard.removeObject(forKey: key)
    }
}