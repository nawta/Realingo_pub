//
//  WrapLayoutView.swift
//  realingo_v3
//
//  Created by 西田直人 on 3/14/25.
//


import SwiftUI

struct WrapLayoutView<Item, ItemView>: View where ItemView: View {
    let items: [Item]
    let viewForItem: (Item) -> ItemView
    
    @State private var totalHeight: CGFloat = .zero
    
    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(minHeight: max(totalHeight, 50))
    }
    
    func generateContent(in g: GeometryProxy) -> some View {
        var widthAccumulator: CGFloat = 0
        var heightAccumulator: CGFloat = 0
        var maxHeight: CGFloat = 0
        let spacing: CGFloat = 8
        let maxWidth = g.size.width
        
        return ZStack(alignment: .topLeading) {
            ForEach(items.indices, id: \.self) { i in
                self.viewForItem(items[i])
                    .alignmentGuide(.leading) { d in
                        // 現在の行に収まらない場合は次の行へ
                        if widthAccumulator > 0 && (widthAccumulator + d.width) > maxWidth {
                            widthAccumulator = 0
                            heightAccumulator += d.height + spacing
                        }
                        let result = widthAccumulator
                        widthAccumulator += d.width + spacing
                        if i == items.count - 1 {
                            maxHeight = heightAccumulator + d.height
                        }
                        return -result  // 符号を反転
                    }
                    .alignmentGuide(.top) { d in
                        let result = heightAccumulator
                        return -result  // 符号を反転
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
        .onAppear {
            // 初期の高さを設定
            DispatchQueue.main.async {
                self.totalHeight = maxHeight
            }
        }
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    binding.wrappedValue = geometry.size.height
                }
                .onChange(of: geometry.size.height) { _, newHeight in
                    binding.wrappedValue = newHeight
                }
        }
    }
}
