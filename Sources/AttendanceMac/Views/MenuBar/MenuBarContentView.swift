import SwiftUI

public struct MenuBarContentView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    public var onOpenDashboard: () -> Void
    
    public init(viewModel: AttendanceViewModel, onOpenDashboard: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onOpenDashboard = onOpenDashboard
    }
    
    private var cleanRollNumber: String? {
        guard let roll = viewModel.attendance?.rollNumber else { return nil }
        let cleaned = roll.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r")).uppercased()
        return cleaned.isEmpty ? nil : cleaned
    }
    
    public var body: some View {
        Group {
            if !viewModel.isLoggedIn {
                MenuBarLoginView(viewModel: viewModel, onOpenDashboard: onOpenDashboard)
                    .frame(width: 290)
                    .fixedSize(horizontal: true, vertical: true)
            } else if let attendance = viewModel.attendance {
                VStack(alignment: .leading, spacing: 8) {
                    // Header Bar (Name, Clean Roll & Glass Refresh)
                    headerBar(attendance)
                    
                    // 1. PRESENT ATTENDANCE (Liquid Glass Tile)
                    presentAttendanceGlassCard(attendance)
                    
                    // 2. SAFE TO SKIP PERIODS (Liquid Glass Tile)
                    safeToSkipGlassCard(attendance)
                    
                    // 3. TODAY'S ATTENDANCE FROM ATTENDANCE GRID (Liquid Glass Tile)
                    todayAttendanceGridGlassCard(attendance)
                    
                    // Action Footer: Liquid Glass Open Dashboard & Custom Glass Menu Button
                    footerActionBar()
                }
                .padding(11)
                .frame(width: 300)
                .fixedSize(horizontal: true, vertical: true)
            } else if viewModel.isLoading {
                VStack(spacing: 10) {
                    ProgressView().scaleEffect(0.8)
                    Text("Updating attendance...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(22)
                .frame(width: 280)
                .fixedSize(horizontal: true, vertical: true)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AttendanceColors.critical)
                    Text(viewModel.errorMessage ?? "No records available")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(20)
                .frame(width: 280)
                .fixedSize(horizontal: true, vertical: true)
            }
        }
        .background(
            ZStack {
                MacVisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color.black.opacity(0.08)
            }
        )
    }
    
    // MARK: - Header Bar
    
    @ViewBuilder
    private func headerBar(_ attendance: AttendanceResponse) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Text(viewModel.currentAccount?.displayName ?? attendance.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let roll = cleanRollNumber {
                    Text(roll)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
            }
            
            Spacer()
            
            Button {
                Task { await viewModel.refresh() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                        .animation(viewModel.isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                }
                .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Refresh attendance data")
            .disabled(viewModel.isRefreshing)
        }
        .padding(.horizontal, 2)
        .padding(.top, 1)
    }
    
    // MARK: - 1. PRESENT ATTENDANCE (Liquid Glass Tile)
    
    @ViewBuilder
    private func presentAttendanceGlassCard(_ attendance: AttendanceResponse) -> some View {
        let pct = attendance.overallPercentage
        let isSafe = pct >= viewModel.targetThreshold
        
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                // Large Glowing Percentage
                Text(String(format: "%.1f%%", pct))
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundColor(isSafe ? AttendanceColors.safe : AttendanceColors.critical)
                    .shadow(color: (isSafe ? AttendanceColors.safe : AttendanceColors.critical).opacity(0.35), radius: 6, x: 0, y: 1)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    // Status Pill with Glowing Dot
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isSafe ? AttendanceColors.safe : AttendanceColors.critical)
                            .frame(width: 6, height: 6)
                            .shadow(color: (isSafe ? AttendanceColors.safe : AttendanceColors.critical).opacity(0.6), radius: 2)
                        
                        Text(isSafe ? "Safe Standing" : "At Risk")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isSafe ? AttendanceColors.safe : AttendanceColors.critical)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((isSafe ? AttendanceColors.safe : AttendanceColors.critical).opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke((isSafe ? AttendanceColors.safe : AttendanceColors.critical).opacity(0.3), lineWidth: 0.5)
                    )
                    
                    Text("\(attendance.attendedCount)/\(attendance.heldCount) Classes Held")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            // Liquid Progress Track with Target Goal Marker
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Frosted track
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                        .frame(height: 5)
                    
                    // Liquid filled bar with soft glow
                    Capsule()
                        .fill(isSafe ? AttendanceColors.safeGradient : AttendanceColors.criticalGradient)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(pct / 100.0))), height: 5)
                        .shadow(color: (isSafe ? AttendanceColors.safe : AttendanceColors.critical).opacity(0.4), radius: 3, y: 1)
                    
                    // Target goal tick mark (75%)
                    Rectangle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: 1.5, height: 8)
                        .offset(x: max(0, min(geo.size.width - 2, geo.size.width * CGFloat(viewModel.targetThreshold / 100.0))))
                }
            }
            .frame(height: 8)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.24), Color.white.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 2. SAFE TO SKIP PERIODS (Liquid Glass Tile)
    
    @ViewBuilder
    private func safeToSkipGlassCard(_ attendance: AttendanceResponse) -> some View {
        let advice = attendance.getBunkAdvice(targetThreshold: viewModel.targetThreshold)
        let isSafe = advice.status == .safe
        let color = isSafe ? AttendanceColors.safe : AttendanceColors.critical
        
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.15))
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
                
                Image(systemName: isSafe ? "shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.4), radius: 2)
            }
            .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(isSafe ? "Safe to Skip:" : "Must Attend:")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(isSafe ? "\(advice.periodsCanSkip) Periods" : "\(advice.periodsNeedToAttend) Periods")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
                
                Text(isSafe ? "Buffer above \(Int(viewModel.targetThreshold))% target goal" : "Attend next \(advice.periodsNeedToAttend) classes to reach \(Int(viewModel.targetThreshold))%")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(color.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), color.opacity(0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 3. TODAY'S ATTENDANCE FROM ATTENDANCE GRID (Liquid Glass Tile)
    
    @ViewBuilder
    private func todayAttendanceGridGlassCard(_ attendance: AttendanceResponse) -> some View {
        let grid = viewModel.todayGridAttendance
        let records = grid?.records ?? []
        let timeline = grid?.timeline ?? viewModel.todayTimeline
        let summary = attendance.getTodaySummary()
        
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Text("TODAY'S GRID")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text("(\(grid?.dateHeader ?? "Today"))")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                if !records.isEmpty {
                    let presentCount = records.filter { $0.status == .present || $0.statusString.uppercased().contains("P") }.count
                    let absentCount = records.filter { $0.status == .absent || $0.statusString.uppercased().contains("A") }.count
                    Text("\(presentCount)P • \(absentCount)A")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                } else if !timeline.isEmpty && (summary.present > 0 || summary.absent > 0) {
                    Text("\(summary.present)P • \(summary.absent)A")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            
            // Period timeline dots (P1, P2, P3...)
            if !timeline.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(timeline.enumerated()), id: \.offset) { index, status in
                        HStack(spacing: 2) {
                            Text("P\(index + 1)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Circle()
                                .fill(status.color)
                                .frame(width: 6, height: 6)
                                .shadow(color: status.color.opacity(0.5), radius: 2)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(status.color.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(status.color.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
            }
            
            // Marked subjects in today's grid
            if !records.isEmpty {
                VStack(spacing: 3) {
                    ForEach(records) { record in
                        let isP = record.status == .present || record.statusString.uppercased().contains("P")
                        let isA = record.status == .absent || (record.statusString.uppercased().contains("A") && !record.statusString.uppercased().contains("P"))
                        let c = isP ? AttendanceColors.safe : (isA ? AttendanceColors.critical : AttendanceColors.purple)
                        
                        HStack(spacing: 6) {
                            Text(record.statusString.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(c)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(c.opacity(0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(c.opacity(0.3), lineWidth: 0.5)
                                )
                            
                            Text(record.subjectName)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(isP ? "Present" : (isA ? "Absent" : record.status.title))
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(c)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.03))
                        )
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("No attendance marks recorded in grid for today yet")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.white.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Action Footer (Liquid Glass Open Dashboard & Custom Glass Menu Button)
    
    @ViewBuilder
    private func footerActionBar() -> some View {
        HStack(spacing: 8) {
            // Liquid Glass Primary Button
            Button {
                onOpenDashboard()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11, weight: .bold))
                    Text("Open Dashboard")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.12, green: 0.54, blue: 1.0), Color(red: 0.04, green: 0.42, blue: 0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: Color.blue.opacity(0.35), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Custom Liquid Glass Options Button (No weird caret or white circle!)
            Menu {
                if !viewModel.savedAccounts.isEmpty {
                    Text("Switch Student Account")
                    ForEach(viewModel.savedAccounts) { account in
                        Button(account.displayName) {
                            Task { await viewModel.switchAccount(to: account.studentId) }
                        }
                    }
                    Divider()
                }
                
                Button("Refresh Attendance") {
                    Task { await viewModel.refresh() }
                }
                
                Button("Preferences & Settings...") {
                    viewModel.activeTab = .settings
                    onOpenDashboard()
                }
                
                Divider()
                
                Button("Quit Attendance") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.75)
                    
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary.opacity(0.85))
                }
                .frame(width: 28, height: 28)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
        }
        .padding(.top, 2)
    }
}

// MARK: - Compact Login View for Menu Bar

private struct MenuBarLoginView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    var onOpenDashboard: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 24))
                .foregroundColor(AttendanceColors.accent)
            
            Text("College Attendance")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            
            VStack(spacing: 6) {
                TextField("Student ID", text: $viewModel.menuBarLoginStudentId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                
                SecureField("Password", text: $viewModel.menuBarLoginPassword)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
            }
            
            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundColor(AttendanceColors.critical)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                Task {
                    _ = await viewModel.login(
                        studentId: viewModel.menuBarLoginStudentId,
                        password: viewModel.menuBarLoginPassword
                    )
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text("Sign In")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isLoading || viewModel.menuBarLoginStudentId.isEmpty || viewModel.menuBarLoginPassword.isEmpty)
        }
        .padding(14)
    }
}
