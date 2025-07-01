//
//  VLMModels.swift
//  realingo_v3
//
//  VLM関連の共通モデル定義
//

import Foundation

// VLM Model data structure
struct VLMModel: Identifiable, Hashable {
    let id: String
    let name: String
    let filename: String
    let url: String
    let size: String
    let description: String
    
    // Optional projection model properties
    var projectionModelURL: String?
    var projectionModelFilename: String?
    var requiresVisionTower: Bool = false
    var clipModelURL: String?
    var clipModelFilename: String?
    
    // For compatibility with existing code
    var displayName: String {
        return name
    }
    
    var downloadURL: String {
        return url
    }
}