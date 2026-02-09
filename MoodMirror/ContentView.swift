//
//  ContentView.swift
//  MoodMirror
//
//  Main navigation view
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            CheckInView()
                .tabItem {
                    Label(AppState.Tab.checkIn.title, systemImage: AppState.Tab.checkIn.icon)
                }
                .tag(AppState.Tab.checkIn)
            
            TimelineView()
                .tabItem {
                    Label(AppState.Tab.timeline.title, systemImage: AppState.Tab.timeline.icon)
                }
                .tag(AppState.Tab.timeline)
            
            InsightsView()
                .tabItem {
                    Label(AppState.Tab.insights.title, systemImage: AppState.Tab.insights.icon)
                }
                .tag(AppState.Tab.insights)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppState.Tab.settings)
        }
        .tint(Theme.primary)
        .onChange(of: appState.selectedTab) { _, _ in
            HapticManager.shared.selectionChanged()
        }
    }
}

// MARK: - Placeholder Views

struct CheckInView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCheckIn = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.primaryGradient
                    .ignoresSafeArea()
                
                VStack(spacing: Theme.spacing.lg) {
                    Spacer()
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                    
                    Text("Check-In")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Take a selfie and record your voice to analyze your emotional state")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, Theme.spacing.xl)
                    
                    Spacer()
                    
                    Button("Start Check-In") {
                        showingCheckIn = true
                    }
                    .primaryButtonStyle()
                    .padding(.horizontal, Theme.spacing.xl)
                    .padding(.bottom, Theme.spacing.xl)
                }
            }
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingCheckIn) {
                CheckInFlowView(
                    geminiService: appState.geminiService,
                    storageService: appState.storageService
                )
            }
        }
    }
}

struct TimelineView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TimelineListView(storageService: appState.storageService)
    }
}

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        InsightsListView(
            storageService: appState.storageService,
            geminiService: appState.geminiService
        )
    }
}

#Preview {
    ContentView()
}
