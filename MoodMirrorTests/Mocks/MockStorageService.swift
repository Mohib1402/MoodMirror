//
//  MockStorageService.swift
//  MoodMirrorTests
//
//  Mock storage service for testing
//

import Foundation
@testable import MoodMirror

class MockStorageService: StorageServiceProtocol {
    var checkIns: [EmotionCheckIn] = []
    var shouldThrowError = false
    
    func save(analysis: EmotionAnalysis, notes: String?, voiceTranscript: String?) async throws -> EmotionCheckIn {
        if shouldThrowError {
            throw StorageError.saveFailed
        }
        
        let checkIn = EmotionCheckIn(context: PersistenceController.preview.container.viewContext)
        checkIn.id = UUID()
        checkIn.timestamp = Date()
        checkIn.primaryEmotion = analysis.primaryEmotion.rawValue
        checkIn.notes = notes
        checkIn.aiInsight = analysis.insight
        checkIn.voiceTranscript = voiceTranscript
        
        // Store emotion scores
        if let scoresData = try? JSONEncoder().encode(analysis.emotionScores) {
            checkIn.emotionScores = scoresData
        }
        
        checkIns.append(checkIn)
        return checkIn
    }
    
    func fetch(from startDate: Date, to endDate: Date) async throws -> [EmotionCheckIn] {
        if shouldThrowError {
            throw StorageError.fetchFailed
        }
        return checkIns.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
    
    func fetchAll() async throws -> [EmotionCheckIn] {
        if shouldThrowError {
            throw StorageError.fetchFailed
        }
        return checkIns
    }
    
    func delete(checkIn: EmotionCheckIn) async throws {
        if shouldThrowError {
            throw StorageError.deleteFailed
        }
        checkIns.removeAll { $0.id == checkIn.id }
    }
    
    func deleteAll() async throws {
        if shouldThrowError {
            throw StorageError.deleteFailed
        }
        checkIns.removeAll()
    }
    
    // Helper method to create mock check-ins
    func createMockCheckIn(emotion: EmotionType, timestamp: Date = Date()) -> EmotionCheckIn {
        let checkIn = EmotionCheckIn(context: PersistenceController.preview.container.viewContext)
        checkIn.id = UUID()
        checkIn.timestamp = timestamp
        checkIn.primaryEmotion = emotion.rawValue
        checkIn.notes = "Test notes"
        checkIn.aiInsight = "Test insight"
        
        // Create emotion scores
        let scores = [
            EmotionScore(emotion: emotion, confidence: 0.8)
        ]
        
        if let scoresData = try? JSONEncoder().encode(scores) {
            checkIn.emotionScores = scoresData
        }
        
        return checkIn
    }
}
