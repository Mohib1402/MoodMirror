//
//  Theme.swift
//  MoodMirror
//
//  App-wide color scheme and styling
//

import SwiftUI

/// App theme colors and styles
enum Theme {
    // MARK: - Colors
    
    /// Primary brand color
    static let primary = Color("AccentColor")
    
    /// Background colors
    static let background = Color("Background")
    static let secondaryBackground = Color("SecondaryBackground")
    
    /// Text colors
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    /// Emotion colors
    static let emotionColors: [EmotionType: Color] = [
        .happy: .yellow,
        .sad: .blue,
        .angry: .red,
        .anxious: .orange,
        .neutral: .gray,
        .excited: .pink,
        .fearful: .purple,
        .disgusted: .green,
        .surprised: .cyan,
        .calm: .mint
    ]
    
    // MARK: - Gradients
    
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.4, green: 0.5, blue: 0.92), Color(red: 0.46, green: 0.29, blue: 0.64)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Spacing
    
    static let spacing = Spacing()
    
    struct Spacing {
        let xs: CGFloat = 4
        let sm: CGFloat = 8
        let md: CGFloat = 16
        let lg: CGFloat = 24
        let xl: CGFloat = 32
        let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    static let cornerRadius = CornerRadius()
    
    struct CornerRadius {
        let sm: CGFloat = 8
        let md: CGFloat = 12
        let lg: CGFloat = 16
        let xl: CGFloat = 24
    }
    
    // MARK: - Shadows
    
    static func cardShadow() -> some View {
        EmptyView()
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply card style
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(Theme.cornerRadius.lg)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    /// Apply primary button style
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.primary)
            .cornerRadius(Theme.cornerRadius.md)
    }
    
    /// Apply secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(Theme.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(Theme.cornerRadius.md)
    }
}

// MARK: - Color Assets (for Asset Catalog)

extension Color {
    /// Initialize color from asset catalog
    static let accentColor = Color("AccentColor")
    
    /// Custom background colors
    static let appBackground = Color("Background")
    static let cardBackground = Color("CardBackground")
}
