//
//  ChartDataProcessorTests.swift
//  MoodMirrorTests
//
//  Tests for ChartDataProcessor
//

import XCTest
@testable import MoodMirror

final class ChartDataProcessorTests: XCTestCase {
    var processor: ChartDataProcessor!
    var mockStorage: MockStorageService!
    
    override func setUp() {
        processor = ChartDataProcessor()
        mockStorage = MockStorageService()
    }
    
    override func tearDown() {
        processor = nil
        mockStorage = nil
    }
    
    // MARK: - Emotion Frequency Tests
    
    func testEmotionFrequencyWithEmptyData() {
        let result = processor.calculateEmotionFrequency(from: [])
        XCTAssertTrue(result.isEmpty)
    }
    
    func testEmotionFrequencyWithSingleEmotion() {
        let checkIns = [
            mockStorage.createMockCheckIn(emotion: .happy),
            mockStorage.createMockCheckIn(emotion: .happy),
            mockStorage.createMockCheckIn(emotion: .happy)
        ]
        
        let result = processor.calculateEmotionFrequency(from: checkIns)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.emotion, .happy)
        XCTAssertEqual(result.first?.count, 3)
    }
    
    func testEmotionFrequencyWithMultipleEmotions() {
        let checkIns = [
            mockStorage.createMockCheckIn(emotion: .happy),
            mockStorage.createMockCheckIn(emotion: .happy),
            mockStorage.createMockCheckIn(emotion: .sad),
            mockStorage.createMockCheckIn(emotion: .anxious)
        ]
        
        let result = processor.calculateEmotionFrequency(from: checkIns)
        
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.contains(where: { $0.emotion == .happy && $0.count == 2 }))
        XCTAssertTrue(result.contains(where: { $0.emotion == .sad && $0.count == 1 }))
        XCTAssertTrue(result.contains(where: { $0.emotion == .anxious && $0.count == 1 }))
    }
    
    // MARK: - Most Common Emotion Tests
    
    func testMostCommonEmotionWithEmptyData() {
        let result = processor.getMostCommonEmotion(from: [])
        XCTAssertNil(result)
    }
    
    func testMostCommonEmotionWithSingleCheckIn() {
        let checkIns = [mockStorage.createMockCheckIn(emotion: .happy)]
        
        let result = processor.getMostCommonEmotion(from: checkIns)
        
        XCTAssertEqual(result, .happy)
    }
    
    func testMostCommonEmotionWithMultipleCheckIns() {
        let checkIns = [
            mockStorage.createMockCheckIn(emotion: .happy),
            mockStorage.createMockCheckIn(emotion: .happy),
            mockStorage.createMockCheckIn(emotion: .sad),
            mockStorage.createMockCheckIn(emotion: .anxious),
            mockStorage.createMockCheckIn(emotion: .anxious),
            mockStorage.createMockCheckIn(emotion: .anxious)
        ]
        
        let result = processor.getMostCommonEmotion(from: checkIns)
        
        XCTAssertEqual(result, .anxious)
    }
    
    // MARK: - Emotion Streak Tests
    
    func testEmotionStreakWithEmptyData() {
        let result = processor.calculateEmotionStreak(from: [])
        XCTAssertNil(result)
    }
    
    func testEmotionStreakWithSingleDay() {
        let checkIns = [mockStorage.createMockCheckIn(emotion: .happy)]
        
        let result = processor.calculateEmotionStreak(from: checkIns)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.emotion, .happy)
        XCTAssertEqual(result?.days, 1)
    }
    
    func testEmotionStreakWithConsecutiveDays() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        
        let checkIns = [
            mockStorage.createMockCheckIn(emotion: .happy, timestamp: twoDaysAgo),
            mockStorage.createMockCheckIn(emotion: .happy, timestamp: yesterday),
            mockStorage.createMockCheckIn(emotion: .happy, timestamp: today)
        ]
        
        let result = processor.calculateEmotionStreak(from: checkIns)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.emotion, .happy)
        XCTAssertGreaterThanOrEqual(result?.days ?? 0, 1)
    }
    
    // MARK: - Trend Calculation Tests
    
    func testEmotionTrendWithEmptyData() {
        let startDate = Date()
        let endDate = Date()
        
        let result = processor.calculateEmotionTrend(from: [], startDate: startDate, endDate: endDate)
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testEmotionTrendWithData() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let checkIns = [
            mockStorage.createMockCheckIn(emotion: .happy, timestamp: yesterday),
            mockStorage.createMockCheckIn(emotion: .sad, timestamp: today)
        ]
        
        let result = processor.calculateEmotionTrend(from: checkIns, startDate: yesterday, endDate: today)
        
        XCTAssertFalse(result.isEmpty)
    }
}
