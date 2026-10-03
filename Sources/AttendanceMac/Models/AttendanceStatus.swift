import SwiftUI

/// Represents the status of a single period or class
public enum AttendanceStatus: String, Codable, CaseIterable, Identifiable {
    case present = "PRESENT"
    case absent = "ABSENT"
    case holiday = "HOLIDAY"
    case leave = "LEAVE"
    case upcoming = "UPCOMING"
    
    public var id: String { rawValue }
    
    public var code: String {
        switch self {
        case .present: return "P"
        case .absent: return "A"
        case .holiday: return "H"
        case .leave: return "L"
        case .upcoming: return "-"
        }
    }
    
    public var title: String {
        switch self {
        case .present: return "Present"
        case .absent: return "Absent"
        case .holiday: return "Holiday"
        case .leave: return "Leave"
        case .upcoming: return "Upcoming"
        }
    }
    
    public var iconName: String {
        switch self {
        case .present: return "checkmark.circle.fill"
        case .absent: return "xmark.circle.fill"
        case .holiday: return "sparkles"
        case .leave: return "airplane"
        case .upcoming: return "clock.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .present: return Color(red: 0.1, green: 0.75, blue: 0.45) // emerald green
        case .absent: return Color(red: 0.95, green: 0.3, blue: 0.3) // bright red
        case .holiday: return Color(red: 0.2, green: 0.6, blue: 0.95) // electric blue
        case .leave: return Color(red: 0.75, green: 0.35, blue: 0.95) // purple
        case .upcoming: return Color.secondary.opacity(0.7)
        }
    }
    
    public var backgroundColor: Color {
        switch self {
        case .present: return Color(red: 0.08, green: 0.35, blue: 0.2).opacity(0.3)
        case .absent: return Color(red: 0.45, green: 0.12, blue: 0.12).opacity(0.3)
        case .holiday: return Color(red: 0.12, green: 0.25, blue: 0.45).opacity(0.3)
        case .leave: return Color(red: 0.35, green: 0.15, blue: 0.45).opacity(0.3)
        case .upcoming: return Color.secondary.opacity(0.12)
        }
    }
    
    public static func from(character: Character) -> AttendanceStatus {
        switch character.uppercased() {
        case "P": return .present
        case "A": return .absent
        case "H": return .holiday
        case "L": return .leave
        default: return .upcoming
        }
    }
    
    public static func from(string: String) -> AttendanceStatus {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let first = trimmed.first {
            return from(character: first)
        }
        return .upcoming
    }
}

/// Represents the overall status relative to target threshold
public enum OverallAttendanceStatus: String, Codable {
    case safe = "SAFE"
    case warning = "WARNING"
    case critical = "CRITICAL"
    
    public var title: String {
        switch self {
        case .safe: return "Safe Standing"
        case .warning: return "At Risk"
        case .critical: return "Critical Alert"
        }
    }
    
    public var iconName: String {
        switch self {
        case .safe: return "shield.checkmark.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .safe: return Color(red: 0.1, green: 0.75, blue: 0.45)
        case .warning: return Color(red: 0.95, green: 0.65, blue: 0.15)
        case .critical: return Color(red: 0.95, green: 0.25, blue: 0.25)
        }
    }
    
    public var lightBackgroundColor: Color {
        switch self {
        case .safe: return Color.green.opacity(0.12)
        case .warning: return Color.orange.opacity(0.12)
        case .critical: return Color.red.opacity(0.12)
        }
    }
}
