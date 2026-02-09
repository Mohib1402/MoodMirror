//
//  VoiceRecorderView.swift
//  MoodMirror
//
//  SwiftUI voice recorder view with waveform visualization
//

import SwiftUI

/// Voice recorder view with waveform and timer
struct VoiceRecorderView: View {
    @StateObject private var voiceRecorder = VoiceRecorder()
    
    let onRecordingComplete: (URL) -> Void
    let onCancel: () -> Void
    
    init(onRecordingComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void = {}) {
        self.onRecordingComplete = onRecordingComplete
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Top bar
                HStack {
                    Button {
                        if voiceRecorder.isRecording {
                            voiceRecorder.stopRecording()
                        }
                        voiceRecorder.deleteRecording()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Recording state
                VStack(spacing: 24) {
                    // Waveform visualization
                    WaveformView(audioLevel: voiceRecorder.audioLevel, isRecording: voiceRecorder.isRecording)
                        .frame(height: 100)
                        .padding(.horizontal)
                    
                    // Timer
                    Text(formatDuration(voiceRecorder.duration))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Max duration indicator
                    Text("Maximum 10 seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Instructions
                    if !voiceRecorder.isRecording {
                        if voiceRecorder.duration > 0 {
                            Text("Tap checkmark to continue or record button to retry")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else if let error = voiceRecorder.error {
                            VStack(spacing: 12) {
                                Text(error.localizedDescription)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                if case .notAuthorized = error {
                                    Button("Open Settings") {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        } else {
                            Text("Tap the microphone to start recording")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Recording... Speak naturally")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 48) {
                    // Delete/Retry button
                    if voiceRecorder.duration > 0 && !voiceRecorder.isRecording {
                        Button {
                            voiceRecorder.deleteRecording()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                                .foregroundColor(.orange)
                                .frame(width: 60, height: 60)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    
                    // Record/Stop button
                    Button {
                        if voiceRecorder.isRecording {
                            voiceRecorder.stopRecording()
                        } else {
                            Task {
                                let granted = await voiceRecorder.requestPermission()
                                if granted {
                                    do {
                                        try voiceRecorder.startRecording()
                                    } catch {
                                        voiceRecorder.error = error as? VoiceRecordingError
                                    }
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(voiceRecorder.isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: voiceRecorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        .shadow(radius: 8)
                    }
                    
                    // Complete button
                    if voiceRecorder.duration > 0 && !voiceRecorder.isRecording {
                        Button {
                            if let url = voiceRecorder.getRecordingURL() {
                                onRecordingComplete(url)
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 60, height: 60)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onDisappear {
            if voiceRecorder.isRecording {
                voiceRecorder.stopRecording()
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d.%02d", seconds, milliseconds)
    }
}

/// Waveform visualization
struct WaveformView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    private let barCount = 40
    
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard isRecording else {
            return 4
        }
        
        let normalizedIndex = abs(Float(index) - Float(barCount) / 2) / Float(barCount / 2)
        let levelMultiplier = 1.0 - normalizedIndex
        let height = CGFloat(audioLevel) * 80 * CGFloat(levelMultiplier)
        
        return max(4, height + CGFloat.random(in: 0...10))
    }
    
    private func barColor(for index: Int) -> Color {
        let centerIndex = barCount / 2
        let distance = abs(index - centerIndex)
        
        if distance < 5 {
            return .blue
        } else if distance < 10 {
            return .cyan
        } else {
            return .gray.opacity(0.5)
        }
    }
}

// MARK: - Preview

#Preview {
    VoiceRecorderView { url in
        print("Recording complete: \(url)")
    }
}
