//
//  ConsentView.swift
//  realingo_v3
//
//  研究参加同意画面
//

import SwiftUI

struct ConsentView: View {
    @Binding var isPresented: Bool
    @State private var hasReadTerms = false
    @State private var agreeToParticipate = false
    @State private var agreeToDataCollection = false
    @State private var participantID = ""
    @State private var groupID = ""
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ヘッダー
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("研究参加への同意")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Realingo言語学習アプリ研究プロジェクト")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // 研究概要
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "研究の目的", icon: "target")
                        
                        Text("""
                        本研究は、画像を活用した言語学習の効果を測定し、より効果的な言語学習方法の開発を目的としています。特に以下の点を調査します：
                        
                        • 視覚情報（画像）と言語学習の関連性
                        • 学習者のエンゲージメントパターン
                        • 異なる問題形式による学習効果の違い
                        • 記憶定着率の向上要因
                        """)
                        .font(.body)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // データ収集について
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "収集するデータ", icon: "chart.bar.doc.horizontal")
                        
                        DataCollectionItem(
                            title: "学習データ",
                            items: [
                                "回答内容と正誤",
                                "回答時間",
                                "問題の種類と難易度",
                                "学習言語と母国語"
                            ]
                        )
                        
                        DataCollectionItem(
                            title: "使用パターン",
                            items: [
                                "アプリ使用時間",
                                "学習頻度",
                                "機能の使用状況",
                                "学習時間帯"
                            ]
                        )
                        
                        DataCollectionItem(
                            title: "画像データ",
                            items: [
                                "アップロードされた画像",
                                "画像から生成された問題",
                                "画像の選択パターン"
                            ]
                        )
                    }
                    
                    // プライバシー保護
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "プライバシー保護", icon: "lock.shield")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            PrivacyPoint(text: "個人を特定できる情報は収集しません")
                            PrivacyPoint(text: "データは参加者IDで匿名化されます")
                            PrivacyPoint(text: "データは研究目的のみに使用されます")
                            PrivacyPoint(text: "いつでも研究参加を中止できます")
                            PrivacyPoint(text: "データの削除を要求できます")
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button(action: { showingPrivacyPolicy = true }) {
                            Label("プライバシーポリシーを読む", systemImage: "doc.text")
                                .font(.caption)
                        }
                    }
                    
                    // 参加者情報
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "参加者情報", icon: "person.fill")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("参加者ID", text: $participantID)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("グループID（A または B）", text: $groupID)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.allCharacters)
                            
                            Text("※ これらのIDは研究責任者から提供されます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 同意チェックボックス
                    VStack(alignment: .leading, spacing: 16) {
                        ConsentCheckbox(
                            isChecked: $hasReadTerms,
                            text: "上記の内容を読み、理解しました"
                        )
                        
                        ConsentCheckbox(
                            isChecked: $agreeToParticipate,
                            text: "研究への参加に同意します"
                        )
                        
                        ConsentCheckbox(
                            isChecked: $agreeToDataCollection,
                            text: "データの収集と分析に同意します"
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // アクションボタン
                    HStack(spacing: 16) {
                        Button(action: decline) {
                            Text("同意しない")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        Button(action: accept) {
                            Text("同意して参加")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canProceed ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(!canProceed)
                    }
                }
                .padding()
            }
            .navigationBarTitle("研究参加同意", displayMode: .inline)
            .navigationBarItems(
                trailing: Button("キャンセル") { isPresented = false }
            )
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }
    
    private var canProceed: Bool {
        hasReadTerms && 
        agreeToParticipate && 
        agreeToDataCollection && 
        !participantID.isEmpty && 
        (groupID == "A" || groupID == "B")
    }
    
    private func accept() {
        // 同意情報を保存
        UserDefaults.standard.set(true, forKey: "researchConsentGiven")
        UserDefaults.standard.set(participantID, forKey: "participantID")
        UserDefaults.standard.set(groupID, forKey: "groupID")
        UserDefaults.standard.set(Date(), forKey: "consentDate")
        UserDefaults.standard.set(true, forKey: "isResearchMode")
        
        // プロファイルを更新
        Task {
            if let userID = UserDefaults.standard.string(forKey: "currentUserID") {
                do {
                    var profile = try await DataPersistenceManager.shared.getUserProfile(participantID: userID)
                    profile?.participantID = participantID
                    profile?.groupID = groupID
                    profile?.consentGiven = true
                    if let profile = profile {
                        try await DataPersistenceManager.shared.saveUserProfile(profile)
                    }
                } catch {
                    print("Failed to update profile: \(error)")
                }
            }
        }
        
        isPresented = false
    }
    
    private func decline() {
        UserDefaults.standard.set(false, forKey: "isResearchMode")
        isPresented = false
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
        }
    }
}

struct DataCollectionItem: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .fontWeight(.semibold)
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct PrivacyPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct ConsentCheckbox: View {
    @Binding var isChecked: Bool
    let text: String
    
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .blue : .gray)
                    .font(.title3)
                
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("プライバシーポリシー")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("最終更新日: 2025年6月28日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    PolicySection(
                        title: "1. 収集する情報",
                        content: """
                        本アプリは以下の情報を収集します：
                        • 学習活動データ（回答、正誤、時間）
                        • アプリ使用統計（使用時間、頻度）
                        • アップロードされた画像
                        • デバイス情報（OS、アプリバージョン）
                        • 匿名化された参加者ID
                        """
                    )
                    
                    PolicySection(
                        title: "2. 情報の使用目的",
                        content: """
                        収集した情報は以下の目的で使用されます：
                        • 言語学習効果の研究
                        • アプリの改善
                        • 学習パターンの分析
                        • 研究論文の作成
                        """
                    )
                    
                    PolicySection(
                        title: "3. 情報の保護",
                        content: """
                        • すべてのデータは暗号化して保存されます
                        • 個人を特定できる情報は収集しません
                        • データへのアクセスは研究者のみに限定されます
                        • 業界標準のセキュリティ対策を実施しています
                        """
                    )
                    
                    PolicySection(
                        title: "4. データの保存期間",
                        content: """
                        • 研究データは研究終了後5年間保存されます
                        • その後、すべてのデータは安全に削除されます
                        • 参加者の要求により、いつでもデータを削除できます
                        """
                    )
                    
                    PolicySection(
                        title: "5. 参加者の権利",
                        content: """
                        参加者には以下の権利があります：
                        • データへのアクセス権
                        • データの修正権
                        • データの削除権
                        • 研究参加の中止権
                        • 質問や懸念事項の問い合わせ権
                        """
                    )
                    
                    PolicySection(
                        title: "6. お問い合わせ",
                        content: """
                        ご質問や懸念事項がございましたら、以下までご連絡ください：
                        
                        研究責任者: [研究者名]
                        所属: [大学/機関名]
                        メール: research@example.com
                        """
                    )
                }
                .padding()
            }
            .navigationBarTitle("プライバシーポリシー", displayMode: .inline)
            .navigationBarItems(trailing: Button("閉じる") { dismiss() })
        }
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ConsentView(isPresented: .constant(true))
}