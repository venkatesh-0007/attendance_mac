import SwiftUI

public struct CircularProgressGauge: View {
    public let percentage: Double
    public let threshold: Double
    public let size: CGFloat
    public let strokeWidth: CGFloat
    
    public init(
        percentage: Double,
        threshold: Double = 75.0,
        size: CGFloat = 130,
        strokeWidth: CGFloat = 12
    ) {
        self.percentage = percentage
        self.threshold = threshold
        self.size = size
        self.strokeWidth = strokeWidth
    }
    
    private var progress: Double {
        min(max(percentage / 100.0, 0.0), 1.0)
    }
    
    private var isSafe: Bool {
        percentage >= threshold
    }
    
    private var primaryColor: Color {
        isSafe ? Color(red: 0.1, green: 0.78, blue: 0.45) : Color(red: 0.95, green: 0.3, blue: 0.3)
    }
    
    private var gradientColors: [Color] {
        if isSafe {
            return [Color(red: 0.2, green: 0.85, blue: 0.55), Color(red: 0.05, green: 0.65, blue: 0.35)]
        } else {
            return [Color(red: 1.0, green: 0.4, blue: 0.4), Color(red: 0.85, green: 0.2, blue: 0.2)]
        }
    }
    
    public var body: some View {
        let radius = (size - strokeWidth) / 2
        let targetAngle = (threshold / 100.0) * 360.0 - 90.0
        let targetX = size / 2 + radius * cos(targetAngle * .pi / 180)
        let targetY = size / 2 + radius * sin(targetAngle * .pi / 180)
        
        ZStack {
            // Subtle ambient backdrop disc
            Circle()
                .fill(primaryColor.opacity(0.04))
                .frame(width: size - strokeWidth * 2, height: size - strokeWidth * 2)
            
            // Background track
            Circle()
                .stroke(
                    Color.primary.opacity(0.08),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
            
            // Progress arc with glowing shadow
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: primaryColor.opacity(0.35), radius: 6, x: 0, y: 2)
                .animation(.spring(response: 0.7, dampingFraction: 0.75), value: percentage)
            
            // Target Threshold Pin
            Circle()
                .fill(Color.orange)
                .frame(width: strokeWidth * 0.7, height: strokeWidth * 0.7)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2)
                .position(x: targetX, y: targetY)
                .help("Attendance Goal: \(Int(threshold))%")
            
            // Center Typography
            VStack(spacing: 2) {
                Text(String(format: "%.1f%%", percentage))
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(isSafe ? "SAFE" : "AT RISK")
                    .font(.system(size: max(size * 0.08, 9), weight: .bold, design: .rounded))
                    .foregroundColor(primaryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(primaryColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(width: size, height: size)
    }
}
