//
//  VoiceRecorder.swift
//  MoodMirror
//
//  AVAudioRecorder manager for recording voice clips
//

import AVFoundation
import SwiftUI

/// Errors that can occur during voice recording
enum VoiceRecordingError: Error, LocalizedError {
    case notAuthorized
    case recordingFailed(Error)
    case audioSessionFailed(Error)
    case noRecordingFound
    case invalidDuration
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone access is required. Please enable it in Settings."
        case .recordingFailed(let error):
            return "Failed to record audio: \(error.localizedDescription)"
        case .audioSessionFailed(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .noRecordingFound:
            return "No recording found."
        case .invalidDuration:
            return "Recording duration is invalid."
        }
    }
}

/// Voice recorder manager
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var error: VoiceRecordingError?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var levelTimer: Timer?
    
    private let maxDuration: TimeInterval = 10.0
    
    override init() {
        super.init()
    }
    
    /// Request microphone permission
    func requestPermission() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission
        
        switch status {
        case .granted:
            isAuthorized = true
            return true
            
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            isAuthorized = granted
            return granted
            
        case .denied:
            isAuthorized = false
            error = .notAuthorized
            return false
            
        @unknown default:
            isAuthorized = false
            return false
        }
    }
    
    /// Start recording
    func startRecording() throws {
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
        } catch {
            throw VoiceRecordingError.audioSessionFailed(error)
        }
        
        // Create temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".m4a"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        audioFileURL = fileURL
        
        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Start recording
            guard audioRecorder?.record() == true else {
                throw VoiceRecordingError.recordingFailed(NSError(domain: "VoiceRecorder", code: -1))
            }
            
            isRecording = true
            duration = 0
            
            // Start level monitoring
            startLevelMonitoring()
            
            // Auto-stop after max duration
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(maxDuration * 1_000_000_000))
                if isRecording {
                    stopRecording()
                }
            }
            
        } catch {
            throw VoiceRecordingError.recordingFailed(error)
        }
    }
    
    /// Stop recording
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        
        stopLevelMonitoring()
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    /// Get recorded audio URL
    func getRecordingURL() -> URL? {
        return audioFileURL
    }
    
    /// Get recorded audio data
    func getRecordingData() throws -> Data {
        guard let url = audioFileURL else {
            throw VoiceRecordingError.noRecordingFound
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            throw VoiceRecordingError.recordingFailed(error)
        }
    }
    
    /// Delete recording
    func deleteRecording() {
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioFileURL = nil
        duration = 0
        audioLevel = 0
    }
    
    /// Get recording duration
    func getRecordingDuration() -> TimeInterval {
        return audioRecorder?.currentTime ?? 0
    }
    
    // MARK: - Private Methods
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.audioRecorder?.updateMeters()
                
                // Get average power level
                let averagePower = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                
                // Convert to 0-1 range (dB range is typically -160 to 0)
                let normalizedLevel = pow(10, averagePower / 20)
                self.audioLevel = Float(normalizedLevel)
                
                // Update duration
                self.duration = self.audioRecorder?.currentTime ?? 0
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
            stopLevelMonitoring()
            
            if !flag {
                error = .recordingFailed(NSError(domain: "VoiceRecorder", code: -1))
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            isRecording = false
            stopLevelMonitoring()
            
            if let error = error {
                self.error = .recordingFailed(error)
            }
        }
    }
}
