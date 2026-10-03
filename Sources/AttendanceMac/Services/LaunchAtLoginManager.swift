import Foundation
import ServiceManagement

/// Manages Launch at Login registration using macOS 13+ SMAppService
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @Published public var isEnabled: Bool = false
    @Published public var statusMessage: String? = nil
    
    private init() {
        refreshStatus()
    }
    
    public func refreshStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            isEnabled = (status == .enabled)
            switch status {
            case .enabled:
                statusMessage = "Enabled (Launches automatically at macOS login)"
            case .requiresApproval:
                statusMessage = "Requires approval in macOS System Settings > General > Login Items"
            case .notFound:
                statusMessage = "Application not found in system service registry"
            default:
                statusMessage = "Disabled"
            }
        } else {
            isEnabled = false
            statusMessage = "Requires macOS 13.0 or later"
        }
    }
    
    public func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                refreshStatus()
            } catch {
                statusMessage = "Failed: \(error.localizedDescription)"
                refreshStatus()
            }
        }
    }
}
