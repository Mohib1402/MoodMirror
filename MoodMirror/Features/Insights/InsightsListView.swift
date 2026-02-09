//
//  InsightsListView.swift
//  MoodMirror
//
//  AI-generated insights view
//

import SwiftUI

/// Insights list view
struct InsightsListView: View {
    @StateObject private var viewModel: InsightsViewModel
    @State private var showingCharts = false
    @State private var showingError = false
    
    init(storageService: StorageServiceProtocol, geminiService: GeminiServiceProtocol) {
        _viewModel = StateObject(wrappedValue: InsightsViewModel(
            storageService: storageService,
            geminiService: geminiService
        ))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Generating insights...")
                } else if viewModel.insights.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    insightsList
                }
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCharts = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .task {
                await viewModel.generateInsights()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingCharts) {
                NavigationStack {
                    ChartsContainerView(
                        storageService: viewModel.storageService
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingCharts = false
                            }
                            .foregroundColor(.accentColor)
                        }
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
    
    // MARK: - Subviews
    
    private var insightsList: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stats cards
                statsCards
                
                // AI Insights
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI Insights")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    ForEach(Array(viewModel.insights.enumerated()), id: \.offset) { index, insight in
                        InsightCard(insight: insight, index: index)
                    }
                }
                .padding(.top)
                
                // Health Correlations
                if !viewModel.healthCorrelations.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Health & Mood Patterns")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ForEach(Array(viewModel.healthCorrelations.enumerated()), id: \.offset) { index, correlation in
                            HealthCorrelationCard(correlation: correlation)
                        }
                    }
                    .padding(.top)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var statsCards: some View {
        VStack(spacing: 16) {
            if let emotion = viewModel.mostCommonEmotion {
                StatsCard(
                    title: "Most Common Emotion",
                    value: emotion.rawValue.capitalized,
                    icon: emotion.icon,
                    color: emotion.color
                )
            }
            
            if let streak = viewModel.emotionStreak, streak.days > 1 {
                StatsCard(
                    title: "Longest Streak",
                    value: "\(streak.days) days of \(streak.emotion.rawValue)",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "lightbulb")
                .font(.system(size: 60))
                .foregroundColor(Theme.primary)
            
            Text("No Insights Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete more check-ins to receive personalized AI insights about your emotional patterns")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Generate Insights") {
                Task {
                    await viewModel.generateInsights()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// Insight card view
struct InsightCard: View {
    let insight: String
    let index: Int
    
    private var cardColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink]
        return colors[index % colors.count]
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundColor(cardColor)
            
            Text(insight)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(cardColor.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// Health correlation card
struct HealthCorrelationCard: View {
    let correlation: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundColor(.red)
            
            Text(correlation)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// Stats card view
struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

/// Charts container view
struct ChartsContainerView: View {
    let storageService: StorageServiceProtocol
    @State private var checkIns: [EmotionCheckIn] = []
    
    var body: some View {
        Group {
            if checkIns.isEmpty {
                ProgressView()
            } else {
                EmotionChartsView(checkIns: checkIns)
            }
        }
        .task {
            do {
                checkIns = try await storageService.fetchAll()
            } catch {
                print("Failed to fetch check-ins: \(error)")
            }
        }
    }
}
