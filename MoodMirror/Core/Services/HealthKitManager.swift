//
//  HealthKitManager.swift
//  MoodMirror
//
//  Manages HealthKit integration for correlating health data with emotions
//

import Foundation
import HealthKit

/// HealthKit manager errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case dataUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit access denied"
        case .dataUnavailable:
            return "Health data not available"
        }
    }
}

/// Health correlation data
struct HealthCorrelation: Identifiable {
    let id = UUID()
    let date: Date
    let sleepHours: Double?
    let exerciseMinutes: Double?
    let heartRate: Double?
    let primaryEmotion: EmotionType
}

/// HealthKit manager
@MainActor
final class HealthKitManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var sleepData: [Date: Double] = [:]
    @Published var exerciseData: [Date: Double] = [:]
    @Published var correlations: [String] = []
    
    private let healthStore = HKHealthStore()
    
    /// Check if HealthKit is available
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    /// Request HealthKit authorization (MUST be called from main thread)
    @MainActor
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let typesToRead: Set<HKObjectType> = [sleepType, exerciseType, heartRateType]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            await MainActor.run {
                isAuthorized = true
            }
        } catch {
            throw HealthKitError.authorizationDenied
        }
    }
    
    /// Fetch sleep data for date range
    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [Date: Double] {
        guard isAuthorized else {
            throw HealthKitError.authorizationDenied
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [:])
                    return
                }
                
                var sleepByDate: [Date: Double] = [:]
                let calendar = Calendar.current
                
                for sample in sleepSamples {
                    guard sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                          sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                          sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue else {
                        continue
                    }
                    
                    let date = calendar.startOfDay(for: sample.startDate)
                    let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                    
                    sleepByDate[date, default: 0] += hours
                }
                
                continuation.resume(returning: sleepByDate)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch exercise data for date range
    func fetchExerciseData(from startDate: Date, to endDate: Date) async throws -> [Date: Double] {
        guard isAuthorized else {
            throw HealthKitError.authorizationDenied
        }
        
        let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )
            
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = results else {
                    continuation.resume(returning: [:])
                    return
                }
                
                var exerciseByDate: [Date: Double] = [:]
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        let minutes = sum.doubleValue(for: .minute())
                        exerciseByDate[statistics.startDate] = minutes
                    }
                }
                
                continuation.resume(returning: exerciseByDate)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Generate correlations between health data and emotions
    func generateCorrelations(checkIns: [EmotionCheckIn]) async -> [String] {
        var insights: [String] = []
        
        guard !checkIns.isEmpty else { return insights }
        
        // Fetch health data for the same period
        let dates = checkIns.map { $0.timestamp }
        guard let startDate = dates.min(), let endDate = dates.max() else { return insights }
        
        do {
            sleepData = try await fetchSleepData(from: startDate, to: endDate)
            exerciseData = try await fetchExerciseData(from: startDate, to: endDate)
        } catch {
            return ["Unable to fetch health data: \(error.localizedDescription)"]
        }
        
        // Analyze sleep correlation
        if let sleepInsight = analyzeSleepCorrelation(checkIns: checkIns) {
            insights.append(sleepInsight)
        }
        
        // Analyze exercise correlation
        if let exerciseInsight = analyzeExerciseCorrelation(checkIns: checkIns) {
            insights.append(exerciseInsight)
        }
        
        return insights
    }
    
    // MARK: - Private Methods
    
    private func analyzeSleepCorrelation(checkIns: [EmotionCheckIn]) -> String? {
        let calendar = Calendar.current
        
        var goodMoodWithGoodSleep = 0
        var poorMoodWithPoorSleep = 0
        var totalWithSleepData = 0
        
        for checkIn in checkIns {
            let date = calendar.startOfDay(for: checkIn.timestamp)
            guard let sleepHours = sleepData[date] else { continue }
            
            totalWithSleepData += 1
            let emotion = EmotionType(rawValue: checkIn.primaryEmotion)
            
            if sleepHours >= 7 && (emotion == .happy || emotion == .excited || emotion == .calm) {
                goodMoodWithGoodSleep += 1
            } else if sleepHours < 6 && (emotion == .sad || emotion == .anxious || emotion == .angry) {
                poorMoodWithPoorSleep += 1
            }
        }
        
        guard totalWithSleepData >= 3 else { return nil }
        
        let correlation = Double(goodMoodWithGoodSleep + poorMoodWithPoorSleep) / Double(totalWithSleepData)
        
        if correlation > 0.6 {
            return "Your mood correlates with sleep quality. Better sleep (7+ hours) is linked to more positive emotions."
        } else if poorMoodWithPoorSleep > goodMoodWithGoodSleep {
            return "Poor sleep (<6 hours) may be affecting your mood. Consider prioritizing rest for emotional wellbeing."
        }
        
        return nil
    }
    
    private func analyzeExerciseCorrelation(checkIns: [EmotionCheckIn]) -> String? {
        let calendar = Calendar.current
        
        var goodMoodWithExercise = 0
        var totalWithExerciseData = 0
        
        for checkIn in checkIns {
            let date = calendar.startOfDay(for: checkIn.timestamp)
            guard let exerciseMinutes = exerciseData[date] else { continue }
            
            totalWithExerciseData += 1
            let emotion = EmotionType(rawValue: checkIn.primaryEmotion)
            
            if exerciseMinutes >= 20 && (emotion == .happy || emotion == .excited || emotion == .calm) {
                goodMoodWithExercise += 1
            }
        }
        
        guard totalWithExerciseData >= 3 else { return nil }
        
        let correlation = Double(goodMoodWithExercise) / Double(totalWithExerciseData)
        
        if correlation > 0.5 {
            return "Exercise appears to boost your mood! Days with 20+ minutes of activity show more positive emotions."
        }
        
        return nil
    }
}
