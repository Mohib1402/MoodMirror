//
//  InsightsViewModel.swift
//  MoodMirror
//
//  ViewModel for AI-generated insights
//

import SwiftUI

/// Insights view model
@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var insights: [String] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var mostCommonEmotion: EmotionType?
    @Published var emotionStreak: (emotion: EmotionType, days: Int)?
    
    let storageService: StorageServiceProtocol
    private let geminiService: GeminiServiceProtocol
    private let chartProcessor = ChartDataProcessor()
    private let healthKitManager = HealthKitManager()
    @Published var healthCorrelations: [String] = []
    
    init(storageService: StorageServiceProtocol, geminiService: GeminiServiceProtocol) {
        self.storageService = storageService
        self.geminiService = geminiService
    }
    
    /// Generate insights from check-ins
    func generateInsights() async {
        isLoading = true
        error = nil
        
        do {
            // Fetch recent check-ins (last 30 days)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let checkIns = try await storageService.fetch(from: thirtyDaysAgo, to: Date())
            
            guard !checkIns.isEmpty else {
                insights = []
                isLoading = false
                return
            }
            
            // Calculate patterns
            mostCommonEmotion = chartProcessor.getMostCommonEmotion(from: checkIns)
            emotionStreak = chartProcessor.calculateEmotionStreak(from: checkIns)
            
            // Generate AI insights
            let aiInsights = try await geminiService.generateInsights(from: checkIns)
            insights = aiInsights
            
            // HealthKit correlations disabled - threading issues with authorization
            // TODO: Re-enable after fixing HealthKit threading
            healthCorrelations = []
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// Refresh insights
    func refresh() async {
        await generateInsights()
    }
}
