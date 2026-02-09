//
//  EmotionChartsView.swift
//  MoodMirror
//
//  Emotion charts and visualizations
//

import SwiftUI
import Charts

/// Date range option for charts
enum ChartDateRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case year = "Year"
    case all = "All Time"
    
    func dateRange(from endDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = endDate
        
        let start: Date
        switch self {
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: end)!
        case .month:
            start = calendar.date(byAdding: .month, value: -1, to: end)!
        case .threeMonths:
            start = calendar.date(byAdding: .month, value: -3, to: end)!
        case .year:
            start = calendar.date(byAdding: .year, value: -1, to: end)!
        case .all:
            start = calendar.date(byAdding: .year, value: -10, to: end)!
        }
        
        return (start, end)
    }
}

/// Emotion charts view
struct EmotionChartsView: View {
    let checkIns: [EmotionCheckIn]
    @State private var selectedDateRange: ChartDateRange = .month
    
    private let processor = ChartDataProcessor()
    
    private var filteredCheckIns: [EmotionCheckIn] {
        let range = selectedDateRange.dateRange()
        return processor.filterByDateRange(checkIns, from: range.start, to: range.end)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Date range picker
                dateRangePicker
                
                if filteredCheckIns.isEmpty {
                    emptyState
                } else {
                    // Frequency chart
                    frequencyChart
                    
                    // Trend chart
                    trendChart
                    
                    // Time of day patterns
                    timeOfDayChart
                }
            }
            .padding()
        }
        .navigationTitle("Charts")
    }
    
    // MARK: - Subviews
    
    private var dateRangePicker: some View {
        Picker("Date Range", selection: $selectedDateRange) {
            ForEach(ChartDateRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var frequencyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emotion Distribution")
                .font(.headline)
            
            let frequencies = processor.calculateEmotionFrequency(from: filteredCheckIns)
            
            Chart(frequencies) { frequency in
                BarMark(
                    x: .value("Count", frequency.count),
                    y: .value("Emotion", frequency.emotion.rawValue.capitalized)
                )
                .foregroundStyle(frequency.emotion.color)
                .annotation(position: .trailing) {
                    Text("\(frequency.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: CGFloat(frequencies.count * 40))
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emotion Trends")
                .font(.headline)
            
            let trendData = processor.calculateEmotionTrend(from: filteredCheckIns)
            
            if trendData.isEmpty {
                Text("Not enough data for trends")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Chart(trendData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Confidence", point.averageConfidence)
                    )
                    .foregroundStyle(point.emotion.color)
                    .symbol(by: .value("Emotion", point.emotion.rawValue))
                    
                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Confidence", point.averageConfidence)
                    )
                    .foregroundStyle(point.emotion.color)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let confidence = value.as(Double.self) {
                                Text("\(Int(confidence * 100))%")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var timeOfDayChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time of Day Patterns")
                .font(.headline)
            
            let patterns = processor.calculateTimeOfDayPatterns(from: filteredCheckIns)
            
            if patterns.isEmpty {
                Text("Not enough data for time patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Chart(patterns) { pattern in
                    BarMark(
                        x: .value("Hour", "\(pattern.hour):00"),
                        y: .value("Count", pattern.count)
                    )
                    .foregroundStyle(pattern.emotion.color)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 12)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Data Available")
                .font(.headline)
            
            Text("Complete more check-ins to see your emotion patterns")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
