//
//  ChartDataProcessor.swift
//  MoodMirror
//
//  Process check-in data for chart visualizations
//

import Foundation

/// Data point for trend charts
struct EmotionTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let emotion: EmotionType
    let averageConfidence: Double
}

/// Data point for frequency charts
struct EmotionFrequency: Identifiable {
    let id = UUID()
    let emotion: EmotionType
    let count: Int
    let percentage: Double
}

/// Time-of-day pattern data
struct TimeOfDayPattern: Identifiable {
    let id = UUID()
    let hour: Int
    let emotion: EmotionType
    let count: Int
}

/// Chart data processor
final class ChartDataProcessor {
    
    /// Calculate emotion trend over time
    func calculateEmotionTrend(from checkIns: [EmotionCheckIn]) -> [EmotionTrendPoint] {
        let calendar = Calendar.current
        
        // Group by date first
        let byDate = Dictionary(grouping: checkIns) { checkIn -> Date in
            calendar.startOfDay(for: checkIn.timestamp)
        }
        
        var trendPoints: [EmotionTrendPoint] = []
        
        for (date, dailyCheckIns) in byDate {
            // Group by emotion for this date
            let byEmotion = Dictionary(grouping: dailyCheckIns) { $0.primaryEmotion }
            
            for (emotionString, emotionCheckIns) in byEmotion {
                guard let emotion = EmotionType(rawValue: emotionString) else { continue }

                // Calculate average confidence for this emotion on this day
                let totalConfidence = emotionCheckIns.compactMap { checkIn -> Double? in
                    guard let scoresData = checkIn.emotionScores,
                          let scores = try? JSONDecoder().decode([EmotionScore].self, from: scoresData),
                          let emotionScore = scores.first(where: { $0.emotion == emotion }) else {
                        return nil
                    }
                    return emotionScore.confidence
                }.reduce(0, +)
                
                let averageConfidence = totalConfidence / Double(emotionCheckIns.count)
                
                trendPoints.append(EmotionTrendPoint(
                    date: date,
                    emotion: emotion,
                    averageConfidence: averageConfidence
                ))
            }
        }
        
        return trendPoints.sorted { $0.date < $1.date }
    }
    
    /// Calculate emotion frequency distribution
    func calculateEmotionFrequency(from checkIns: [EmotionCheckIn]) -> [EmotionFrequency] {
        guard !checkIns.isEmpty else { return [] }
        
        // Count occurrences of each emotion
        let emotionCounts = Dictionary(grouping: checkIns) { $0.primaryEmotion }
            .mapValues { $0.count }
        
        let total = Double(checkIns.count)
        
        return emotionCounts.compactMap { (emotionString, count) -> EmotionFrequency? in
            guard let emotion = EmotionType(rawValue: emotionString) else { return nil }
            
            return EmotionFrequency(
                emotion: emotion,
                count: count,
                percentage: Double(count) / total * 100
            )
        }.sorted { $0.count > $1.count }
    }
    
    /// Calculate time-of-day patterns
    func calculateTimeOfDayPatterns(from checkIns: [EmotionCheckIn]) -> [TimeOfDayPattern] {
        let calendar = Calendar.current
        
        // Group by hour first
        let byHour = Dictionary(grouping: checkIns) { checkIn -> Int in
            calendar.component(.hour, from: checkIn.timestamp)
        }
        
        var patterns: [TimeOfDayPattern] = []
        
        for (hour, hourlyCheckIns) in byHour {
            // Group by emotion for this hour
            let byEmotion = Dictionary(grouping: hourlyCheckIns) { $0.primaryEmotion }
            
            for (emotionString, emotionCheckIns) in byEmotion {
                guard let emotion = EmotionType(rawValue: emotionString) else { continue }
                
                patterns.append(TimeOfDayPattern(
                    hour: hour,
                    emotion: emotion,
                    count: emotionCheckIns.count
                ))
            }
        }
        
        return patterns.sorted { $0.hour < $1.hour }
    }
    
    /// Get most common emotion
    func getMostCommonEmotion(from checkIns: [EmotionCheckIn]) -> EmotionType? {
        guard !checkIns.isEmpty else { return nil }
        
        let emotionCounts = Dictionary(grouping: checkIns) { $0.primaryEmotion }
            .mapValues { $0.count }
        
        guard let mostCommon = emotionCounts.max(by: { $0.value < $1.value }),
              let emotion = EmotionType(rawValue: mostCommon.key) else {
            return nil
        }
        
        return emotion
    }
    
    /// Calculate emotion streak (consecutive days with same primary emotion)
    func calculateEmotionStreak(from checkIns: [EmotionCheckIn]) -> (emotion: EmotionType, days: Int)? {
        guard !checkIns.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let sorted = checkIns.sorted { $0.timestamp < $1.timestamp }
        
        // Group by day and get primary emotion for each day
        let dailyEmotions = Dictionary(grouping: sorted) { checkIn in
            calendar.startOfDay(for: checkIn.timestamp)
        }.mapValues { dayCheckIns -> String? in
            // Most common emotion for that day
            let emotionCounts = Dictionary(grouping: dayCheckIns) { $0.primaryEmotion }
                .mapValues { $0.count }
            return emotionCounts.max(by: { $0.value < $1.value })?.key
        }.compactMapValues { $0 }
        
        // Find longest streak
        var maxStreak = 0
        var maxStreakEmotion: String?
        var currentStreak = 0
        var currentEmotion: String?
        
        for date in dailyEmotions.keys.sorted() {
            guard let emotion = dailyEmotions[date] else { continue }
            
            if emotion == currentEmotion {
                currentStreak += 1
            } else {
                if currentStreak > maxStreak {
                    maxStreak = currentStreak
                    maxStreakEmotion = currentEmotion
                }
                currentStreak = 1
                currentEmotion = emotion
            }
        }
        
        // Check final streak
        if currentStreak > maxStreak {
            maxStreak = currentStreak
            maxStreakEmotion = currentEmotion
        }
        
        guard let streakEmotionString = maxStreakEmotion,
              let streakEmotion = EmotionType(rawValue: streakEmotionString) else {
            return nil
        }
        
        return (streakEmotion, maxStreak)
    }
    
    /// Filter check-ins by date range
    func filterByDateRange(_ checkIns: [EmotionCheckIn], from startDate: Date, to endDate: Date) -> [EmotionCheckIn] {
        return checkIns.filter { checkIn in
            checkIn.timestamp >= startDate && checkIn.timestamp <= endDate
        }
    }
}
