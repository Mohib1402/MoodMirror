//
//  SettingsView.swift
//  MoodMirror
//
//  Settings and preferences view
//

import SwiftUI

/// Settings view
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var onboardingManager: OnboardingManager
    @StateObject private var notificationManager = NotificationManager()
    @State private var showingDeleteAlert = false
    @State private var showingExportSheet = false
    @State private var exportData: String?
    @State private var deleteError: Error?
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Notifications section
                Section {
                    Toggle("Daily Reminders", isOn: $notificationManager.isReminderEnabled)
                    
                    if notificationManager.isReminderEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $notificationManager.reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    
                    if !notificationManager.isAuthorized {
                        Button("Enable Notifications") {
                            notificationManager.openSettings()
                        }
                        .foregroundColor(.orange)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get daily reminders to check in with your emotions")
                }
                
                // Data management section
                Section {
                    Button("Export Data") {
                        exportCheckIns()
                    }
                    
                    Button("Delete All Data", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export your check-ins or permanently delete all data")
                }
                
                // About section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Show Onboarding Again") {
                        onboardingManager.resetOnboarding()
                    }
                } header: {
                    Text("About")
                }
                
                // Privacy section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Privacy")
                            .font(.headline)
                        Text("All your data stays on your device. We don't collect or share any personal information.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete All Data", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your check-ins. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    deleteError = nil
                }
            } message: {
                Text(deleteError?.localizedDescription ?? "An error occurred")
            }
            .sheet(isPresented: $showingExportSheet) {
                if let data = exportData {
                    ShareSheet(items: [data])
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func exportCheckIns() {
        Task {
            do {
                let checkIns = try await appState.storageService.fetchAll()
                let jsonData = try exportToJSON(checkIns: checkIns)
                await MainActor.run {
                    exportData = jsonData
                    showingExportSheet = true
                }
            } catch {
                await MainActor.run {
                    deleteError = error
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func exportToJSON(checkIns: [EmotionCheckIn]) throws -> String {
        let exportItems = checkIns.map { checkIn -> [String: Any] in
            return [
                "id": checkIn.id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: checkIn.timestamp),
                "primaryEmotion": checkIn.primaryEmotion,
                "notes": checkIn.notes ?? "",
                "aiInsight": checkIn.aiInsight ?? "",
                "voiceTranscript": checkIn.voiceTranscript ?? ""
            ]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportItems, options: .prettyPrinted)
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    private func deleteAllData() {
        Task {
            do {
                try await appState.storageService.deleteAll()
            } catch {
                deleteError = error
                showingErrorAlert = true
            }
        }
    }
}

/// Share sheet for exporting data
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
