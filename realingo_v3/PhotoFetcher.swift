//
//  PhotoFetcher.swift
//  realingo_v3
//
//  Created by 西田直人 on 3/9/25.
//


import Photos

class PhotoFetcher {
    static let shared = PhotoFetcher()
    private init() {}

    func fetchRandomCameraPhoto() -> PHAsset? {
        // 対象とする過去の日付オフセットを配列化
        let intervals: [TimeInterval] = [
            -1 * 24 * 60 * 60,            // 1日前
            -3 * 24 * 60 * 60,            // 3日前
            -7 * 24 * 60 * 60,            // 1週間前
            -30 * 24 * 60 * 60,           // 1ヶ月前(ざっくり)
            -180 * 24 * 60 * 60,          // 半年前
            -365 * 24 * 60 * 60,          // 1年前
            -365 * 2 * 24 * 60 * 60,      // 2年前
            -365 * 3 * 24 * 60 * 60,      // 3年前
            -365 * 4 * 24 * 60 * 60,      // 4年前
            -365 * 5 * 24 * 60 * 60,      // 5年前
        ]
        
        // ランダムに1つのオフセットを選ぶ
        guard let chosenInterval = intervals.randomElement() else { return nil }
        
        let targetDate = Date().addingTimeInterval(chosenInterval)
        
        // 前後1日程度の幅を持たせるとか 〜±1日の範囲とする
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", argumentArray: [startOfDay, endOfDay])
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        if assets.count == 0 {
            return nil
        }
        
        // スクリーンショットを除外したい場合、さらに `mediaSubtypes != .photoScreenshot` などでフィルタする
        // ただし PhotoKit の mediaSubtypes に .photoScreenshot が含まれるかで判定
        var cameraAssets: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            // カメラ写真だけを判定 (mediaSubtypes)
            // .photoPanorama, .photoHDR, .photoScreenshot, ...
            if !asset.mediaSubtypes.contains(.photoScreenshot) {
                cameraAssets.append(asset)
            }
        }
        
        guard !cameraAssets.isEmpty else {
            return nil
        }
        
        // ランダムに1枚返す
        return cameraAssets.randomElement()
    }
}
