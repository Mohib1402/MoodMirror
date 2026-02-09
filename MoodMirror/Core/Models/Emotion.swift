//
//  Emotion.swift
//  MoodMirror
//
//  Emotion types and scoring model
//

import Foundation
import SwiftUI

/// Represents different emotion types
enum EmotionType: String, Codable, CaseIterable {
    case happy
    case sad
    case angry
    case anxious
    case neutral
    case excited
    case fearful
    case disgusted
    case surprised
    case calm
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .angry: return "😠"
        case .anxious: return "😰"
        case .neutral: return "😐"
        case .excited: return "🤩"
        case .fearful: return "😨"
        case .disgusted: return "🤢"
        case .surprised: return "😲"
        case .calm: return "😌"
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .sad: return "cloud.rain"
        case .angry: return "flame"
        case .anxious: return "wind"
        case .neutral: return "circle"
        case .excited: return "star.fill"
        case .fearful: return "exclamationmark.triangle"
        case .disgusted: return "xmark.circle"
        case .surprised: return "sparkles"
        case .calm: return "leaf"
        }
    }
    
    var color: Color {
        switch self {
        case .happy: return .yellow
        case .sad: return .blue
        case .angry: return .red
        case .anxious: return .orange
        case .neutral: return .gray
        case .excited: return .pink
        case .fearful: return .purple
        case .disgusted: return .green
        case .surprised: return .cyan
        case .calm: return .mint
        }
    }
}

/// Represents an emotion with confidence score
struct EmotionScore: Codable, Identifiable {
    let id: UUID
    let emotion: EmotionType
    let confidence: Double // 0.0 to 1.0
    
    init(emotion: EmotionType, confidence: Double) {
        self.id = UUID()
        self.emotion = emotion
        self.confidence = min(max(confidence, 0.0), 1.0) // Clamp between 0 and 1
    }
}

/// Complete emotion analysis result
struct EmotionAnalysis: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let emotionScores: [EmotionScore]
    let primaryEmotion: EmotionType
    let aiInsight: String?
    let voiceTranscript: String?
    
    init(emotionScores: [EmotionScore], aiInsight: String? = nil, voiceTranscript: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.emotionScores = emotionScores
        
        // Primary emotion is the one with highest confidence
        self.primaryEmotion = emotionScores.max(by: { $0.confidence < $1.confidence })?.emotion ?? .neutral
        self.aiInsight = aiInsight
        self.voiceTranscript = voiceTranscript
    }
    
    /// Get confidence score for a specific emotion
    func confidence(for emotion: EmotionType) -> Double {
        emotionScores.first(where: { $0.emotion == emotion })?.confidence ?? 0.0
    }
}
