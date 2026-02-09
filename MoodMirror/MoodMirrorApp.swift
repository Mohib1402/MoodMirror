//
//  MoodMirrorApp.swift
//  MoodMirror
//
//  AI-powered emotion tracking app
//

import SwiftUI

@main
struct MoodMirrorApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var appState = AppState()
    @StateObject private var onboardingManager = OnboardingManager()
    
    init() {
        // Load environment variables from .env file
        ConfigLoader.loadEnv()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .environmentObject(onboardingManager)
                .fullScreenCover(isPresented: Binding(
                    get: { !onboardingManager.hasCompletedOnboarding },
                    set: { _ in }
                )) {
                    OnboardingView()
                        .environmentObject(onboardingManager)
                }
                .alert("Error", isPresented: $appState.showError, presenting: appState.error) { _ in
                    Button("OK") {
                        appState.clearError()
                    }
                } message: { error in
                    Text(error.localizedDescription)
                }
        }
    }
}
