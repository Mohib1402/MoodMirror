//
//  StorageService.swift
//  MoodMirror
//
//  Service for managing emotion check-in storage
//

import Foundation
import CoreData

/// Errors that can occur during storage operations
enum StorageError: Error, LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save check-in: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch check-ins: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete check-in: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

/// Protocol for storage operations
protocol StorageServiceProtocol {
    func save(analysis: EmotionAnalysis, notes: String?) async throws -> EmotionCheckIn
    func fetchAll() async throws -> [EmotionCheckIn]
    func fetch(from startDate: Date, to endDate: Date) async throws -> [EmotionCheckIn]
    func delete(checkIn: EmotionCheckIn) async throws
    func deleteAll() async throws
}

/// Core Data storage service
final class StorageService: StorageServiceProtocol {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    /// Save emotion analysis as a check-in
    func save(analysis: EmotionAnalysis, notes: String? = nil) async throws -> EmotionCheckIn {
        let context = persistenceController.container.viewContext
        
        do {
            let checkIn = try EmotionCheckIn.create(from: analysis, notes: notes, context: context)
            
            try context.save()
            return checkIn
        } catch {
            throw StorageError.saveFailed(error)
        }
    }
    
    /// Fetch all check-ins, sorted by timestamp (newest first)
    func fetchAll() async throws -> [EmotionCheckIn] {
        let context = persistenceController.container.viewContext
        let request = EmotionCheckIn.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            throw StorageError.fetchFailed(error)
        }
    }
    
    /// Fetch check-ins within a date range
    func fetch(from startDate: Date, to endDate: Date) async throws -> [EmotionCheckIn] {
        let context = persistenceController.container.viewContext
        let request = EmotionCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            throw StorageError.fetchFailed(error)
        }
    }
    
    /// Delete a specific check-in
    func delete(checkIn: EmotionCheckIn) async throws {
        let context = persistenceController.container.viewContext
        
        do {
            context.delete(checkIn)
            try context.save()
        } catch {
            throw StorageError.deleteFailed(error)
        }
    }
    
    /// Delete all check-ins (use with caution)
    func deleteAll() async throws {
        let context = persistenceController.container.viewContext
        let request = EmotionCheckIn.fetchRequest()
        
        do {
            let checkIns = try context.fetch(request)
            checkIns.forEach { context.delete($0) }
            try context.save()
        } catch {
            throw StorageError.deleteFailed(error)
        }
    }
}
