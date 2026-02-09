//
//  OnboardingView.swift
//  MoodMirror
//
//  Onboarding flow for first-time users
//

import SwiftUI

/// Onboarding page data
struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
}

/// Onboarding view
struct OnboardingView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to MoodMirror",
            description: "Track your emotions with AI-powered insights. Understand your mental health patterns and improve your wellbeing.",
            icon: "heart.fill",
            color: .pink
        ),
        OnboardingPage(
            title: "Express Through Face & Voice",
            description: "Capture your emotions through selfies and voice recordings. Our AI analyzes your expressions for deeper insights.",
            icon: "face.smiling",
            color: .blue
        ),
        OnboardingPage(
            title: "Visualize Your Journey",
            description: "See your emotional patterns over time with beautiful charts and AI-generated insights.",
            icon: "chart.line.uptrend.xyaxis",
            color: .green
        ),
        OnboardingPage(
            title: "Privacy First",
            description: "Your data stays on your device. We use Gemini AI for analysis, but your photos and recordings are never stored externally.",
            icon: "lock.shield.fill",
            color: .orange
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    completeOnboarding()
                }
                .padding()
                .opacity(currentPage < pages.count - 1 ? 1 : 0)
            }
            
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Bottom button
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .cornerRadius(12)
                    }
                } else {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    private func completeOnboarding() {
        onboardingManager.completeOnboarding()
        dismiss()
    }
}

/// Individual onboarding page
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 150, height: 150)
                
                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundColor(page.color)
            }
            
            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}
