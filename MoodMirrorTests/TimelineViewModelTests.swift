//
//  TimelineViewModelTests.swift
//  MoodMirrorTests
//
//  Tests for TimelineViewModel
//

import XCTest
import Combine
@testable import MoodMirror

final class TimelineViewModelTests: XCTestCase {
    var viewModel: TimelineViewModel!
    var mockStorageService: StorageService!
    var testController: PersistenceController!
    var cancellables: Set<AnyCancellable>!
    
    @MainActor
    override func setUp() async throws {
        testController = PersistenceController(inMemory: true)
        mockStorageService = StorageService(persistenceController: testController)
        viewModel = TimelineViewModel(storageService: mockStorageService)
        cancellables = Set<AnyCancellable>()
    }
    
    @MainActor
    override func tearDown() async throws {
        try await mockStorageService.deleteAll()
        viewModel = nil
        mockStorageService = nil
        testController = nil
        cancellables = nil
    }
    
    // MARK: - Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertTrue(viewModel.checkIns.isEmpty)
        XCTAssertTrue(viewModel.groupedCheckIns.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.searchText, "")
    }
    
    @MainActor
    func testFetchCheckIns() async throws {
        // Create test check-ins
        let analysis1 = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        let analysis2 = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .sad, confidence: 0.7)])
        
        _ = try await mockStorageService.save(analysis: analysis1, notes: "Test 1")
        _ = try await mockStorageService.save(analysis: analysis2, notes: "Test 2")
        
        // Fetch check-ins
        await viewModel.fetchCheckIns()
        
        // Verify
        XCTAssertEqual(viewModel.checkIns.count, 2)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.groupedCheckIns.isEmpty)
    }
    
    @MainActor
    func testFetchCheckInsInDateRange() async throws {
        // Create check-ins with different dates
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        
        let analysis = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        
        let checkIn1 = try await mockStorageService.save(analysis: analysis, notes: "Old")
        checkIn1.timestamp = twoDaysAgo
        
        let checkIn2 = try await mockStorageService.save(analysis: analysis, notes: "Recent")
        checkIn2.timestamp = yesterday
        
        try testController.container.viewContext.save()
        
        // Fetch only yesterday onwards
        await viewModel.fetchCheckIns(from: yesterday, to: now)
        
        // Verify - should only get the recent one
        XCTAssertEqual(viewModel.checkIns.count, 1)
        XCTAssertEqual(viewModel.checkIns.first?.notes, "Recent")
    }
    
    @MainActor
    func testDeleteCheckIn() async throws {
        // Create check-in
        let analysis = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        let checkIn = try await mockStorageService.save(analysis: analysis)
        
        await viewModel.fetchCheckIns()
        XCTAssertEqual(viewModel.checkIns.count, 1)
        
        // Delete
        await viewModel.deleteCheckIn(checkIn)
        
        // Verify
        XCTAssertTrue(viewModel.checkIns.isEmpty)
        XCTAssertTrue(viewModel.groupedCheckIns.isEmpty)
    }
    
    @MainActor
    func testRefresh() async throws {
        // Create initial check-in
        let analysis = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        _ = try await mockStorageService.save(analysis: analysis)
        
        await viewModel.fetchCheckIns()
        XCTAssertEqual(viewModel.checkIns.count, 1)
        
        // Add another check-in directly to storage
        _ = try await mockStorageService.save(analysis: analysis)
        
        // Refresh
        await viewModel.refresh()
        
        // Verify
        XCTAssertEqual(viewModel.checkIns.count, 2)
    }
    
    @MainActor
    func testGroupCheckInsByDate() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let analysis = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        
        // Create check-ins for different days
        let checkIn1 = try await mockStorageService.save(analysis: analysis)
        checkIn1.timestamp = today
        
        let checkIn2 = try await mockStorageService.save(analysis: analysis)
        checkIn2.timestamp = yesterday
        
        try testController.container.viewContext.save()
        
        await viewModel.fetchCheckIns()
        
        // Verify grouping
        XCTAssertEqual(viewModel.groupedCheckIns.count, 2)
        XCTAssertEqual(viewModel.sortedDates().count, 2)
    }
    
    @MainActor
    func testSearchFilter() async throws {
        // Create check-ins with different emotions
        let happy = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        let sad = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .sad, confidence: 0.7)])
        
        _ = try await mockStorageService.save(analysis: happy, notes: "Feeling great")
        _ = try await mockStorageService.save(analysis: sad, notes: "Feeling down")
        
        await viewModel.fetchCheckIns()
        XCTAssertEqual(viewModel.checkIns.count, 2)
        
        // Apply search filter
        viewModel.searchText = "great"
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 400_000_000)
        
        // Verify filtered results
        let filteredCount = viewModel.groupedCheckIns.values.flatMap { $0 }.count
        XCTAssertEqual(filteredCount, 1)
    }
    
    @MainActor
    func testEmotionFilter() async throws {
        // Create check-ins with different emotions
        let happy = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        let sad = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .sad, confidence: 0.7)])
        
        _ = try await mockStorageService.save(analysis: happy)
        _ = try await mockStorageService.save(analysis: sad)
        
        await viewModel.fetchCheckIns()
        XCTAssertEqual(viewModel.checkIns.count, 2)
        
        // Apply emotion filter
        viewModel.selectedFilter = .emotion(.happy)
        
        // Wait for filter to apply
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify filtered results
        let filteredCount = viewModel.groupedCheckIns.values.flatMap { $0 }.count
        XCTAssertEqual(filteredCount, 1)
    }
    
    @MainActor
    func testSortedDates() async throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let analysis = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        
        let checkIn1 = try await mockStorageService.save(analysis: analysis)
        checkIn1.timestamp = yesterday
        
        let checkIn2 = try await mockStorageService.save(analysis: analysis)
        checkIn2.timestamp = today
        
        try testController.container.viewContext.save()
        
        await viewModel.fetchCheckIns()
        
        let sortedDates = viewModel.sortedDates()
        XCTAssertEqual(sortedDates.count, 2)
        XCTAssertEqual(sortedDates.first, today) // Most recent first
        XCTAssertEqual(sortedDates.last, yesterday)
    }
    
    @MainActor
    func testCheckInsForDate() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let analysis = EmotionAnalysis(emotionScores: [EmotionScore(emotion: .happy, confidence: 0.8)])
        
        let checkIn = try await mockStorageService.save(analysis: analysis)
        checkIn.timestamp = today
        
        try testController.container.viewContext.save()
        
        await viewModel.fetchCheckIns()
        
        let checkInsToday = viewModel.checkIns(for: today)
        XCTAssertEqual(checkInsToday.count, 1)
        XCTAssertEqual(checkInsToday.first?.id, checkIn.id)
    }
}
