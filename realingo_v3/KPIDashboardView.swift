//
//  KPIDashboardView.swift
//  realingo_v3
//
//  KPIダッシュボード画面
//  学習効果の可視化と分析結果の表示
//

import SwiftUI
import Charts

struct KPIDashboardView: View {
    @StateObject private var analyzer = KPIAnalyzer.shared
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isLoading = false
    @State private var learningAnalysis: KPIAnalyzer.LearningPatternAnalysis?
    @State private var performanceHistory: [PerformanceDataPoint] = []
    @State private var engagementData: EngagementData?
    
    @AppStorage("nativeLanguage") private var nativeLanguageRaw: String = SupportedLanguage.japanese.rawValue
    @AppStorage("participantID") private var participantID = ""
    
    private var nativeLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: nativeLanguageRaw) ?? .japanese
    }
    
    enum TimeRange: String, CaseIterable {
        case day = "day"
        case week = "week"
        case month = "month"
        case all = "all"
        
        func displayName(for language: SupportedLanguage) -> String {
            switch self {
            case .day:
                return LocalizationHelper.getCommonText("today", for: language)
            case .week:
                return LocalizationHelper.getCommonText("week", for: language)
            case .month:
                return LocalizationHelper.getCommonText("month", for: language)
            case .all:
                return LocalizationHelper.getCommonText("allTime", for: language)
            }
        }
    }
    
    struct EngagementData {
        let averageSessionTime: Int
        let averageSessionTrend: Double
        let problemAttempts: Int
        let problemAttemptsTrend: Double
        let hintUsageRate: Double
        let hintUsageTrend: Double
        let averageResponseTime: Int
        let responseTimeTrend: Double
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // リアルタイムメトリクス
                    realtimeMetricsSection
                    
                    // 時間範囲選択
                    timeRangeSelector
                    
                    // 学習パフォーマンスチャート
                    performanceChartSection
                    
                    // エンゲージメント分析
                    engagementAnalysisSection
                    
                    // 学習パターン分析
                    learningPatternSection
                    
                    // 詳細レポート
                    detailedReportSection
                }
                .padding()
            }
            .navigationTitle(LocalizationHelper.getCommonText("learningAnalytics", for: nativeLanguage))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            loadAnalysis()
        }
    }
    
    // MARK: - リアルタイムメトリクス
    
    private var realtimeMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationHelper.getCommonText("realtimeMetrics", for: nativeLanguage))
                .font(.headline)
            
            HStack(spacing: 16) {
                MetricCard(
                    title: LocalizationHelper.getCommonText("continuousLearning", for: nativeLanguage),
                    value: "\(analyzer.realtimeMetrics.currentStreak)",
                    unit: LocalizationHelper.getCommonText("days", for: nativeLanguage),
                    icon: "flame.fill",
                    color: .orange
                )
                
                MetricCard(
                    title: LocalizationHelper.getCommonText("todayAccuracy", for: nativeLanguage),
                    value: String(format: "%.1f", analyzer.realtimeMetrics.todayAccuracy * 100),
                    unit: "%",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                MetricCard(
                    title: LocalizationHelper.getCommonText("weeklyProgress", for: nativeLanguage),
                    value: String(format: "%.1f", analyzer.realtimeMetrics.weeklyProgress * 100),
                    unit: "%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                MetricCard(
                    title: LocalizationHelper.getCommonText("monthlyGrowth", for: nativeLanguage),
                    value: String(format: "%.1f", analyzer.realtimeMetrics.monthlyGrowth * 100),
                    unit: "%",
                    icon: "arrow.up.forward",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - 時間範囲選択
    
    private var timeRangeSelector: some View {
        Picker(LocalizationHelper.getCommonText("timeRange", for: nativeLanguage), selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName(for: nativeLanguage)).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedTimeRange) {
            loadAnalysis()
        }
    }
    
    // MARK: - パフォーマンスチャート
    
    private var performanceChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationHelper.getCommonText("learningPerformance", for: nativeLanguage))
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(performanceData) { item in
                    LineMark(
                        x: .value(LocalizationHelper.getCommonText("date", for: nativeLanguage), item.date),
                        y: .value(LocalizationHelper.getCommonText("accuracyRate", for: nativeLanguage), item.accuracy)
                    )
                    .foregroundStyle(.blue)
                    
                    AreaMark(
                        x: .value(LocalizationHelper.getCommonText("date", for: nativeLanguage), item.date),
                        y: .value(LocalizationHelper.getCommonText("accuracyRate", for: nativeLanguage), item.accuracy)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                }
                .frame(height: 200)
                .chartYScale(domain: 0...100)
            } else {
                // iOS 16未満の場合の代替表示
                Text(LocalizationHelper.getCommonText("chartRequiresiOS16", for: nativeLanguage))
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - エンゲージメント分析
    
    private var engagementAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationHelper.getCommonText("engagementAnalysis", for: nativeLanguage))
                .font(.headline)
            
            VStack(spacing: 12) {
                if let data = engagementData {
                    EngagementRow(
                        title: LocalizationHelper.getCommonText("averageSessionTime", for: nativeLanguage),
                        value: "\(data.averageSessionTime)" + LocalizationHelper.getCommonText("minutes", for: nativeLanguage),
                        trend: data.averageSessionTrend > 0 ? .up : .down,
                        changePercent: String(format: "%+.0f%%", data.averageSessionTrend)
                    )
                    
                    EngagementRow(
                        title: LocalizationHelper.getCommonText("problemAttempts", for: nativeLanguage),
                        value: "\(data.problemAttempts)" + LocalizationHelper.getCommonText("times", for: nativeLanguage),
                        trend: data.problemAttemptsTrend > 0 ? .up : .down,
                        changePercent: String(format: "%+.0f%%", data.problemAttemptsTrend)
                    )
                    
                    EngagementRow(
                        title: LocalizationHelper.getCommonText("hintUsageRate", for: nativeLanguage),
                        value: String(format: "%.0f%%", data.hintUsageRate),
                        trend: data.hintUsageTrend < 0 ? .up : .down,  // ヒント使用率は下がった方が良い
                        changePercent: String(format: "%+.0f%%", data.hintUsageTrend)
                    )
                    
                    EngagementRow(
                        title: LocalizationHelper.getCommonText("averageResponseTime", for: nativeLanguage),
                        value: "\(data.averageResponseTime)" + LocalizationHelper.getCommonText("seconds", for: nativeLanguage),
                        trend: data.responseTimeTrend < 0 ? .up : .down,  // 回答時間は短い方が良い
                        changePercent: String(format: "%+.0f%%", data.responseTimeTrend)
                    )
                } else {
                    // データがない場合はローディング表示
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 学習パターン分析
    
    private var learningPatternSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationHelper.getCommonText("learningPatternAnalysis", for: nativeLanguage))
                .font(.headline)
            
            if let analysis = learningAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(LocalizationHelper.getCommonText("optimalLearningTime", for: nativeLanguage), systemImage: "clock.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Text(LocalizationHelper.getTimeOfDayText(analysis.optimalLearningTime, for: nativeLanguage))
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Label(LocalizationHelper.getCommonText("recommendedDifficulty", for: nativeLanguage), systemImage: "slider.horizontal.3")
                            .foregroundColor(.blue)
                        Spacer()
                        DifficultyIndicator(level: analysis.recommendedDifficulty)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label(LocalizationHelper.getCommonText("strongAreas", for: nativeLanguage), systemImage: "star.fill")
                            .foregroundColor(.green)
                        
                        ForEach(analysis.strongAreas, id: \.self) { area in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(area)
                                    .font(.caption)
                            }
                            .padding(.leading)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label(LocalizationHelper.getCommonText("improvementAreas", for: nativeLanguage), systemImage: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                        
                        ForEach(analysis.improvementAreas, id: \.self) { area in
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(area)
                                    .font(.caption)
                            }
                            .padding(.leading)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else if isLoading {
                ProgressView(LocalizationHelper.getCommonText("analyzing", for: nativeLanguage) + "...")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
    
    // MARK: - 詳細レポート
    
    private var detailedReportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizationHelper.getCommonText("personalizedSuggestions", for: nativeLanguage))
                .font(.headline)
            
            if let suggestions = learningAnalysis?.suggestions {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(suggestion)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
            }
            
            Button(action: exportReport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(LocalizationHelper.getCommonText("shareReport", for: nativeLanguage))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAnalysis() {
        isLoading = true
        
        Task {
            let userID = participantID.isEmpty ? UserDefaults.standard.string(forKey: "currentUserID") ?? "" : participantID
            
            // 学習パターン分析
            learningAnalysis = await analyzer.analyzeLearningPatterns(userID: userID)
            
            // パフォーマンス履歴を取得
            await loadPerformanceHistory()
            
            // エンゲージメントデータを取得
            await loadEngagementData()
            
            isLoading = false
        }
    }
    
    private func refreshData() {
        loadAnalysis()
    }
    
    private func exportReport() {
        Task {
            let reportData = generateReportData()
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: reportData, options: .prettyPrinted)
                
                let fileName = "learning_report_\(Date().timeIntervalSince1970).json"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                try jsonData.write(to: url)
                
                // 共有シートを表示
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            } catch {
                print("Report export error: \(error)")
            }
        }
    }
    
    private func generateReportData() -> [String: Any] {
        return [
            "generatedAt": Date().description,
            "userID": participantID,
            "metrics": [
                "currentStreak": analyzer.realtimeMetrics.currentStreak,
                "todayAccuracy": analyzer.realtimeMetrics.todayAccuracy,
                "weeklyProgress": analyzer.realtimeMetrics.weeklyProgress,
                "monthlyGrowth": analyzer.realtimeMetrics.monthlyGrowth
            ],
            "analysis": [
                "optimalLearningTime": learningAnalysis?.optimalLearningTime ?? "",
                "recommendedDifficulty": learningAnalysis?.recommendedDifficulty ?? 0,
                "strongAreas": learningAnalysis?.strongAreas ?? [],
                "improvementAreas": learningAnalysis?.improvementAreas ?? [],
                "suggestions": learningAnalysis?.suggestions ?? []
            ]
        ]
    }
    
    // MARK: - Data Loading
    
    private func loadPerformanceHistory() async {
        // DataPersistenceManagerから学習履歴を取得
        let logs = await DataPersistenceManager.shared.fetchProblemLogs(
            userID: participantID,
            dateRange: getDateRange(for: selectedTimeRange)
        )
        
        // 日別の正解率を計算
        let groupedByDate = Dictionary(grouping: logs) { log in
            Calendar.current.startOfDay(for: log.completedAt)
        }
        
        performanceHistory = groupedByDate.map { date, logs in
            let correctCount = logs.filter { $0.isCorrect }.count
            let accuracy = logs.isEmpty ? 0 : Double(correctCount) / Double(logs.count) * 100
            return PerformanceDataPoint(date: date, accuracy: accuracy)
        }.sorted { $0.date < $1.date }
    }
    
    private func loadEngagementData() async {
        // エンゲージメントデータを計算
        let logs = await DataPersistenceManager.shared.fetchProblemLogs(
            userID: participantID,
            dateRange: getDateRange(for: selectedTimeRange)
        )
        
        let previousLogs = await DataPersistenceManager.shared.fetchProblemLogs(
            userID: participantID,
            dateRange: getPreviousDateRange(for: selectedTimeRange)
        )
        
        // 現在期間のメトリクス
        let avgSessionTime = calculateAverageSessionTime(logs)
        let problemCount = logs.count
        let hintUsageRate = calculateHintUsageRate(logs)
        let avgResponseTime = calculateAverageResponseTime(logs)
        
        // 前期間のメトリクス
        let prevAvgSessionTime = calculateAverageSessionTime(previousLogs)
        let prevProblemCount = previousLogs.count
        let prevHintUsageRate = calculateHintUsageRate(previousLogs)
        let prevAvgResponseTime = calculateAverageResponseTime(previousLogs)
        
        // トレンドを計算
        engagementData = EngagementData(
            averageSessionTime: avgSessionTime,
            averageSessionTrend: calculateTrend(current: Double(avgSessionTime), previous: Double(prevAvgSessionTime)),
            problemAttempts: problemCount,
            problemAttemptsTrend: calculateTrend(current: Double(problemCount), previous: Double(prevProblemCount)),
            hintUsageRate: hintUsageRate,
            hintUsageTrend: calculateTrend(current: hintUsageRate, previous: prevHintUsageRate),
            averageResponseTime: avgResponseTime,
            responseTimeTrend: calculateTrend(current: Double(avgResponseTime), previous: Double(prevAvgResponseTime))
        )
    }
    
    private func getDateRange(for timeRange: TimeRange) -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch timeRange {
        case .day:
            return (calendar.startOfDay(for: now), now)
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return (weekAgo, now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return (monthAgo, now)
        case .all:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return (yearAgo, now)
        }
    }
    
    private func getPreviousDateRange(for timeRange: TimeRange) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let current = getDateRange(for: timeRange)
        let duration = current.end.timeIntervalSince(current.start)
        
        let end = current.start
        let start = Date(timeInterval: -duration, since: end)
        
        return (start, end)
    }
    
    private func calculateAverageSessionTime(_ logs: [ExtendedProblemLog]) -> Int {
        guard !logs.isEmpty else { return 0 }
        let totalTime = logs.reduce(0) { $0 + $1.timeSpentSeconds }
        return totalTime / logs.count / 60  // 分単位
    }
    
    private func calculateHintUsageRate(_ logs: [ExtendedProblemLog]) -> Double {
        guard !logs.isEmpty else { return 0 }
        // ヒント使用の判定ロジックが必要
        return 0.0  // TODO: 実装
    }
    
    private func calculateAverageResponseTime(_ logs: [ExtendedProblemLog]) -> Int {
        guard !logs.isEmpty else { return 0 }
        let totalTime = logs.reduce(0) { $0 + $1.timeSpentSeconds }
        return totalTime / logs.count
    }
    
    private func calculateTrend(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
    
    private var performanceData: [PerformanceDataPoint] {
        performanceHistory
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct EngagementRow: View {
    let title: String
    let value: String
    let trend: Trend
    let changePercent: String
    
    enum Trend {
        case up, down, neutral
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .fontWeight(.semibold)
                
                HStack(spacing: 2) {
                    Image(systemName: trend == .up ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(changePercent)
                        .font(.caption2)
                }
                .foregroundColor(trend == .up ? .green : .red)
            }
        }
    }
}

struct DifficultyIndicator: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= level ? "star.fill" : "star")
                    .foregroundColor(i <= level ? .yellow : .gray)
                    .font(.caption)
            }
        }
    }
}

struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let accuracy: Double
}

// MARK: - Preview

struct KPIDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        KPIDashboardView()
    }
}