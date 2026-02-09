//
//  InsightsViewModelTests.swift
//  MoodMirrorTests
//
//  Tests for InsightsViewModel
//

import XCTest
@testable import MoodMirror

@MainActor
final class InsightsViewModelTests: XCTestCase {
    var viewModel: InsightsViewModel!
    var mockStorage: MockStorageService!
    var mockGemini: MockGeminiService!
    
    override func setUp() {
        mockStorage = MockStorageService()
        mockGemini = MockGeminiService()
        viewModel = InsightsViewModel(storageService: mockStorage, geminiService: mockGemini)
    }
    
    override func tearDown() {
        viewModel = nil
        mockStorage = nil
        mockGemini = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(viewModel.insights.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertNil(viewModel.mostCommonEmotion)
        XCTAssertNil(viewModel.emotionStreak)
        XCTAssertTrue(viewModel.healthCorrelations.isEmpty)
    }
    
    // MARK: - Generate Insights Tests
    
    func testGenerateInsightsWithNoData() async {
        // Given no check-ins
        mockStorage.checkIns = []
        
        // When generating insights
        await viewModel.generateInsights()
        
        // Then insights should be empty
        XCTAssertTrue(viewModel.insights.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testGenerateInsightsWithData() async {
        // Given some check-ins
        let checkIn1 = mockStorage.createMockCheckIn(emotion: .happy)
        let checkIn2 = mockStorage.createMockCheckIn(emotion: .happy)
        let checkIn3 = mockStorage.createMockCheckIn(emotion: .sad)
        mockStorage.checkIns = [checkIn1, checkIn2, checkIn3]
        
        // When generating insights
        await viewModel.generateInsights()
        
        // Then insights should be generated
        XCTAssertFalse(viewModel.insights.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    func testMostCommonEmotionCalculation() async {
        // Given check-ins with mostly happy emotions
        let checkIn1 = mockStorage.createMockCheckIn(emotion: .happy)
        let checkIn2 = mockStorage.createMockCheckIn(emotion: .happy)
        let checkIn3 = mockStorage.createMockCheckIn(emotion: .sad)
        mockStorage.checkIns = [checkIn1, checkIn2, checkIn3]
        
        // When generating insights
        await viewModel.generateInsights()
        
        // Then most common emotion should be happy
        XCTAssertEqual(viewModel.mostCommonEmotion, .happy)
    }
    
    func testEmotionStreakCalculation() async {
        // Given consecutive check-ins with same emotion
        let checkIn1 = mockStorage.createMockCheckIn(emotion: .happy)
        let checkIn2 = mockStorage.createMockCheckIn(emotion: .happy)
        let checkIn3 = mockStorage.createMockCheckIn(emotion: .happy)
        mockStorage.checkIns = [checkIn1, checkIn2, checkIn3]
        
        // When generating insights
        await viewModel.generateInsights()
        
        // Then emotion streak should be calculated
        XCTAssertNotNil(viewModel.emotionStreak)
        if let streak = viewModel.emotionStreak {
            XCTAssertEqual(streak.emotion, .happy)
            XCTAssertGreaterThan(streak.days, 0)
        }
    }
    
    func testLoadingStateManagement() async {
        // Given some check-ins
        mockStorage.checkIns = [mockStorage.createMockCheckIn(emotion: .happy)]
        
        // When starting to generate insights
        let task = Task {
            await viewModel.generateInsights()
        }
        
        // Then loading should be true initially
        // (Note: Due to async nature, this might complete too fast to catch)
        
        await task.value
        
        // After completion, loading should be false
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testErrorHandling() async {
        // Given storage will throw error
        mockStorage.shouldThrowError = true
        
        // When generating insights
        await viewModel.generateInsights()
        
        // Then error should be set
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Refresh Tests
    
    func testRefresh() async {
        // Given initial state
        mockStorage.checkIns = [mockStorage.createMockCheckIn(emotion: .happy)]
        
        // When refreshing
        await viewModel.refresh()
        
        // Then insights should be regenerated
        XCTAssertFalse(viewModel.insights.isEmpty)
    }
}
