//
//  CheckInFlowView.swift
//  MoodMirror
//
//  Complete check-in flow orchestration
//

import SwiftUI

/// Main check-in flow view
struct CheckInFlowView: View {
    @StateObject private var viewModel: CheckInViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    
    init(geminiService: GeminiServiceProtocol, storageService: StorageServiceProtocol) {
        _viewModel = StateObject(wrappedValue: CheckInViewModel(
            geminiService: geminiService,
            storageService: storageService
        ))
    }
    
    var body: some View {
        ZStack {
            switch viewModel.currentStep {
            case .camera:
                CameraView(
                    onCapture: { image in
                        viewModel.didCapturePhoto(image)
                    },
                    onCancel: {
                        dismiss()
                    }
                )
                
            case .voice:
                VoiceRecorderView(
                    onRecordingComplete: { url in
                        viewModel.didCompleteVoiceRecording(url)
                    },
                    onCancel: {
                        dismiss()
                    }
                )
                .overlay(alignment: .topLeading) {
                    Button("Skip") {
                        viewModel.skipVoiceRecording()
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding()
                }
                
            case .notes:
                NotesView(
                    notes: $viewModel.userNotes,
                    onContinue: {
                        Task {
                            await viewModel.completeCheckIn()
                        }
                    },
                    onBack: {
                        viewModel.goBack()
                    }
                )
                
            case .analyzing:
                AnalyzingView()
                
            case .results:
                if let analysis = viewModel.analysisResult {
                    ResultsView(
                        analysis: analysis,
                        onComplete: {
                            dismiss()
                        },
                        onRetry: {
                            viewModel.reset()
                        }
                    )
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred")
        }
        .onReceive(viewModel.$error) { error in
            showingError = error != nil
        }
    }
}

/// Notes input view
struct NotesView: View {
    @Binding var notes: String
    let onContinue: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Add Notes (Optional)")
                    .font(.headline)
                
                Spacer()
                
                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .opacity(0)
            }
            .padding()
            
            // Notes input
            VStack(alignment: .leading, spacing: 12) {
                Text("How are you feeling?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add any additional context or notes about your current mood")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $notes)
                    .frame(height: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding()
            
            Spacer()
            
            // Continue button
            Button {
                onContinue()
            } label: {
                Text("Analyze My Mood")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

/// Analyzing view with loading indicator
struct AnalyzingView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            VStack(spacing: 12) {
                Text("Analyzing Your Mood")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Our AI is processing your facial expressions and voice...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            ProgressView()
                .scaleEffect(1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Results view showing emotion analysis
struct ResultsView: View {
    let analysis: EmotionAnalysis
    let onComplete: () -> Void
    let onRetry: () -> Void
    @State private var showingResults = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Primary emotion
                VStack(spacing: 24) {
                    // Emotion icon with celebration animation
                    Text(analysis.primaryEmotion.emoji)
                        .font(.system(size: 80))
                        .scaleEffect(showingResults ? 1.0 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showingResults)
                        .foregroundColor(analysis.primaryEmotion.color)
                    
                    Text(analysis.primaryEmotion.rawValue.capitalized)
                        .font(.system(size: 36, weight: .bold))
                    
                    if let primaryScore = analysis.emotionScores.first(where: { $0.emotion == analysis.primaryEmotion }) {
                        Text("\(Int(primaryScore.confidence * 100))% confidence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // All emotions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detected Emotions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(analysis.emotionScores.sorted(by: { $0.confidence > $1.confidence }), id: \.emotion) { score in
                        HStack {
                            Text(score.emotion.rawValue.capitalized)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            ProgressView(value: score.confidence)
                                .frame(width: 100)
                            
                            Text("\(Int(score.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // AI Insight
                if let insight = analysis.aiInsight {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("AI Insight", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text(insight)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.success()
                        onComplete()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    Button {
                        onRetry()
                    } label: {
                        Text("New Check-In")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .padding(.vertical)
        }
        .background(Color(.systemBackground))
    }
}
