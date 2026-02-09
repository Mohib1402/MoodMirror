//
//  HapticManagerTests.swift
//  MoodMirrorTests
//
//  Tests for HapticManager
//

import XCTest
@testable import MoodMirror

final class HapticManagerTests: XCTestCase {
    
    // MARK: - Singleton Tests
    
    func testSharedInstanceExists() {
        let instance = HapticManager.shared
        XCTAssertNotNil(instance)
    }
    
    func testSharedInstanceIsSingleton() {
        let instance1 = HapticManager.shared
        let instance2 = HapticManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Impact Feedback Tests
    
    func testLightImpactDoesNotCrash() {
        HapticManager.shared.lightImpact()
        // Should complete without crash
        XCTAssertTrue(true)
    }
    
    func testMediumImpactDoesNotCrash() {
        HapticManager.shared.mediumImpact()
        // Should complete without crash
        XCTAssertTrue(true)
    }
    
    func testHeavyImpactDoesNotCrash() {
        HapticManager.shared.heavyImpact()
        // Should complete without crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Notification Feedback Tests
    
    func testSuccessFeedbackDoesNotCrash() {
        HapticManager.shared.success()
        // Should complete without crash
        XCTAssertTrue(true)
    }
    
    func testWarningFeedbackDoesNotCrash() {
        HapticManager.shared.warning()
        // Should complete without crash
        XCTAssertTrue(true)
    }
    
    func testErrorFeedbackDoesNotCrash() {
        HapticManager.shared.error()
        // Should complete without crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Selection Feedback Tests
    
    func testSelectionChangedDoesNotCrash() {
        HapticManager.shared.selectionChanged()
        // Should complete without crash
        XCTAssertTrue(true)
    }
}
