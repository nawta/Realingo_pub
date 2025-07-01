//
//  ReviewView.swift
//  realingo_v3
//
//  学習履歴の復習画面
//  問題、画像、ユーザーの回答、正答を表示
//

import SwiftUI

struct ReviewView: View {
    @StateObject private var viewModel = ReviewViewModel()
    @State private var selectedFilter: ReviewFilter = .all
    @State private var showingDetail: ExtendedProblemLog?
    
    enum ReviewFilter: String, CaseIterable {
        case all = "すべて"
        case correct = "正解"
        case incorrect = "不正解"
        case recent = "最近"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .correct: return "checkmark.circle.fill"
            case .incorrect: return "xmark.circle.fill"
            case .recent: return "clock.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .correct: return .green
            case .incorrect: return .red
            case .recent: return .orange
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 統計ヘッダー
                statsHeader
                
                // フィルターセグメント
                filterSegment
                
                // 問題リスト
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredLogs.isEmpty {
                    emptyState
                } else {
                    reviewList
                }
            }
            .navigationTitle("学習履歴")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.exportReviewData() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(item: $showingDetail) { log in
                ReviewDetailView(log: log)
            }
        }
        .onAppear {
            viewModel.loadReviewData()
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        HStack(spacing: 20) {
            StatCard(
                title: "ストリーク",
                value: "\(viewModel.currentStreak)",
                unit: "日",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "総正解率",
                value: String(format: "%.1f", viewModel.overallAccuracy * 100),
                unit: "%",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            
            StatCard(
                title: "エンゲージメント",
                value: String(format: "%.1f", viewModel.engagementRate * 100),
                unit: "%",
                icon: "person.fill.checkmark",
                color: .blue
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Filter Segment
    
    private var filterSegment: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ReviewFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - Review List
    
    private var reviewList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredLogs) { log in
                    ReviewCard(log: log) {
                        showingDetail = log
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("学習履歴がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("問題を解いて学習を始めましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var filteredLogs: [ExtendedProblemLog] {
        switch selectedFilter {
        case .all:
            return viewModel.problemLogs
        case .correct:
            return viewModel.problemLogs.filter { $0.isCorrect }
        case .incorrect:
            return viewModel.problemLogs.filter { !$0.isCorrect }
        case .recent:
            let oneDayAgo = Date().addingTimeInterval(-86400)
            return viewModel.problemLogs.filter { $0.completedAt > oneDayAgo }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let filter: ReviewView.ReviewFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? filter.color : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct ReviewCard: View {
    let log: ExtendedProblemLog
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // ヘッダー
                HStack {
                    Label(log.problemType.displayName, systemImage: getProblemTypeIcon(log.problemType))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: log.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(log.isCorrect ? .green : .red)
                        Text(log.isCorrect ? "正解" : "不正解")
                            .font(.caption)
                            .foregroundColor(log.isCorrect ? .green : .red)
                    }
                }
                
                // 問題内容
                Text(log.question)
                    .font(.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 回答情報
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("あなたの回答:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(log.userAnswer)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        if !log.isCorrect {
                            HStack {
                                Text("正解:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(log.correctAnswer)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 画像サムネイル
                    if let imageUrl = log.imageUrl {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                
                // フッター
                HStack {
                    Text(formatDate(log.completedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(log.timeSpentSeconds)秒")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getProblemTypeIcon(_ type: ProblemType) -> String {
        switch type {
        case .wordArrangement: return "arrow.left.arrow.right"
        case .fillInTheBlank: return "square.and.pencil"
        case .speaking: return "mic.fill"
        case .writing: return "pencil.and.scribble"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Review Detail View

struct ReviewDetailView: View {
    let log: ExtendedProblemLog
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 画像
                    if let imageUrl = log.imageUrl {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(12)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 300)
                                .overlay(
                                    ProgressView()
                                )
                        }
                    }
                    
                    // 問題情報
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(label: "問題タイプ", value: log.problemType.displayName)
                        DetailRow(label: "言語", value: log.language.displayName)
                        DetailRow(label: "問題", value: log.question)
                        
                        Divider()
                        
                        // 回答情報
                        DetailRow(
                            label: "あなたの回答",
                            value: log.userAnswer,
                            valueColor: log.isCorrect ? .green : .primary
                        )
                        
                        if !log.isCorrect {
                            DetailRow(
                                label: "正解",
                                value: log.correctAnswer,
                                valueColor: .green
                            )
                        }
                        
                        DetailRow(
                            label: "結果",
                            value: log.isCorrect ? "正解" : "不正解",
                            valueColor: log.isCorrect ? .green : .red
                        )
                        
                        Divider()
                        
                        // メタデータ
                        DetailRow(label: "回答時間", value: "\(log.timeSpentSeconds)秒")
                        DetailRow(label: "日時", value: formatDateTime(log.completedAt))
                        
                        if let vlmFeedbackString = log.vlmFeedback {
                            Divider()
                            VStack(alignment: .leading, spacing: 12) {
                                Text("AIフィードバック")
                                    .font(.headline)
                                Text(vlmFeedbackString)
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .foregroundColor(valueColor)
        }
    }
}


// MARK: - View Model

class ReviewViewModel: ObservableObject {
    @Published var problemLogs: [ExtendedProblemLog] = []
    @Published var isLoading = false
    @Published var currentStreak = 0
    @Published var overallAccuracy = 0.0
    @Published var engagementRate = 0.0
    
    func loadReviewData() {
        isLoading = true
        
        Task {
            do {
                let userID = UserDefaults.standard.string(forKey: "currentUserID") ?? ""
                
                // 問題ログを取得
                problemLogs = try await DataPersistenceManager.shared.fetchUserLogs(
                    participantID: userID,
                    limit: 100
                )
                
                // 統計を計算
                calculateStats()
                
                isLoading = false
            } catch {
                print("Failed to load review data: \(error)")
                isLoading = false
            }
        }
    }
    
    private func calculateStats() {
        // ストリーク計算
        currentStreak = calculateCurrentStreak()
        
        // 正解率計算
        if !problemLogs.isEmpty {
            let correctCount = problemLogs.filter { $0.isCorrect }.count
            overallAccuracy = Double(correctCount) / Double(problemLogs.count)
        }
        
        // エンゲージメント率計算（簡易版）
        engagementRate = calculateEngagementRate()
    }
    
    private func calculateCurrentStreak() -> Int {
        // UserDefaultsから取得（実際はDataPersistenceManagerから）
        return UserDefaults.standard.integer(forKey: "currentStreak")
    }
    
    private func calculateEngagementRate() -> Double {
        // 過去7日間のアクティブ率を計算（簡易版）
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400)
        let recentLogs = problemLogs.filter { $0.completedAt > sevenDaysAgo }
        
        // 少なくとも1日1問解いていれば100%
        let uniqueDays = Set(recentLogs.map { Calendar.current.startOfDay(for: $0.completedAt) })
        return Double(uniqueDays.count) / 7.0
    }
    
    func exportReviewData() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            // エクスポート用データ構造
            let exportData = ReviewExportData(
                exportDate: Date(),
                participantID: UserDefaults.standard.string(forKey: "participantID") ?? "",
                groupID: UserDefaults.standard.string(forKey: "groupID") ?? "",
                statistics: ReviewStatistics(
                    totalProblems: problemLogs.count,
                    correctAnswers: problemLogs.filter { $0.isCorrect }.count,
                    overallAccuracy: overallAccuracy,
                    currentStreak: currentStreak,
                    engagementRate: engagementRate
                ),
                problemLogs: problemLogs
            )
            
            let jsonData = try encoder.encode(exportData)
            
            // ファイルに保存
            let fileName = "review_export_\(Date().timeIntervalSince1970).json"
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            // 共有
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            
        } catch {
            print("Failed to export data: \(error)")
        }
    }
}

// MARK: - Export Data Structures

struct ReviewExportData: Codable {
    let exportDate: Date
    let participantID: String
    let groupID: String
    let statistics: ReviewStatistics
    let problemLogs: [ExtendedProblemLog]
}

struct ReviewStatistics: Codable {
    let totalProblems: Int
    let correctAnswers: Int
    let overallAccuracy: Double
    let currentStreak: Int
    let engagementRate: Double
}

#Preview {
    ReviewView()
}