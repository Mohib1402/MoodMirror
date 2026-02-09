//
//  AppStateTests.swift
//  MoodMirrorTests
//
//  Tests for AppState
//

import XCTest
@testable import MoodMirror

@MainActor
final class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() async throws {
        appState = AppState(
            storageService: StorageService(persistenceController: PersistenceController(inMemory: true)),
            geminiService: MockGeminiService()
        )
    }
    
    override func tearDown() async throws {
        appState = nil
    }
    
    func testInitialState() {
        // Assert initial values
        XCTAssertEqual(appState.selectedTab, .checkIn)
        XCTAssertTrue(appState.isOnline)
        XCTAssertFalse(appState.isLoading)
        XCTAssertNil(appState.error)
        XCTAssertFalse(appState.showError)
    }
    
    func testTabSelection() {
        // Act
        appState.selectedTab = .timeline
        
        // Assert
        XCTAssertEqual(appState.selectedTab, .timeline)
    }
    
    func testErrorHandling() {
        // Arrange
        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // Act
        appState.handleError(testError)
        
        // Assert
        XCTAssertNotNil(appState.error)
        XCTAssertTrue(appState.showError)
        XCTAssertEqual((appState.error as NSError?)?.localizedDescription, "Test error")
    }
    
    func testClearError() {
        // Arrange
        let testError = NSError(domain: "test", code: 1)
        appState.handleError(testError)
        
        // Act
        appState.clearError()
        
        // Assert
        XCTAssertNil(appState.error)
        XCTAssertFalse(appState.showError)
    }
    
    func testServicesInjection() {
        // Assert services are properly injected
        XCTAssertNotNil(appState.storageService)
        XCTAssertNotNil(appState.geminiService)
    }
    
    func testTabEnum() {
        // Test all tabs
        let allTabs = AppState.Tab.allCases
        
        XCTAssertEqual(allTabs.count, 3)
        XCTAssertEqual(AppState.Tab.checkIn.title, "Check-In")
        XCTAssertEqual(AppState.Tab.timeline.title, "Timeline")
        XCTAssertEqual(AppState.Tab.insights.title, "Insights")
        
        XCTAssertEqual(AppState.Tab.checkIn.icon, "camera.fill")
        XCTAssertEqual(AppState.Tab.timeline.icon, "list.bullet")
        XCTAssertEqual(AppState.Tab.insights.icon, "chart.line.uptrend.xyaxis")
    }
}
