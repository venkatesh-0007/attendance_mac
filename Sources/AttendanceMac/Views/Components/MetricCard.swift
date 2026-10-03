import SwiftUI

public struct MetricCard: View {
    public let title: String
    public let value: String
    public let subtitle: String?
    public let iconName: String?
    public let accentColor: Color?
    
    public init(
        title: String,
        value: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        accentColor: Color? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.iconName = iconName
        self.accentColor = accentColor
    }
    
    @State private var isHovered = false
    
    public var body: some View {
        let themeColor = accentColor ?? AttendanceColors.accent
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                if let icon = iconName {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(themeColor.opacity(0.12))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeColor)
                    }
                }
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(themeColor)
            
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovered ? 0.95 : 0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHovered ? themeColor.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
