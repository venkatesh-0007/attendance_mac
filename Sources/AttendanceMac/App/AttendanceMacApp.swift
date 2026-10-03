import SwiftUI

@main
struct AttendanceMacApp: App {
    @StateObject private var viewModel = AttendanceViewModel.shared
    
    private var colorScheme: ColorScheme? {
        switch viewModel.themePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some Scene {
        // Native macOS Menu Bar Item & Window Popover
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel) {
                WindowManager.shared.openDashboard(viewModel: viewModel)
            }
            .preferredColorScheme(colorScheme)
        } label: {
            MenuBarLabelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("Attendance") {
                Button("Refresh Attendance") {
                    Task { await viewModel.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Open Dashboard") {
                    WindowManager.shared.openDashboard(viewModel: viewModel)
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Divider()
                
                Button("Preferences...") {
                    viewModel.activeTab = .settings
                    WindowManager.shared.openDashboard(viewModel: viewModel)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
