//
//  LanguageSelectionView.swift
//  realingo_v3
//
//  言語選択画面
//  参照: specification.md - 多言語対応（8言語）
//  関連: ContentView.swift (メイン画面), Models.swift (SupportedLanguage)
//

import SwiftUI

struct LanguageSelectionView: View {
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = SupportedLanguage.finnish.rawValue
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @Binding var showLanguageSelection: Bool
    
    var selectedLanguage: SupportedLanguage {
        get { SupportedLanguage(rawValue: selectedLanguageRaw) ?? .finnish }
        set { selectedLanguageRaw = newValue.rawValue }
    }
    
    var nativeLanguage: SupportedLanguage {
        get { SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese }
        set { nativeLanguageRaw = newValue.rawValue }
    }
    
    @State private var temporarySelectedLanguage: SupportedLanguage = .finnish
    @State private var temporaryNativeLanguage: SupportedLanguage = .japanese
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // ネイティブ言語選択
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizationHelper.getCommonText("selectNativeLanguage", for: temporaryNativeLanguage))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                            ForEach(SupportedLanguage.allCases, id: \.self) { language in
                                LanguageCard(
                                    language: language,
                                    isSelected: temporaryNativeLanguage == language,
                                    action: {
                                        temporaryNativeLanguage = language
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
                
                Divider()
                
                // 学習言語選択
                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizationHelper.getCommonText("selectLearningLanguage", for: temporaryNativeLanguage))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                            ForEach(SupportedLanguage.allCases.filter { $0 != temporaryNativeLanguage }, id: \.self) { language in
                                LanguageCard(
                                    language: language,
                                    isSelected: temporarySelectedLanguage == language,
                                    action: {
                                        temporarySelectedLanguage = language
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // 確定ボタン
                Button(action: {
                    selectedLanguageRaw = temporarySelectedLanguage.rawValue
                    nativeLanguageRaw = temporaryNativeLanguage.rawValue
                    showLanguageSelection = false
                }) {
                    Text(LocalizationHelper.getCommonText("setLanguage", for: temporaryNativeLanguage))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .navigationTitle(LocalizationHelper.getCommonText("languageSettings", for: temporaryNativeLanguage))
            .navigationBarItems(trailing: Button(LocalizationHelper.getCommonText("cancel", for: temporaryNativeLanguage)) {
                showLanguageSelection = false
            })
            .onAppear {
                temporarySelectedLanguage = selectedLanguage
                temporaryNativeLanguage = nativeLanguage
            }
        }
    }
}

struct LanguageCard: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: 40))
                
                Text(language.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LanguageSelectionView(showLanguageSelection: .constant(true))
}