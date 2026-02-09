//
//  EmotionCheckIn+CoreData.swift
//  MoodMirror
//
//  Core Data entity extension
//

import Foundation
import CoreData

@objc(EmotionCheckIn)
public class EmotionCheckIn: NSManagedObject {
    
}

extension EmotionCheckIn {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EmotionCheckIn> {
        return NSFetchRequest<EmotionCheckIn>(entityName: "EmotionCheckIn")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var primaryEmotion: String
    @NSManaged public var emotionScores: Data?
    @NSManaged public var notes: String?
    @NSManaged public var aiInsight: String?
    @NSManaged public var voiceTranscript: String?
    
    /// Convert to EmotionAnalysis model
    var analysis: EmotionAnalysis? {
        guard let emotionScores = emotionScores,
              let scores = try? JSONDecoder().decode([EmotionScore].self, from: emotionScores),
              EmotionType(rawValue: primaryEmotion) != nil else {
            return nil
        }
        
        return EmotionAnalysis(
            emotionScores: scores,
            aiInsight: aiInsight,
            voiceTranscript: voiceTranscript
        )
    }
    
    /// Create from EmotionAnalysis
    static func create(from analysis: EmotionAnalysis, notes: String? = nil, context: NSManagedObjectContext) throws -> EmotionCheckIn {
        let checkIn = EmotionCheckIn(context: context)
        checkIn.id = analysis.id
        checkIn.timestamp = analysis.timestamp
        checkIn.primaryEmotion = analysis.primaryEmotion.rawValue
        checkIn.emotionScores = try JSONEncoder().encode(analysis.emotionScores)
        checkIn.notes = notes
        checkIn.aiInsight = analysis.aiInsight
        checkIn.voiceTranscript = analysis.voiceTranscript
        
        return checkIn
    }
}

extension EmotionCheckIn: Identifiable {
    
}
