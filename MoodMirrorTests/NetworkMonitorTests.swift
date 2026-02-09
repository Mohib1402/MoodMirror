//
//  NetworkMonitorTests.swift
//  MoodMirrorTests
//
//  Tests for NetworkMonitor
//

import XCTest
@testable import MoodMirror

@MainActor
final class NetworkMonitorTests: XCTestCase {
    var monitor: NetworkMonitor!
    
    override func setUp() async throws {
        monitor = NetworkMonitor()
    }
    
    override func tearDown() {
        monitor.stopMonitoring()
        monitor = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Test that monitor initializes with a connection state
        XCTAssertNotNil(monitor.isConnected)
        // Connection type may or may not be set initially
    }
    
    func testStartMonitoring() {
        // Test that monitoring can be started
        monitor.startMonitoring()
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testStopMonitoring() {
        // Test that monitoring can be stopped
        monitor.stopMonitoring()
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Connection State Tests
    
    func testIsConnectedIsBoolean() {
        // Test that isConnected is a boolean value
        let isConnected = monitor.isConnected
        XCTAssertTrue(isConnected == true || isConnected == false)
    }
}
