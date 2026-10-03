import Foundation
import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()
    
    private var center: UNUserNotificationCenter? {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty,
              (Bundle.main.bundleURL.pathExtension == "app" || Bundle.main.bundlePath.contains(".app")) else {
            return nil
        }
        return UNUserNotificationCenter.current()
    }
    private var lastNotifiedPercentage: Double?
    
    private init() {}
    
    public func requestAuthorization() {
        guard let center = center else {
            #if DEBUG
            print("[NotificationManager] Running outside an app bundle; user notifications disabled.")
            #endif
            return
        }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    public func postLowAttendanceNotification(percentage: Double, threshold: Double) {
        // Prevent spamming notification if percentage hasn't changed noticeably
        if let last = lastNotifiedPercentage, abs(last - percentage) < 0.05 {
            return
        }
        lastNotifiedPercentage = percentage
        
        guard let center = center else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Critical Attendance Alert!"
        content.body = String(format: "Your overall attendance is %.2f%%, which is below your target threshold of %.0f%%.", percentage, threshold)
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(
            identifier: "low_attendance_alert",
            content: content,
            trigger: nil // Immediate
        )
        
        center.add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
    
    public func postSyncNotification(status: String) {
        guard let center = center else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Attendance Synchronized"
        content.body = status
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "attendance_sync_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        center.add(request)
    }
}
