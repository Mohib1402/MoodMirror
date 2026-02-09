//
//  CheckInViewModelTests.swift
//  MoodMirrorTests
//
//  Tests for CheckInViewModel
//

import XCTest
@testable import MoodMirror

final class CheckInViewModelTests: XCTestCase {
    var viewModel: CheckInViewModel!
    var mockGeminiService: MockGeminiService!
    var mockStorageService: StorageService!
    var testController: PersistenceController!
    
    @MainActor
    override func setUp() async throws {
        testController = PersistenceController(inMemory: true)
        mockStorageService = StorageService(persistenceController: testController)
        mockGeminiService = MockGeminiService()
        
        viewModel = CheckInViewModel(
            geminiService: mockGeminiService,
            storageService: mockStorageService
        )
    }
    
    @MainActor
    override func tearDown() async throws {
        try await mockStorageService.deleteAll()
        viewModel = nil
        mockGeminiService = nil
        mockStorageService = nil
        testController = nil
    }
    
    // MARK: - Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertEqual(viewModel.currentStep, .camera)
        XCTAssertNil(viewModel.capturedImage)
        XCTAssertNil(viewModel.voiceRecordingURL)
        XCTAssertEqual(viewModel.userNotes, "")
        XCTAssertNil(viewModel.analysisResult)
        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertNil(viewModel.error)
    }
    
    @MainActor
    func testDidCapturePhoto() {
        let testImage = createTestImage()
        
        viewModel.didCapturePhoto(testImage)
        
        XCTAssertEqual(viewModel.capturedImage, testImage)
        XCTAssertEqual(viewModel.currentStep, .voice)
    }
    
    @MainActor
    func testDidCompleteVoiceRecording() {
        let testURL = URL(fileURLWithPath: "/test/audio.m4a")
        
        viewModel.didCompleteVoiceRecording(testURL)
        
        XCTAssertEqual(viewModel.voiceRecordingURL, testURL)
        XCTAssertEqual(viewModel.currentStep, .notes)
    }
    
    @MainActor
    func testSkipVoiceRecording() {
        viewModel.skipVoiceRecording()
        
        XCTAssertNil(viewModel.voiceRecordingURL)
        XCTAssertEqual(viewModel.currentStep, .notes)
    }
    
    @MainActor
    func testCompleteCheckInWithoutPhoto() async {
        await viewModel.completeCheckIn()
        
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isAnalyzing)
    }
    
    @MainActor
    func testCompleteCheckInSuccess() async {
        // Setup
        let testImage = createTestImage(size: CGSize(width: 400, height: 400))
        viewModel.capturedImage = testImage
        viewModel.userNotes = "Test notes"
        
        mockGeminiService.shouldFail = false
        mockGeminiService.mockEmotionResponse = EmotionAnalysis(
            emotionScores: [EmotionScore(emotion: .happy, confidence: 0.9)],
            aiInsight: "You seem happy!"
        )
        
        // Execute
        await viewModel.completeCheckIn()
        
        // Verify
        XCTAssertNotNil(viewModel.analysisResult)
        XCTAssertEqual(viewModel.currentStep, .results)
        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertNil(viewModel.error)
    }
    
    @MainActor
    func testCompleteCheckInWithGeminiError() async {
        // Setup
        let testImage = createTestImage(size: CGSize(width: 400, height: 400))
        viewModel.capturedImage = testImage
        
        mockGeminiService.shouldFail = true
        
        // Execute
        await viewModel.completeCheckIn()
        
        // Verify
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertNil(viewModel.analysisResult)
    }
    
    @MainActor
    func testReset() {
        // Setup with data
        viewModel.capturedImage = createTestImage()
        viewModel.voiceRecordingURL = URL(fileURLWithPath: "/test/audio.m4a")
        viewModel.userNotes = "Test notes"
        viewModel.currentStep = .results
        viewModel.isAnalyzing = true
        
        // Reset
        viewModel.reset()
        
        // Verify
        XCTAssertEqual(viewModel.currentStep, .camera)
        XCTAssertNil(viewModel.capturedImage)
        XCTAssertNil(viewModel.voiceRecordingURL)
        XCTAssertEqual(viewModel.userNotes, "")
        XCTAssertNil(viewModel.analysisResult)
        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertNil(viewModel.error)
    }
    
    @MainActor
    func testGoBackFromVoice() {
        viewModel.currentStep = .voice
        viewModel.capturedImage = createTestImage()
        
        viewModel.goBack()
        
        XCTAssertEqual(viewModel.currentStep, .camera)
        XCTAssertNil(viewModel.capturedImage)
    }
    
    @MainActor
    func testGoBackFromNotes() {
        viewModel.currentStep = .notes
        viewModel.voiceRecordingURL = URL(fileURLWithPath: "/test/audio.m4a")
        
        viewModel.goBack()
        
        XCTAssertEqual(viewModel.currentStep, .voice)
        XCTAssertNil(viewModel.voiceRecordingURL)
    }
    
    @MainActor
    func testCheckInStepEnum() {
        let steps: [CheckInStep] = [.camera, .voice, .notes, .analyzing, .results]
        XCTAssertEqual(steps.count, 5)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
