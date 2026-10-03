import SwiftUI
import AppKit

public final class WindowManager: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = WindowManager()
    private var dashboardWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func openDashboard(viewModel: AttendanceViewModel) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        if let existing = dashboardWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        let contentView = DashboardWindowView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Attendance Dashboard"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 800, height: 520)
        window.delegate = self
        
        self.dashboardWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    
    public func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
