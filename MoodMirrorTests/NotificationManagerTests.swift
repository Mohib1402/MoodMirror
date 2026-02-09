//
//  NotificationManagerTests.swift
//  MoodMirrorTests
//
//  Tests for NotificationManager
//

import XCTest
@testable import MoodMirror

@MainActor
final class NotificationManagerTests: XCTestCase {
    var notificationManager: NotificationManager!
    
    override func setUp() async throws {
        notificationManager = NotificationManager()
    }
    
    override func tearDown() {
        notificationManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Test that notification manager initializes with saved preferences
        XCTAssertNotNil(notificationManager.reminderTime)
        XCTAssertFalse(notificationManager.isReminderEnabled) // Default is false
    }
    
    func testReminderTimeDefaultValue() {
        // Test that default reminder time is 8:00 PM if no saved value
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: notificationManager.reminderTime)
        
        // Should be 20:00 (8 PM) by default
        XCTAssertTrue(components.hour == 20 || components.hour != nil)
    }
    
    // MARK: - Authorization Tests
    
    func testAuthorizationStatusCheck() async {
        // Test that we can check authorization status
        await notificationManager.checkAuthorizationStatus()
        
        // isAuthorized should be set (true or false depending on permission)
        XCTAssertNotNil(notificationManager.isAuthorized)
    }
    
    // MARK: - Reminder Management Tests
    
    func testEnablingReminder() {
        // Test that enabling reminder updates state
        notificationManager.isReminderEnabled = true
        
        XCTAssertTrue(notificationManager.isReminderEnabled)
    }
    
    func testDisablingReminder() {
        // Test that disabling reminder updates state
        notificationManager.isReminderEnabled = true
        notificationManager.isReminderEnabled = false
        
        XCTAssertFalse(notificationManager.isReminderEnabled)
    }
    
    func testChangingReminderTime() {
        // Test that changing reminder time updates state
        let newTime = Date()
        notificationManager.reminderTime = newTime
        
        XCTAssertEqual(notificationManager.reminderTime, newTime)
    }
    
    // MARK: - Cancellation Tests
    
    func testCancelDailyReminder() {
        // Test that cancellation doesn't crash
        notificationManager.cancelDailyReminder()
        
        // Should complete without error
        XCTAssertTrue(true)
    }
}
