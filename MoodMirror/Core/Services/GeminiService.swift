//
//  GeminiService.swift
//  MoodMirror
//
//  Service for interacting with Google Gemini API
//

import Foundation

/// Errors that can occur during Gemini API operations
enum GeminiError: Error, LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case rateLimitExceeded
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing Gemini API key"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .apiError(let message):
            return "Gemini API error: \(message)"
        }
    }
}

/// Response from Gemini emotion analysis
struct GeminiEmotionResponse: Codable {
    let emotions: [EmotionData]
    let primaryEmotion: String
    let insight: String
    
    struct EmotionData: Codable {
        let name: String
        let confidence: Double
    }
}

/// Protocol for Gemini API service
protocol GeminiServiceProtocol {
    func analyzeEmotion(faceDescription: String, voiceTone: String?, transcribedText: String?) async throws -> EmotionAnalysis
    func analyzeEmotionWithImage(image: Data, voiceTone: String?, transcribedText: String?) async throws -> EmotionAnalysis
    func generateInsights(from checkIns: [EmotionCheckIn]) async throws -> [String]
}

/// Gemini API service implementation
final class GeminiService: GeminiServiceProtocol {
    private let apiKey: String
    // Use gemini-3-flash-preview for multimodal (image + text) analysis
    private let visionModelURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"
    private let textModelURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"
    
    private struct GeminiAPIResponse: Codable {
        let candidates: [Candidate]
        
        struct Candidate: Codable {
            let content: Content
            
            struct Content: Codable {
                let parts: [Part]
                
                struct Part: Codable {
                    let text: String
                }
            }
        }
    }
    
