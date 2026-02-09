//
//  TimelineListView.swift
//  MoodMirror
//
//  Timeline list view with check-ins grouped by date
//

import SwiftUI

/// Timeline list view
struct TimelineListView: View {
    @StateObject private var viewModel: TimelineViewModel
    @State private var selectedCheckIn: EmotionCheckIn?
    @State private var showingFilterSheet = false
    @State private var showingError = false
    
    init(storageService: StorageServiceProtocol) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(storageService: storageService))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading check-ins...")
                } else if viewModel.groupedCheckIns.isEmpty {
                    emptyState
                } else {
                    checkInsList
                }
            }
            .navigationTitle("Timeline")
            .searchable(text: $viewModel.searchText, prompt: "Search emotions or notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.fetchCheckIns()
            }
            .sheet(item: $selectedCheckIn) { checkIn in
                CheckInDetailView(checkIn: checkIn, onDelete: {
                    Task {
                        await viewModel.deleteCheckIn(checkIn)
                        selectedCheckIn = nil
                    }
                })
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterView(selectedFilter: $viewModel.selectedFilter)
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
    
    private var checkInsList: some View {
        List {
            ForEach(viewModel.sortedDates(), id: \.self) { date in
                Section {
                    ForEach(viewModel.checkIns(for: date), id: \.id) { checkIn in
                        CheckInRow(checkIn: checkIn)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCheckIn = checkIn
                            }
                    }
                } header: {
                    Text(date, style: .date)
                        .font(.headline)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)
            
            Text("No Check-Ins Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your emotional journey will appear here after your first check-in")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

/// Check-in row view
struct CheckInRow: View {
    let checkIn: EmotionCheckIn
    
    private var emotionType: EmotionType? {
        EmotionType(rawValue: checkIn.primaryEmotion)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Emotion icon
            if let emotion = emotionType {
                Image(systemName: emotion.icon)
                    .font(.title2)
                    .foregroundColor(emotion.color)
                    .frame(width: 44, height: 44)
                    .background(emotion.color.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(checkIn.primaryEmotion.capitalized)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(checkIn.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let notes = checkIn.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let insight = checkIn.aiInsight, !insight.isEmpty {
                    Text(insight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Filter view
struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFilter: TimelineFilter
    @State private var tempFilter: TimelineFilter
    
    init(selectedFilter: Binding<TimelineFilter>) {
        _selectedFilter = selectedFilter
        _tempFilter = State(initialValue: selectedFilter.wrappedValue)
    }
    
    private func isSelected(_ filter: TimelineFilter) -> Bool {
        switch (tempFilter, filter) {
        case (.all, .all):
            return true
        case (.emotion(let e1), .emotion(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Filter by Emotion") {
                    Button {
                        tempFilter = .all
                    } label: {
                        HStack {
                            Text("All Emotions")
                                .foregroundColor(.accentColor)
                            Spacer()
                            if case .all = tempFilter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    ForEach(EmotionType.allCases, id: \.self) { emotion in
                        Button {
                            tempFilter = .emotion(emotion)
                        } label: {
                            HStack {
                                Image(systemName: emotion.icon)
                                    .foregroundColor(emotion.color)
                                Text(emotion.rawValue.capitalized)
                                    .foregroundColor(.primary)
                                Spacer()
                                if case .emotion(let selected) = tempFilter, selected == emotion {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        selectedFilter = tempFilter
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}
