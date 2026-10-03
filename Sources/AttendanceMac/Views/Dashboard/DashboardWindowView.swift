import SwiftUI

public struct DashboardWindowView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    public init(viewModel: AttendanceViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Group {
            if !viewModel.isLoggedIn {
                LoginView(viewModel: viewModel)
            } else {
                NavigationSplitView {
                    sidebar
                        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
                } detail: {
                    detailView
                }
                .navigationSplitViewStyle(.balanced)
                .toolbar {
                    toolbarContent
                }
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .preferredColorScheme(colorScheme)
    }
    
    private var colorScheme: ColorScheme? {
        switch viewModel.themePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Student Profile Header Card
            if let account = viewModel.currentAccount {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AttendanceColors.blueGradient)
                                .frame(width: 36, height: 36)
                                .shadow(color: AttendanceColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            Text(String(account.displayName.prefix(1)).uppercased())
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            
                            Text(account.studentId)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if let attendance = viewModel.attendance {
                        HStack {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(viewModel.overallStatus.color)
                                    .frame(width: 7, height: 7)
                                
                                Text(String(format: "%.1f%% Overall", attendance.overallPercentage))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(viewModel.overallStatus.color)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.overallStatus.color.opacity(0.12))
                            .clipShape(Capsule())
                            
                            Spacer()
                            
                            Text("\(attendance.attendedCount)/\(attendance.heldCount)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
            
            // Navigation Links
            List(DashboardTab.allCases, id: \.self, selection: $viewModel.activeTab) { tab in
                NavigationLink(value: tab) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(tabColor(tab).opacity(0.15))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(tabColor(tab))
                        }
                        
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                        
                        Spacer()
                        
                        if tab == .subjects, let count = viewModel.attendance?.subjectwiseSummary?.count {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        } else if tab == .timetable, !viewModel.todayClasses.isEmpty {
                            Text("\(viewModel.todayClasses.count)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
                .opacity(0.6)
            
            // Sidebar Footer
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                
                Text(viewModel.lastUpdated.map { "Updated \(formatDate($0))" } ?? "Sync Ready")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                        .animation(viewModel.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                }
                .buttonStyle(.plain)
                .help("Refresh attendance data")
                .disabled(viewModel.isRefreshing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .navigationTitle("Attendance")
    }
    
    private func tabColor(_ tab: DashboardTab) -> Color {
        switch tab {
        case .overview: return AttendanceColors.accent
        case .subjects: return AttendanceColors.purple
        case .timetable: return AttendanceColors.warning
        case .grid: return AttendanceColors.cyan
        case .simulator: return AttendanceColors.safe
        case .settings: return Color.secondary
        }
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private var detailView: some View {
        switch viewModel.activeTab {
        case .overview:
            OverviewTabView(viewModel: viewModel)
        case .subjects:
            SubjectsTabView(viewModel: viewModel)
        case .timetable:
            TimetableTabView(viewModel: viewModel)
        case .grid:
            AttendanceGridTabView(viewModel: viewModel)
        case .simulator:
            BunkSimulatorTabView(viewModel: viewModel)
        case .settings:
            SettingsTabView(viewModel: viewModel)
        }
    }
    
    // MARK: - Toolbar Content
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .status) {
            if viewModel.savedAccounts.count > 1 {
                Menu {
                    ForEach(viewModel.savedAccounts) { acc in
                        Button {
                            Task { await viewModel.switchAccount(to: acc.studentId) }
                        } label: {
                            HStack {
                                Text(acc.displayName)
                                if acc.studentId == viewModel.currentAccount?.studentId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(viewModel.currentAccount?.displayName ?? "Accounts")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .menuStyle(.borderlessButton)
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                        .animation(viewModel.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                    Text("Refresh")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .help("Refresh attendance data (⌘R)")
            .disabled(viewModel.isRefreshing)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