    init(apiKey: String? = nil) throws {
        // Try to get API key from parameter, .env file, environment, or throw error
        if let key = apiKey {
            self.apiKey = key
        } else if let envKey = ConfigLoader.getValue(for: "GEMINI_API_KEY") {
            self.apiKey = envKey
        } else if let processEnvKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            self.apiKey = processEnvKey
        } else {
            throw GeminiError.invalidAPIKey
        }
    }
    
    /// Analyze emotion from face description, voice, and text (text-only fallback)
    func analyzeEmotion(faceDescription: String, voiceTone: String? = nil, transcribedText: String? = nil) async throws -> EmotionAnalysis {
        let prompt = buildEmotionPrompt(face: faceDescription, voice: voiceTone, text: transcribedText)
        
        let response: GeminiEmotionResponse = try await sendTextRequest(prompt: prompt)
        
        // Convert to EmotionAnalysis
        let scores = response.emotions.compactMap { emotionData -> EmotionScore? in
            guard let emotionType = EmotionType(rawValue: emotionData.name.lowercased()) else {
                return nil
            }
            return EmotionScore(emotion: emotionType, confidence: emotionData.confidence)
        }
        
        return EmotionAnalysis(
            emotionScores: scores,
            aiInsight: response.insight,
            voiceTranscript: transcribedText
        )
    }
    
    /// Analyze emotion from actual image data (multimodal)
    func analyzeEmotionWithImage(image: Data, voiceTone: String? = nil, transcribedText: String? = nil) async throws -> EmotionAnalysis {
        let response: GeminiEmotionResponse = try await sendImageRequest(
            imageData: image,
            voiceTone: voiceTone,
            transcribedText: transcribedText
        )
        
        // Convert to EmotionAnalysis
        let scores = response.emotions.compactMap { emotionData -> EmotionScore? in
            guard let emotionType = EmotionType(rawValue: emotionData.name.lowercased()) else {
                return nil
            }
            return EmotionScore(emotion: emotionType, confidence: emotionData.confidence)
        }
        
        return EmotionAnalysis(
            emotionScores: scores,
            aiInsight: response.insight,
            voiceTranscript: transcribedText
        )
    }
    
    /// Generate insights from check-in history
    func generateInsights(from checkIns: [EmotionCheckIn]) async throws -> [String] {
        let prompt = buildInsightsPrompt(from: checkIns)
        
        struct InsightsResponse: Codable {
            let insights: [String]
        }
        
        let response: InsightsResponse = try await sendTextRequest(prompt: prompt)
        return response.insights
    }
    
    // MARK: - Private Methods
    
    private func buildEmotionPrompt(face: String, voice: String?, text: String?) -> String {
        var prompt = """
        Analyze the emotional state based on:
        - Facial expression: \(face)
        """
        
        if let voice = voice {
            prompt += "\n- Voice tone: \(voice)"
        }
        
        if let text = text {
            prompt += "\n- Spoken words: \"\(text)\""
        }
        
        prompt += """
        
        
        Return ONLY valid JSON with emotions and confidence scores (0-1):
        {
          "emotions": [
            {"name": "happy", "confidence": 0.8},
            {"name": "anxious", "confidence": 0.3}
          ],
          "primaryEmotion": "happy",
          "insight": "Brief empathetic insight about emotional state (2-3 sentences)"
        }
        
        Use only these emotion names: happy, sad, angry, anxious, neutral, excited, fearful, disgusted, surprised, calm
        
        Be empathetic and supportive in the insight. Make it personal and helpful.
        """
        
        return prompt
    }
    
    private func buildInsightsPrompt(from checkIns: [EmotionCheckIn]) -> String {
        let checkInData = checkIns.prefix(30).map { checkIn in
            let date = checkIn.timestamp.formatted(date: .abbreviated, time: .shortened)
            return "- \(date): \(checkIn.primaryEmotion)"
        }.joined(separator: "\n")
        
        return """
        Analyze emotional patterns from recent check-ins:
        
        Data:
        \(checkInData)
        
        Identify:
        1. Most common emotions
        2. Time-of-day patterns
        3. Potential triggers or trends
        4. Positive improvements
        
        Return ONLY valid JSON with 3-5 actionable insights:
        {
          "insights": [
            "Your mood is most positive in the mornings",
            "You've shown improvement in managing anxiety this week",
            "Consider mindfulness exercises during stressful periods"
          ]
        }
        
        Keep insights supportive, actionable, and specific to the data.
        """
    }
    
    private func sendTextRequest<T: Codable>(prompt: String) async throws -> T {
        guard let url = URL(string: "\(textModelURL)?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 1024
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return try await executeRequest(request)
    }
    
    private func sendImageRequest(imageData: Data, voiceTone: String?, transcribedText: String?) async throws -> GeminiEmotionResponse {
        guard let url = URL(string: "\(visionModelURL)?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build prompt for image analysis
        var promptText = """
        Analyze the person's facial expression in this image to determine their emotional state.
        
        """
        
        if let voiceTone = voiceTone {
            promptText += "Additional context - Voice tone: \(voiceTone)\n"
        }
        
        if let transcribedText = transcribedText {
            promptText += "Additional context - They said: \"\(transcribedText)\"\n"
        }
        
        promptText += """
        
        Based on the facial expression (and any additional context), return ONLY valid JSON:
        {
          "emotions": [
            {"name": "happy", "confidence": 0.8},
            {"name": "calm", "confidence": 0.5}
          ],
          "primaryEmotion": "happy",
          "insight": "A brief empathetic insight about their emotional state (2-3 sentences)"
        }
        
        Use only these emotion names: happy, sad, angry, anxious, neutral, excited, fearful, disgusted, surprised, calm
        
        Be empathetic and supportive in the insight.
        """
        
        let base64Image = imageData.base64EncodedString()
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        ["text": promptText]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 1024
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return try await executeRequest(request)
    }
    
    private func executeRequest<T: Codable>(_ request: URLRequest) async throws -> T {
        do {
            print("🔵 Gemini API Request to: \(request.url?.absoluteString ?? "unknown")")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GeminiError.invalidResponse
            }
            
            print("🔵 Gemini API Status: \(httpResponse.statusCode)")
            
            // Debug: Print response for troubleshooting
            if httpResponse.statusCode != 200 {
                print("⚠️ Gemini API Error - Status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ Full Response: \(responseString)")
                }
            } else {
                print("✅ Gemini API Success - Response size: \(data.count) bytes")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔵 Response preview: \(responseString.prefix(300))")
                }
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    throw GeminiError.rateLimitExceeded
                }
                
                // Try to extract error message from response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw GeminiError.apiError(message)
                }
                
                throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
            
            guard let textResponse = geminiResponse.candidates.first?.content.parts.first?.text else {
                throw GeminiError.invalidResponse
            }
            
            let jsonString = extractJSON(from: textResponse)
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw GeminiError.invalidResponse
            }
            
            return try JSONDecoder().decode(T.self, from: jsonData)
            
        } catch let error as GeminiError {
            throw error
        } catch let error as DecodingError {
            print("⚠️ Decoding error: \(error)")
            throw GeminiError.decodingError(error)
        } catch {
            throw GeminiError.networkError(error)
        }
    }
    
    private func extractJSON(from text: String) -> String {
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedText.hasPrefix("```json") {
            cleanedText = cleanedText.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedText.hasPrefix("```") {
            cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Mock Service for Testing

/// Mock Gemini service for unit testing
final class MockGeminiService: GeminiServiceProtocol {
    var shouldFail = false
    var mockEmotionResponse: EmotionAnalysis?
    var mockInsights: [String] = []
    
    func analyzeEmotion(faceDescription: String, voiceTone: String?, transcribedText: String?) async throws -> EmotionAnalysis {
        if shouldFail {
            throw GeminiError.apiError("Mock error")
        }
        
        return mockEmotionResponse ?? EmotionAnalysis(
            emotionScores: [
                EmotionScore(emotion: .happy, confidence: 0.8),
                EmotionScore(emotion: .calm, confidence: 0.6)
            ],
            aiInsight: "Mock insight - text analysis",
            voiceTranscript: transcribedText
        )
    }
    
    func analyzeEmotionWithImage(image: Data, voiceTone: String?, transcribedText: String?) async throws -> EmotionAnalysis {
        if shouldFail {
            throw GeminiError.apiError("Mock error")
        }
        
        return mockEmotionResponse ?? EmotionAnalysis(
            emotionScores: [
                EmotionScore(emotion: .happy, confidence: 0.8),
                EmotionScore(emotion: .calm, confidence: 0.6)
            ],
            aiInsight: "Mock insight - image analysis",
            voiceTranscript: transcribedText
        )
    }
    
    func generateInsights(from checkIns: [EmotionCheckIn]) async throws -> [String] {
        if shouldFail {
            throw GeminiError.apiError("Mock error")
        }
        
        return mockInsights.isEmpty ? ["Mock insight 1", "Mock insight 2"] : mockInsights
    }
}
