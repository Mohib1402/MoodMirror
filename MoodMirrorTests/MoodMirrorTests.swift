//
//  MoodMirrorTests.swift
//  MoodMirrorTests
//
//  Unit tests for MoodMirror
//

import XCTest
@testable import MoodMirror

final class MoodMirrorTests: XCTestCase {
    
    func testPersistenceControllerInitialization() {
        // Test that Core Data stack initializes correctly
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container)
    }
    
    func testPreviewPersistenceController() {
        // Test that preview instance works
        let controller = PersistenceController.preview
        XCTAssertNotNil(controller.container)
    }
}
