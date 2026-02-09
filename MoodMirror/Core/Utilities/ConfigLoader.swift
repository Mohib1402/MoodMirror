//
//  ConfigLoader.swift
//  MoodMirror
//
//  Utility to load configuration from .env file
//

import Foundation

/// Loads configuration from .env file
enum ConfigLoader {
    // Store loaded values
    private static var loadedValues: [String: String] = [:]
    
    /// Load environment variables from .env file in project directory
    static func loadEnv() {
        // Try multiple locations for .env file
        let possiblePaths = [
            // In bundle as "env" resource (renamed for bundle compatibility)
            Bundle.main.path(forResource: "env", ofType: nil),
            // In bundle (if user added it)
            Bundle.main.path(forResource: ".env", ofType: nil),
            // In bundle Resources folder
            Bundle.main.resourcePath.map { $0 + "/.env" },
            Bundle.main.resourcePath.map { $0 + "/env" },
            // In project root (development)
            FileManager.default.currentDirectoryPath + "/.env",
            // Parent directory of bundle (common for Xcode builds)
            Bundle.main.bundlePath + "/../../.env",
            // Three levels up from bundle (another common location)
            Bundle.main.bundlePath + "/../../../.env"
        ]
        
        var envPath: String?
        for path in possiblePaths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                envPath = path
                break
            }
        }
        
        guard let envPath = envPath else {
            print("⚠️ .env file not found. Trying environment variables...")
            return
        }
        
        do {
            let envContent = try String(contentsOfFile: envPath, encoding: .utf8)
            let lines = envContent.components(separatedBy: .newlines)
            
            for line in lines {
                // Skip empty lines and comments
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }
                
                // Parse KEY=VALUE format
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                
                // Remove quotes if present
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                
                setenv(key, value, 1)
                loadedValues[key] = value
            }
            
            print("✅ Loaded environment variables from .env file at: \(envPath)")
        } catch {
            print("⚠️ Failed to load .env file: \(error)")
        }
    }
    
    /// Get value for environment variable key
    static func getValue(for key: String) -> String? {
        // Check our stored values first
        if let value = loadedValues[key] {
            return value
        }
        // Fall back to environment variables
        return ProcessInfo.processInfo.environment[key]
    }
    
    /// Manually set a value (useful for hardcoded fallbacks)
    static func setValue(_ value: String, for key: String) {
        loadedValues[key] = value
        setenv(key, value, 1)
    }
}
