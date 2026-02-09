//
//  HapticManager.swift
//  MoodMirror
//
//  Manages haptic feedback throughout the app
//

import UIKit

/// Haptic feedback manager
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// Light impact feedback (button taps)
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium impact feedback (selections)
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Heavy impact feedback (important actions)
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Success feedback (completion, positive actions)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Warning feedback (caution)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Error feedback (failures, errors)
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Selection changed feedback (picker, segmented control)
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
