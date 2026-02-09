//
//  AppState.swift
//  MoodMirror
//
//  Global app state management
//

import Foundation
import SwiftUI

/// Global application state
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    /// Current selected tab
    @Published var selectedTab: Tab = .checkIn
    
    /// Network connectivity status (observed from networkMonitor)
    var isOnline: Bool { networkMonitor.isConnected }
    
    /// Loading state for app-level operations
    @Published var isLoading: Bool = false
    
    /// Global error to display
    @Published var error: Error?
    
    /// Show error alert
    @Published var showError: Bool = false
    
    // MARK: - Services
    
    let storageService: StorageServiceProtocol
    let geminiService: GeminiServiceProtocol
    let networkMonitor = NetworkMonitor()
    
    // MARK: - Initialization
    
    init(
        storageService: StorageServiceProtocol = StorageService(),
        geminiService: GeminiServiceProtocol? = nil
    ) {
        self.storageService = storageService
        
        // Initialize Gemini service with API key from environment
        if let geminiService = geminiService {
            self.geminiService = geminiService
        } else {
            do {
                self.geminiService = try GeminiService()
            } catch {
                // Fallback to mock service if API key not available
                print("⚠️ Gemini API key not found, using mock service")
                self.geminiService = MockGeminiService()
            }
        }
        
        // Observe network status changes via networkMonitor's published property
        // The NetworkMonitor already publishes isConnected, so we just observe it
    }
    
    // MARK: - Methods
    
    /// Handle error and show alert
    func handleError(_ error: Error) {
        self.error = error
        self.showError = true
    }
    
    /// Clear error
    func clearError() {
        self.error = nil
        self.showError = false
    }
}

// MARK: - Tab Enum

extension AppState {
    enum Tab: Int, CaseIterable {
        case checkIn
        case timeline
        case insights
        case settings
        
        var title: String {
            switch self {
            case .checkIn: return "Check-In"
            case .timeline: return "Timeline"
            case .insights: return "Insights"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .checkIn: return "camera.fill"
            case .timeline: return "list.bullet"
            case .insights: return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape.fill"
            }
        }
    }
}
