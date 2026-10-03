import SwiftUI
import AppKit

// MARK: - Modern Design System & Semantic Color Tokens

public enum AttendanceColors {
    // Primary Status Colors
    public static let safe = Color(red: 0.08, green: 0.78, blue: 0.44)       // Emerald Green
    public static let warning = Color(red: 0.98, green: 0.62, blue: 0.12)    // Warm Amber
    public static let critical = Color(red: 0.94, green: 0.28, blue: 0.28)   // Coral Red
    public static let accent = Color(red: 0.08, green: 0.48, blue: 0.98)     // System Blue
    public static let purple = Color(red: 0.62, green: 0.35, blue: 0.95)     // Royal Purple
    public static let cyan = Color(red: 0.06, green: 0.72, blue: 0.88)       // Sky Cyan
    
    // Status Gradients
    public static let safeGradient = LinearGradient(
        colors: [Color(red: 0.12, green: 0.82, blue: 0.48), Color(red: 0.04, green: 0.64, blue: 0.36)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let criticalGradient = LinearGradient(
        colors: [Color(red: 0.98, green: 0.36, blue: 0.36), Color(red: 0.86, green: 0.18, blue: 0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let blueGradient = LinearGradient(
        colors: [Color(red: 0.18, green: 0.58, blue: 1.0), Color(red: 0.06, green: 0.38, blue: 0.90)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let purpleGradient = LinearGradient(
        colors: [Color(red: 0.68, green: 0.42, blue: 0.98), Color(red: 0.48, green: 0.24, blue: 0.86)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let amberGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.72, blue: 0.20), Color(red: 0.90, green: 0.52, blue: 0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Reusable Card Styling Modifier

public struct AttendanceCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    public var borderColor: Color?
    public var borderWidth: CGFloat
    
    public init(
        cornerRadius: CGFloat = 14,
        padding: CGFloat = 16,
        borderColor: Color? = nil,
        borderWidth: CGFloat = 1
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor ?? Color.primary.opacity(0.06), lineWidth: borderWidth)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }
}

public extension View {
    func attendanceCard(
        cornerRadius: CGFloat = 14,
        padding: CGFloat = 16,
        borderColor: Color? = nil,
        borderWidth: CGFloat = 1
    ) -> some View {
        self.modifier(AttendanceCardModifier(
            cornerRadius: cornerRadius,
            padding: padding,
            borderColor: borderColor,
            borderWidth: borderWidth
        ))
    }
}
