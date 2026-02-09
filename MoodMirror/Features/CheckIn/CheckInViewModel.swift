//
//  CheckInViewModel.swift
//  MoodMirror
//
//  ViewModel for orchestrating the complete check-in flow
//

import SwiftUI
import AVFoundation

/// Check-in flow steps
enum CheckInStep {
    case camera
    case voice
    case notes
    case analyzing
    case results
}

/// Check-in view model
@MainActor
final class CheckInViewModel: ObservableObject {
    @Published var currentStep: CheckInStep = .camera
    @Published var capturedImage: UIImage?
    @Published var voiceRecordingURL: URL?
    @Published var userNotes: String = ""
    @Published var analysisResult: EmotionAnalysis?
    @Published var isAnalyzing = false
    @Published var error: Error?
    
    private let faceAnalyzer: FaceAnalyzer
    private let voiceAnalyzer: VoiceAnalyzer
    private let geminiService: GeminiServiceProtocol
    private let storageService: StorageServiceProtocol
    
    init(
        faceAnalyzer: FaceAnalyzer = FaceAnalyzer(),
        voiceAnalyzer: VoiceAnalyzer = VoiceAnalyzer(),
        geminiService: GeminiServiceProtocol,
        storageService: StorageServiceProtocol
    ) {
        self.faceAnalyzer = faceAnalyzer
        self.voiceAnalyzer = voiceAnalyzer
        self.geminiService = geminiService
        self.storageService = storageService
    }
    
    /// Handle photo capture
    func didCapturePhoto(_ image: UIImage) {
        capturedImage = image
        currentStep = .voice
    }
    
    /// Handle voice recording complete
    func didCompleteVoiceRecording(_ url: URL) {
        voiceRecordingURL = url
        currentStep = .notes
    }
    
    /// Skip voice recording
    func skipVoiceRecording() {
        voiceRecordingURL = nil
        currentStep = .notes
    }
    
    /// Complete check-in and analyze
    func completeCheckIn() async {
        guard let image = capturedImage else {
            error = NSError(domain: "CheckIn", code: 1, userInfo: [NSLocalizedDescriptionKey: "No photo captured"])
            return
        }
        
        isAnalyzing = true
        currentStep = .analyzing
        error = nil
        
        do {
            // Step 1: Prepare image for API (resize and compress)
            guard let imageData = faceAnalyzer.prepareImageForAPI(image) else {
                throw NSError(domain: "CheckIn", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare image"])
            }
            
            // Step 2: Transcribe voice (if available)
            var voiceTranscript: String?
            var voiceTone: String?
            
            if let voiceURL = voiceRecordingURL {
                do {
                    let voiceResult = try await voiceAnalyzer.transcribe(audioURL: voiceURL)
                    voiceTranscript = voiceResult.transcription
                    voiceTone = voiceResult.voiceTone
                } catch {
                    // Voice analysis is optional, continue without it
                    print("Voice analysis failed: \(error)")
                }
            }
            
            // Step 3: Analyze emotion with Gemini using actual image
            print("📸 Sending to Gemini - Image: \(imageData.count) bytes")
            print("🎤 Voice tone: \(voiceTone ?? "none"), Transcript: \(voiceTranscript ?? "none")")
            
            let analysis = try await geminiService.analyzeEmotionWithImage(
                image: imageData,
                voiceTone: voiceTone,
                transcribedText: voiceTranscript
            )
            
            print("✅ Gemini returned: \(analysis.primaryEmotion.rawValue) - \(analysis.aiInsight ?? "no insight")")
            
            // Step 4: Save to storage
            _ = try await storageService.save(
                analysis: analysis,
                notes: userNotes.isEmpty ? nil : userNotes
            )
            
            analysisResult = analysis
            currentStep = .results
            isAnalyzing = false
            
        } catch {
            self.error = error
            isAnalyzing = false
        }
    }
    
    /// Reset for new check-in
    func reset() {
        currentStep = .camera
        capturedImage = nil
        voiceRecordingURL = nil
        userNotes = ""
        analysisResult = nil
        isAnalyzing = false
        error = nil
    }
    
    /// Go back to previous step
    func goBack() {
        switch currentStep {
        case .camera:
            break
        case .voice:
            currentStep = .camera
            capturedImage = nil
        case .notes:
            currentStep = .voice
            voiceRecordingURL = nil
        case .analyzing:
            break
        case .results:
            break
        }
    }
}
