//
//  VoiceAnalyzer.swift
//  MoodMirror
//
//  Speech recognition and voice analysis
//

import Speech
import AVFoundation

/// Errors that can occur during voice analysis
enum VoiceAnalysisError: Error, LocalizedError {
    case notAuthorized
    case recognitionFailed(Error)
    case noAudioFile
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition access is required. Please enable it in Settings."
        case .recognitionFailed(let error):
            return "Recognition failed: \(error.localizedDescription)"
        case .noAudioFile:
            return "No audio file provided."
        case .transcriptionFailed:
            return "Failed to transcribe audio."
        }
    }
}

/// Result of voice analysis
struct VoiceAnalysisResult {
    let transcription: String
    let confidence: Float
    let voiceTone: String
}

/// Voice analyzer using Speech framework
final class VoiceAnalyzer {
    
    /// Request speech recognition permission
    func requestPermission() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        
        switch status {
        case .authorized:
            return true
            
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
            
        case .denied, .restricted:
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// Transcribe audio file
    func transcribe(audioURL: URL) async throws -> VoiceAnalysisResult {
        // Check permission
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw VoiceAnalysisError.notAuthorized
        }
        
        // Create recognizer
        guard let recognizer = SFSpeechRecognizer() else {
            throw VoiceAnalysisError.recognitionFailed(NSError(domain: "VoiceAnalyzer", code: -1))
        }
        
        guard recognizer.isAvailable else {
            throw VoiceAnalysisError.recognitionFailed(NSError(domain: "VoiceAnalyzer", code: -2))
        }
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        
        // Perform recognition
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: VoiceAnalysisError.recognitionFailed(error))
                    return
                }
                
                guard let result = result, result.isFinal else {
                    return
                }
                
                let transcription = result.bestTranscription.formattedString
                let confidence = result.bestTranscription.segments.first?.confidence ?? 0.0
                
                // Analyze voice tone from audio characteristics
                let voiceTone = self.analyzeVoiceTone(from: audioURL)
                
                let analysisResult = VoiceAnalysisResult(
                    transcription: transcription,
                    confidence: confidence,
                    voiceTone: voiceTone
                )
                
                continuation.resume(returning: analysisResult)
            }
        }
    }
    
    /// Analyze voice tone from audio file
    private func analyzeVoiceTone(from url: URL) -> String {
        // Simple tone analysis based on audio file properties
        // In production, this could use more sophisticated analysis
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return "neutral tone"
        }
        
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return "neutral tone"
        }
        
        do {
            try audioFile.read(into: buffer)
            
            // Analyze amplitude and frequency characteristics
            if let channelData = buffer.floatChannelData?[0] {
                var sum: Float = 0
                var sumSquared: Float = 0
                
                for i in 0..<Int(buffer.frameLength) {
                    let sample = channelData[i]
                    sum += abs(sample)
                    sumSquared += sample * sample
                }
                
                _ = sum / Float(buffer.frameLength) // average for future use
                let rms = sqrt(sumSquared / Float(buffer.frameLength))
                
                // Classify tone based on amplitude characteristics
                if rms > 0.3 {
                    return "energetic, loud tone"
                } else if rms > 0.15 {
                    return "confident, clear tone"
                } else if rms > 0.05 {
                    return "calm, soft tone"
                } else {
                    return "quiet, subdued tone"
                }
            }
        } catch {
            // Fallback
        }
        
        return "neutral tone"
    }
}
