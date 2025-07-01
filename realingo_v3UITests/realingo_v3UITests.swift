//
//  realingo_v3UITests.swift
//  realingo_v3UITests
//
//  Created by 西田直人 on 3/9/25.
//

import XCTest

final class realingo_v3UITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testMainMenuNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // メインメニューが表示されることを確認
        XCTAssertTrue(app.navigationBars["Realingo"].exists)
        
        // 言語変更ボタンが存在することを確認
        XCTAssertTrue(app.buttons["変更"].exists)
        
        // 学習モードのセクションが存在することを確認
        XCTAssertTrue(app.staticTexts["学習モードを選択"].exists)
        XCTAssertTrue(app.staticTexts["即時モード"].exists)
        XCTAssertTrue(app.staticTexts["レミニセンスモード"].exists)
    }
    
    @MainActor
    func testLanguageSelection() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 言語変更ボタンをタップ
        app.buttons["変更"].tap()
        
        // 言語選択画面が表示されることを確認
        XCTAssertTrue(app.navigationBars["言語設定"].exists)
        XCTAssertTrue(app.staticTexts["母国語を選択"].exists)
        XCTAssertTrue(app.staticTexts["学習したい言語を選択"].exists)
        
        // 言語オプションが表示されることを確認
        XCTAssertTrue(app.staticTexts["日本語"].exists)
        XCTAssertTrue(app.staticTexts["English"].exists)
        XCTAssertTrue(app.staticTexts["Suomi"].exists)
        
        // キャンセルボタンをタップ
        app.buttons["キャンセル"].tap()
        
        // メインメニューに戻ることを確認
        XCTAssertTrue(app.navigationBars["Realingo"].exists)
    }
    
    @MainActor
    func testProblemTypeSelection() throws {
        let app = XCUIApplication()
        app.launch()
        
        // 単語並べ替えボタンをタップ
        let wordArrangementButton = app.buttons["単語並べ替え"]
        XCTAssertTrue(wordArrangementButton.exists)
        wordArrangementButton.tap()
        
        // 問題画面に遷移することを確認（ContentViewのタイトルを確認）
        // 実際のタイトルに応じて調整が必要
        XCTAssertTrue(app.navigationBars.element.exists)
    }
    
    @MainActor
    func testCameraButtonExists() throws {
        let app = XCUIApplication()
        app.launch()
        
        // カメラで撮影ボタンが存在することを確認
        let cameraButton = app.buttons["カメラで撮影"]
        XCTAssertTrue(cameraButton.exists)
        
        // ボタンの説明文が存在することを確認
        XCTAssertTrue(app.staticTexts["写真を撮って問題を作成"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
