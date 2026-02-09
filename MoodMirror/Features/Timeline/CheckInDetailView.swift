//
//  CheckInDetailView.swift
//  MoodMirror
//
//  Detailed view of a single check-in
//

import SwiftUI

/// Detailed check-in view
struct CheckInDetailView: View {
    let checkIn: EmotionCheckIn
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    private var emotionType: EmotionType? {
        EmotionType(rawValue: checkIn.primaryEmotion)
    }
    
    private var emotionScores: [EmotionScore] {
        guard let scoresData = checkIn.emotionScores,
              let decoded = try? JSONDecoder().decode([EmotionScore].self, from: scoresData) else {
            return []
        }
        return decoded.sorted { $0.confidence > $1.confidence }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header with primary emotion
                VStack(spacing: 16) {
                    if let emotion = emotionType {
                        Image(systemName: emotion.icon)
                            .font(.system(size: 80))
                            .foregroundColor(emotion.color)
                    } else {
                        // Fallback if emotion type doesn't parse
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    }
                    
                    Text(checkIn.primaryEmotion.isEmpty ? "Unknown" : checkIn.primaryEmotion.capitalized)
                        .font(.system(size: 36, weight: .bold))
                    
                    Text(checkIn.timestamp, style: .date)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(checkIn.timestamp, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                    
                    // Emotion scores
                    if !emotionScores.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Emotion Breakdown")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(emotionScores, id: \.emotion) { score in
                                HStack {
                                    Image(systemName: score.emotion.icon)
                                        .foregroundColor(score.emotion.color)
                                        .frame(width: 24)
                                    
                                    Text(score.emotion.rawValue.capitalized)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    ProgressView(value: score.confidence)
                                        .frame(width: 100)
                                        .tint(score.emotion.color)
                                    
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
                    }
                    
                    // Notes
                    if let notes = checkIn.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your Notes", systemImage: "note.text")
                                .font(.headline)
                            
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // AI Insight
                    if let insight = checkIn.aiInsight, !insight.isEmpty {
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
                    
                    // Voice transcript
                    if let transcript = checkIn.voiceTranscript, !transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Voice Transcript", systemImage: "waveform")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text(transcript)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Delete button
                    Button(role: .destructive) {
                        HapticManager.shared.warning()
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Check-In", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top)
            }
            .padding(.vertical)
        }
        .overlay(alignment: .topTrailing) {
            Button("Done") {
                dismiss()
            }
            .padding()
        }
        .alert("Delete Check-In", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this check-in? This action cannot be undone.")
        }
    }
}
