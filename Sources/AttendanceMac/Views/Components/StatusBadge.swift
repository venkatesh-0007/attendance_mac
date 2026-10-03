import SwiftUI

public struct StatusBadge: View {
    public let title: String
    public let iconName: String?
    public let color: Color
    public let backgroundColor: Color?
    
    public init(
        title: String,
        iconName: String? = nil,
        color: Color,
        backgroundColor: Color? = nil
    ) {
        self.title = title
        self.iconName = iconName
        self.color = color
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            if let icon = iconName {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor ?? color.opacity(0.15))
        )
    }
}

public struct PeriodCircle: View {
    public let number: Int
    public let status: AttendanceStatus
    
    public init(number: Int, status: AttendanceStatus) {
        self.number = number
        self.status = status
    }
    
    public var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(status.backgroundColor)
                    .frame(width: 26, height: 26)
                
                Circle()
                    .strokeBorder(status.color, lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                
                Text(status.code)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(status.color)
            }
            
            Text("P\(number)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
