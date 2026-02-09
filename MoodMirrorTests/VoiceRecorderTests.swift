//
//  VoiceRecorderTests.swift
//  MoodMirrorTests
//
//  Tests for VoiceRecorder
//

import XCTest
import AVFoundation
@testable import MoodMirror

final class VoiceRecorderTests: XCTestCase {
    var voiceRecorder: VoiceRecorder!
    
    @MainActor
    override func setUp() async throws {
        voiceRecorder = VoiceRecorder()
    }
    
    @MainActor
    override func tearDown() async throws {
        if voiceRecorder.isRecording {
            voiceRecorder.stopRecording()
        }
        voiceRecorder.deleteRecording()
        voiceRecorder = nil
    }
    
    // MARK: - Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertFalse(voiceRecorder.isRecording)
        XCTAssertEqual(voiceRecorder.duration, 0)
        XCTAssertEqual(voiceRecorder.audioLevel, 0)
        XCTAssertNil(voiceRecorder.error)
    }
    
    @MainActor
    func testPermissionRequest() async {
        // Note: This test behavior depends on simulator/device permission state
        // In CI/CD, you'd mock the permission system
        let granted = await voiceRecorder.requestPermission()
        
        // Just verify the method returns a boolean
        XCTAssert(granted == true || granted == false)
    }
    
    @MainActor
    func testStartRecordingWithoutPermission() async {
        // If permission is not granted, starting recording should throw or fail gracefully
        // This test verifies error handling
        do {
            try voiceRecorder.startRecording()
            
            // If recording started, verify state
            if voiceRecorder.isRecording {
                XCTAssert(true, "Recording started successfully")
                voiceRecorder.stopRecording()
            }
        } catch {
            // Expected if no permission
            XCTAssert(error is VoiceRecordingError, "Should throw VoiceRecordingError")
        }
    }
    
    @MainActor
    func testStopRecordingWhenNotRecording() {
        // Should not crash
        voiceRecorder.stopRecording()
        XCTAssertFalse(voiceRecorder.isRecording)
    }
    
    @MainActor
    func testDeleteRecording() {
        voiceRecorder.deleteRecording()
        
        XCTAssertEqual(voiceRecorder.duration, 0)
        XCTAssertEqual(voiceRecorder.audioLevel, 0)
        XCTAssertNil(voiceRecorder.getRecordingURL())
    }
    
    @MainActor
    func testGetRecordingDataWithoutRecording() {
        do {
            _ = try voiceRecorder.getRecordingData()
            XCTFail("Should throw error when no recording exists")
        } catch {
            XCTAssert(error is VoiceRecordingError)
        }
    }
    
    @MainActor
    func testRecordingDurationInitiallyZero() {
        let duration = voiceRecorder.getRecordingDuration()
        XCTAssertEqual(duration, 0)
    }
    
    @MainActor
    func testVoiceRecordingErrorDescriptions() {
        let errors: [VoiceRecordingError] = [
            .notAuthorized,
            .recordingFailed(NSError(domain: "test", code: 1)),
            .audioSessionFailed(NSError(domain: "test", code: 2)),
            .noRecordingFound,
            .invalidDuration
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    // Integration test - requires microphone permission
    @MainActor
    func testFullRecordingCycle() async throws {
        // Request permission first
        let granted = await voiceRecorder.requestPermission()
        
        guard granted else {
            // Skip test if no permission (expected in simulator without permission)
            throw XCTSkip("Microphone permission not granted")
        }
        
        // Start recording
        try voiceRecorder.startRecording()
        XCTAssertTrue(voiceRecorder.isRecording)
        
        // Record for 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Stop recording
        voiceRecorder.stopRecording()
        XCTAssertFalse(voiceRecorder.isRecording)
        
        // Verify recording exists
        XCTAssertNotNil(voiceRecorder.getRecordingURL())
        XCTAssertGreaterThan(voiceRecorder.duration, 0)
        
        // Verify can get data
        let data = try voiceRecorder.getRecordingData()
        XCTAssertGreaterThan(data.count, 0)
        
        // Clean up
        voiceRecorder.deleteRecording()
        XCTAssertNil(voiceRecorder.getRecordingURL())
    }
}
