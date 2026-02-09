//
//  TimelineViewModel.swift
//  MoodMirror
//
//  ViewModel for displaying check-in timeline
//

import SwiftUI
import Combine

/// Filter options for timeline
enum TimelineFilter {
    case all
    case emotion(EmotionType)
    case dateRange(start: Date, end: Date)
}

/// Timeline view model
@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var checkIns: [EmotionCheckIn] = []
    @Published var groupedCheckIns: [Date: [EmotionCheckIn]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""
    @Published var selectedFilter: TimelineFilter = .all
    
    private let storageService: StorageServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
        
        // Observe search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.filterCheckIns()
            }
            .store(in: &cancellables)
        
        // Observe filter changes
        $selectedFilter
            .sink { [weak self] _ in
                self?.filterCheckIns()
            }
            .store(in: &cancellables)
    }
    
    /// Fetch all check-ins
    func fetchCheckIns() async {
        isLoading = true
        error = nil
        
        do {
            let allCheckIns = try await storageService.fetchAll()
            checkIns = allCheckIns
            groupCheckInsByDate()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// Fetch check-ins in date range
    func fetchCheckIns(from startDate: Date, to endDate: Date) async {
        isLoading = true
        error = nil
        
        do {
            let rangeCheckIns = try await storageService.fetch(from: startDate, to: endDate)
            checkIns = rangeCheckIns
            groupCheckInsByDate()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    /// Delete a check-in
    func deleteCheckIn(_ checkIn: EmotionCheckIn) async {
        do {
            try await storageService.delete(checkIn: checkIn)
            checkIns.removeAll { $0.id == checkIn.id }
            groupCheckInsByDate()
        } catch {
            self.error = error
        }
    }
    
    /// Refresh data
    func refresh() async {
        await fetchCheckIns()
    }
    
    // MARK: - Private Methods
    
    /// Group check-ins by date
    private func groupCheckInsByDate() {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: checkIns) { checkIn in
            calendar.startOfDay(for: checkIn.timestamp)
        }
        
        groupedCheckIns = grouped
    }
    
    /// Filter check-ins based on search and filter
    private func filterCheckIns() {
        // Start with all check-ins from storage
        var filtered = checkIns
        
        // Apply emotion filter
        switch selectedFilter {
        case .all:
            break
        case .emotion(let emotionType):
            filtered = filtered.filter { $0.primaryEmotion == emotionType.rawValue }
        case .dateRange(let start, let end):
            filtered = filtered.filter { checkIn in
                checkIn.timestamp >= start && checkIn.timestamp <= end
            }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            filtered = filtered.filter { checkIn in
                checkIn.primaryEmotion.lowercased().contains(searchText.lowercased()) ||
                (checkIn.notes?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        // Update grouped check-ins with filtered results
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { checkIn in
            calendar.startOfDay(for: checkIn.timestamp)
        }
        groupedCheckIns = grouped
    }
    
    /// Get sorted dates for grouped check-ins
    func sortedDates() -> [Date] {
        return groupedCheckIns.keys.sorted(by: >)
    }
    
    /// Get check-ins for a specific date
    func checkIns(for date: Date) -> [EmotionCheckIn] {
        return groupedCheckIns[date]?.sorted { $0.timestamp > $1.timestamp } ?? []
    }
}
