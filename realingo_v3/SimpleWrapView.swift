//
//  SimpleWrapView.swift
//  realingo_v3
//
//  シンプルな単語ラップ表示用View
//

import SwiftUI

struct SimpleWrapView: View {
    let words: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(groupedWords(), id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { word in
                        Button(action: {
                            onTap(word)
                        }) {
                            Text(word)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private func groupedWords() -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentWidth: CGFloat = 0
        let maxWidth: CGFloat = UIScreen.main.bounds.width - 80 // より多めのマージンを確保
        let spacing: CGFloat = 10
        
        for word in words {
            // 単語の推定幅（より保守的に計算）
            // キリル文字は幅が広いので、より大きめに見積もる
            let charWidth: CGFloat = word.contains(where: { $0.isCyrillic }) ? 18 : 14
            let wordWidth = CGFloat(word.count) * charWidth + 32 // パディング込み
            
            if currentWidth > 0 && currentWidth + wordWidth + spacing > maxWidth {
                // 新しい行へ
                rows.append(currentRow)
                currentRow = [word]
                currentWidth = wordWidth
            } else {
                currentRow.append(word)
                currentWidth += wordWidth + spacing
            }
        }
        
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
}

extension Character {
    var isCyrillic: Bool {
        let scalar = String(self).unicodeScalars.first!
        return (0x0400...0x04FF).contains(Int(scalar.value))
    }
}

#Preview {
    SimpleWrapView(words: ["это", "красивая", "картина", "на", "стене"]) { word in
        print("Tapped: \(word)")
    }
}