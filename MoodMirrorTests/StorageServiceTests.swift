//
//  StorageServiceTests.swift
//  MoodMirrorTests
//
//  Tests for StorageService
//

import XCTest
import CoreData
@testable import MoodMirror

final class StorageServiceTests: XCTestCase {
    
    var storageService: StorageService!
    var testController: PersistenceController!
    
    override func setUp() async throws {
        testController = PersistenceController(inMemory: true)
        storageService = StorageService(persistenceController: testController)
    }
    
    override func tearDown() async throws {
        try await storageService.deleteAll()
        storageService = nil
        testController = nil
    }
    
    func testSaveEmotionAnalysis() async throws {
        // Arrange
        let scores = [
            EmotionScore(emotion: .happy, confidence: 0.8),
            EmotionScore(emotion: .calm, confidence: 0.6)
        ]
        let analysis = EmotionAnalysis(
            emotionScores: scores,
            aiInsight: "You seem happy today!",
            voiceTranscript: "I feel great"
        )
        
        // Act
        let checkIn = try await storageService.save(analysis: analysis, notes: "Test notes")
        
        // Assert
        XCTAssertEqual(checkIn.primaryEmotion, "happy")
        XCTAssertEqual(checkIn.notes, "Test notes")
        XCTAssertEqual(checkIn.aiInsight, "You seem happy today!")
        XCTAssertNotNil(checkIn.emotionScores)
    }
    
    func testFetchAllCheckIns() async throws {
        // Arrange - save 3 check-ins
        for i in 1...3 {
            let scores = [EmotionScore(emotion: .happy, confidence: Double(i) / 10.0)]
            let analysis = EmotionAnalysis(emotionScores: scores)
            _ = try await storageService.save(analysis: analysis)
        }
        
        // Act
        let checkIns = try await storageService.fetchAll()
        
        // Assert
        XCTAssertEqual(checkIns.count, 3)
        // Should be sorted by timestamp descending
        XCTAssertTrue(checkIns[0].timestamp >= checkIns[1].timestamp)
    }
    
    func testFetchCheckInsInDateRange() async throws {
        // Arrange
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        
        // Create check-ins with different timestamps
        let scores = [EmotionScore(emotion: .happy, confidence: 0.8)]
        
        let analysis1 = EmotionAnalysis(emotionScores: scores)
        let checkIn1 = try await storageService.save(analysis: analysis1)
        checkIn1.timestamp = twoDaysAgo
        
        let analysis2 = EmotionAnalysis(emotionScores: scores)
        let checkIn2 = try await storageService.save(analysis: analysis2)
        checkIn2.timestamp = yesterday
        
        let analysis3 = EmotionAnalysis(emotionScores: scores)
        let checkIn3 = try await storageService.save(analysis: analysis3)
        checkIn3.timestamp = now // Explicitly set to 'now' to match query range
        
        try testController.container.viewContext.save()
        
        // Act - fetch only yesterday to now
        let checkIns = try await storageService.fetch(from: yesterday, to: now)
        
        // Assert
        XCTAssertEqual(checkIns.count, 2) // Should not include two days ago
    }
    
    func testDeleteCheckIn() async throws {
        // Arrange
        let scores = [EmotionScore(emotion: .happy, confidence: 0.8)]
        let analysis = EmotionAnalysis(emotionScores: scores)
        let checkIn = try await storageService.save(analysis: analysis)
        
        // Act
        try await storageService.delete(checkIn: checkIn)
        
        // Assert
        let allCheckIns = try await storageService.fetchAll()
        XCTAssertEqual(allCheckIns.count, 0)
    }
    
    func testDeleteAllCheckIns() async throws {
        // Arrange - save 3 check-ins
        for _ in 1...3 {
            let scores = [EmotionScore(emotion: .happy, confidence: 0.8)]
            let analysis = EmotionAnalysis(emotionScores: scores)
            _ = try await storageService.save(analysis: analysis)
        }
        
        // Act
        try await storageService.deleteAll()
        
        // Assert
        let allCheckIns = try await storageService.fetchAll()
        XCTAssertEqual(allCheckIns.count, 0)
    }
    
    func testEmotionAnalysisConversion() async throws {
        // Arrange
        let scores = [
            EmotionScore(emotion: .happy, confidence: 0.8),
            EmotionScore(emotion: .calm, confidence: 0.6),
            EmotionScore(emotion: .excited, confidence: 0.4)
        ]
        let analysis = EmotionAnalysis(
            emotionScores: scores,
            aiInsight: "Great mood!",
            voiceTranscript: "I'm feeling awesome"
        )
        
        // Act
        let checkIn = try await storageService.save(analysis: analysis)
        let retrievedAnalysis = checkIn.analysis
        
        // Assert
        XCTAssertNotNil(retrievedAnalysis)
        XCTAssertEqual(retrievedAnalysis?.primaryEmotion, .happy)
        XCTAssertEqual(retrievedAnalysis?.emotionScores.count, 3)
        XCTAssertEqual(retrievedAnalysis?.aiInsight, "Great mood!")
        XCTAssertEqual(retrievedAnalysis?.voiceTranscript, "I'm feeling awesome")
    }
}
