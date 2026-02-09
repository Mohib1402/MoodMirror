//
//  GeminiServiceTests.swift
//  MoodMirrorTests
//
//  Tests for GeminiService
//

import XCTest
@testable import MoodMirror

final class GeminiServiceTests: XCTestCase {
    
    var mockService: MockGeminiService!
    
    override func setUp() async throws {
        mockService = MockGeminiService()
    }
    
    override func tearDown() async throws {
        mockService = nil
    }
    
    // MARK: - Emotion Analysis Tests
    
    func testAnalyzeEmotionSuccess() async throws {
        // Arrange
        let expectedAnalysis = EmotionAnalysis(
            emotionScores: [
                EmotionScore(emotion: .happy, confidence: 0.9),
                EmotionScore(emotion: .excited, confidence: 0.7)
            ],
            aiInsight: "You seem very positive today!",
            voiceTranscript: "I'm feeling great"
        )
        mockService.mockEmotionResponse = expectedAnalysis
        
        // Act
        let result = try await mockService.analyzeEmotion(
            faceDescription: "smiling face",
            voiceTone: "upbeat",
            transcribedText: "I'm feeling great"
        )
        
        // Assert
        XCTAssertEqual(result.primaryEmotion, .happy)
        XCTAssertEqual(result.emotionScores.count, 2)
        XCTAssertEqual(result.aiInsight, "You seem very positive today!")
        XCTAssertEqual(result.voiceTranscript, "I'm feeling great")
    }
    
    func testAnalyzeEmotionWithoutVoice() async throws {
        // Act - only face description
        let result = try await mockService.analyzeEmotion(
            faceDescription: "neutral expression",
            voiceTone: nil,
            transcribedText: nil
        )
        
        // Assert
        XCTAssertNotNil(result)
        XCTAssertFalse(result.emotionScores.isEmpty)
    }
    
    func testAnalyzeEmotionFailure() async throws {
        // Arrange
        mockService.shouldFail = true
        
        // Act & Assert
        do {
            _ = try await mockService.analyzeEmotion(
                faceDescription: "smiling",
                voiceTone: nil,
                transcribedText: nil
            )
            XCTFail("Should have thrown error")
        } catch let error as GeminiError {
            // Verify correct error type
            switch error {
            case .apiError:
                break // Expected
            default:
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testEmotionConfidenceIsValid() async throws {
        // Arrange - emotions with confidence scores
        let scores = [
            EmotionScore(emotion: .happy, confidence: 0.95),
            EmotionScore(emotion: .calm, confidence: 0.5),
            EmotionScore(emotion: .anxious, confidence: 0.2)
        ]
        let analysis = EmotionAnalysis(emotionScores: scores)
        mockService.mockEmotionResponse = analysis
        
        // Act
        let result = try await mockService.analyzeEmotion(faceDescription: "smiling", voiceTone: nil, transcribedText: nil)
        
        // Assert - all confidence scores should be between 0 and 1
        for score in result.emotionScores {
            XCTAssertGreaterThanOrEqual(score.confidence, 0.0)
            XCTAssertLessThanOrEqual(score.confidence, 1.0)
        }
    }
    
    // MARK: - Insights Generation Tests
    
    func testGenerateInsightsSuccess() async throws {
        // Arrange
        mockService.mockInsights = [
            "You've been consistently happy this week",
            "Try meditation for better sleep",
            "Your mood improves after exercise"
        ]
        
        let checkIns: [EmotionCheckIn] = [] // Empty for mock
        
        // Act
        let insights = try await mockService.generateInsights(from: checkIns)
        
        // Assert
        XCTAssertEqual(insights.count, 3)
        XCTAssertTrue(insights[0].contains("happy"))
        XCTAssertTrue(insights[1].contains("meditation"))
    }
    
    func testGenerateInsightsFailure() async throws {
        // Arrange
        mockService.shouldFail = true
        
        // Act & Assert
        do {
            _ = try await mockService.generateInsights(from: [])
            XCTFail("Should have thrown error")
        } catch let error as GeminiError {
            switch error {
            case .apiError:
                break // Expected
            default:
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testGenerateInsightsWithEmptyHistory() async throws {
        // Act - empty check-in history
        let insights = try await mockService.generateInsights(from: [])
        
        // Assert - should still return some insights (default mocks)
        XCTAssertFalse(insights.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidAPIKeyError() {
        // Arrange - no API key provided
        
        // Act & Assert
        XCTAssertThrowsError(try GeminiService(apiKey: nil)) { error in
            XCTAssertTrue(error is GeminiError)
            if case GeminiError.invalidAPIKey = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testValidAPIKeyInitialization() throws {
        // Act
        let service = try GeminiService(apiKey: "test-api-key")
        
        // Assert
        XCTAssertNotNil(service)
    }
}
