//
//  NotificationManager.swift
//  MoodMirror
//
//  Manages local notifications for daily check-in reminders
//

import Foundation
import UserNotifications
import UIKit

/// Notification manager errors
enum NotificationError: LocalizedError {
    case authorizationDenied
    case schedulingFailed
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification permission denied"
        case .schedulingFailed:
            return "Failed to schedule notification"
        }
    }
}

/// Notification manager
@MainActor
final class NotificationManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var reminderTime: Date {
        didSet {
            UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
            if isReminderEnabled {
                Task {
                    await scheduleDailyReminder()
                }
            }
        }
    }
    @Published var isReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isReminderEnabled, forKey: "isReminderEnabled")
            if isReminderEnabled {
                Task {
                    await scheduleDailyReminder()
                }
            } else {
                cancelDailyReminder()
            }
        }
    }
    
    private let center = UNUserNotificationCenter.current()
    private let reminderIdentifier = "daily-checkin-reminder"
    
    init() {
        // Load saved preferences or defaults
        let savedTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date
        self.reminderTime = savedTime ?? Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        self.isReminderEnabled = UserDefaults.standard.bool(forKey: "isReminderEnabled")
        
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    /// Request notification permission
    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        isAuthorized = granted
        
        if !granted {
            throw NotificationError.authorizationDenied
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    /// Schedule daily check-in reminder
    func scheduleDailyReminder() async {
        // Cancel existing
        cancelDailyReminder()
        
        // Ensure we have permission
        if !isAuthorized {
            do {
                try await requestAuthorization()
            } catch {
                return
            }
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Check-In Time"
        content.body = notificationMessage()
        content.sound = .default
        content.badge = 1
        
        // Create trigger (daily at specified time)
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
        dateComponents.second = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
    
    /// Cancel daily reminder
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }
    
    /// Get randomized notification message
    private func notificationMessage() -> String {
        let messages = [
            "How are you feeling today?",
            "Time for your daily check-in",
            "Let's capture today's emotions",
            "Take a moment to check in with yourself",
            "Your daily mood check awaits",
            "Ready to track your emotions?"
        ]
        return messages.randomElement() ?? "Time for your daily check-in"
    }
    
    /// Open app settings for notification permissions
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
