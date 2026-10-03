import SwiftUI

public struct SettingsTabView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @ObservedObject var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject var syncManager = BackgroundSyncManager.shared
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Account Management
                accountsSection
                
                // 2. Target Attendance Threshold
                thresholdSection
                
                // 3. System & Startup (SMAppService)
                launchAtLoginSection
                
                // 4. Background Sync Settings
                syncSection
                
                // 5. API Protocol & Security
                apiProtocolSection
                
                // 6. Notifications & Test
                notificationSection
                
                // 7. Appearance
                appearanceSection
                
                // 8. Sign Out
                signOutSection
            }
            .padding(22)
        }
        .sheet(isPresented: $viewModel.showingAddAccountSheet) {
            addAccountSheet
        }
        .sheet(isPresented: $viewModel.showingReauthSheet) {
            reauthSheet
        }
    }
    
    // MARK: - Accounts Section
    
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Student Accounts", systemImage: "person.2.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    viewModel.showingAddAccountSheet = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            VStack(spacing: 10) {
                ForEach(viewModel.savedAccounts) { account in
                    let isActive = account.studentId == viewModel.currentAccount?.studentId
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isActive ? AttendanceColors.accent : Color.secondary.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(isActive ? .white : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                if viewModel.editingAliasId == account.studentId {
                                    HStack {
                                        TextField("Custom Alias", text: $viewModel.editingAliasText)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(size: 11))
                                            .frame(maxWidth: 160)
                                        Button("Save") {
                                            viewModel.updateAccountAlias(studentId: account.studentId, customName: viewModel.editingAliasText)
                                            viewModel.editingAliasId = nil
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.mini)
                                    }
                                } else {
                                    HStack(spacing: 6) {
                                        Text(account.displayName)
                                            .font(.system(size: 13, weight: .bold))
                                        
                                        Button {
                                            viewModel.editingAliasId = account.studentId
                                            viewModel.editingAliasText = account.customName ?? ""
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Edit custom name")
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Text(account.studentId)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        
                                        if account.hasAuthError {
                                            Text("• Credential Error")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(AttendanceColors.critical)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if isActive {
                                Text("ACTIVE")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(AttendanceColors.accent))
                                    .foregroundColor(.white)
                            } else {
                                Button("Switch") {
                                    Task { await viewModel.switchAccount(to: account.studentId) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            Button {
                                viewModel.removeAccount(studentId: account.studentId)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(AttendanceColors.critical)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove account and delete keychain password")
                        }
                        
                        if let err = account.authError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AttendanceColors.critical)
                                Text(err)
                                    .font(.system(size: 11))
                                    .foregroundColor(AttendanceColors.critical)
                                    .lineLimit(2)
                                Spacer()
                                Button("Update Password") {
                                    viewModel.promptReauth(for: account.studentId)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                                .tint(AttendanceColors.critical)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? AttendanceColors.accent.opacity(0.06) : Color.primary.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(account.hasAuthError ? AttendanceColors.critical.opacity(0.4) : (isActive ? AttendanceColors.accent.opacity(0.3) : Color.primary.opacity(0.04)), lineWidth: 1)
                    )
                }
            }
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
    
    // MARK: - Threshold Section
    
    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Target Attendance Threshold", systemImage: "target")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Text(String(format: "%.0f%%", viewModel.targetThreshold))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(thresholdColor)
            }
            
            Text("Set your college's minimum attendance requirement. Alerts, margin meters, and bunk simulator advice will dynamically compute against this goal.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Slider(
                value: Binding(
                    get: { viewModel.targetThreshold },
                    set: { viewModel.setTargetThreshold($0) }
                ),
                in: 50...95,
                step: 1
            )
            .accentColor(thresholdColor)
            
            // Preset milestone buttons
            HStack(spacing: 8) {
                presetButton(title: "75% Standard", value: 75)
                presetButton(title: "80% Safe Zone", value: 80)
                presetButton(title: "85% Honors", value: 85)
                presetButton(title: "90% Distinction", value: 90)
            }
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
    
    private var thresholdColor: Color {
        if viewModel.targetThreshold < 75 {
            return AttendanceColors.warning
        } else if viewModel.targetThreshold <= 80 {
            return AttendanceColors.accent
        } else {
            return AttendanceColors.safe
        }
    }
    
    private func presetButton(title: String, value: Double) -> some View {
        let isSelected = Int(viewModel.targetThreshold) == Int(value)
        return Button {
            viewModel.setTargetThreshold(value)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? AttendanceColors.accent.opacity(0.15) : Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? AttendanceColors.accent : Color.clear, lineWidth: 1)
                )
                .foregroundColor(isSelected ? AttendanceColors.accent : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Launch at Login (SMAppService)
    
    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("System & Startup", systemImage: "macwindow.and.cursorarrow")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            Toggle(isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch automatically at login")
                        .font(.system(size: 12, weight: .semibold))
                    
                    if let msg = launchAtLogin.statusMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Uses native macOS SMAppService to initialize the menu bar monitor in the background.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
    
    // MARK: - Sync Section
    
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Background Synchronization", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    Task {
                        await syncManager.executeSyncCycle()
                    }
                } label: {
                    if syncManager.isSyncing {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Label("Sync Now", systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(syncManager.isSyncing)
            }
            
            // Sync status display
            HStack(spacing: 8) {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 8, height: 8)
                
                Text(syncManager.syncState.displayText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let next = syncManager.nextScheduledSyncDate {
                    Text("Next: \(formattedTime(next))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            HStack {
                Text("Sync Interval")
                    .font(.system(size: 12, weight: .medium))
                
                Spacer()
                
                Picker("", selection: Binding(
                    get: { viewModel.refreshIntervalMinutes },
                    set: { viewModel.setRefreshInterval($0) }
                )) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("3 hours (Recommended)").tag(180)
                    Text("6 hours").tag(360)
                }
                .frame(width: 200)
            }
            
            Toggle(isOn: Binding(
                get: { viewModel.autoSyncActiveHours },
                set: { viewModel.setAutoSyncActiveHours($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync during college hours only (9 AM – 4 PM)")
                        .font(.system(size: 12, weight: .medium))
                    Text("Preserves battery and network bandwidth when classes are not in session.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
    
    // MARK: - API Protocol & Security Section
    
    private var apiProtocolSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Protocol & Security", systemImage: "network.badge.shield.half.filled")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Request Method")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.preferredAPIMethod },
                        set: { viewModel.setAPIMethod($0) }
                    )) {
                        ForEach(APIMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .frame(width: 230)
                }
                
                Text(viewModel.preferredAPIMethod.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider().opacity(0.5)
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(AttendanceColors.safe)
                    .font(.system(size: 14))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Strict Transport Security (ATS) & Keychain Enforced")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Encrypted communication over TLS 1.3 with hardware-backed macOS Keychain credential storage.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
    
    // MARK: - Notification Section
    
    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notifications", systemImage: "bell.badge.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            Text("Receive native macOS alerts when your overall attendance drops below your \(Int(viewModel.targetThreshold))% goal.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Button("Send Test Notification") {
                NotificationManager.shared.postLowAttendanceNotification(
                    percentage: viewModel.targetThreshold - 2.5,
                    threshold: viewModel.targetThreshold
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Appearance & Theme", systemImage: "paintbrush.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            
            Picker("", selection: Binding(
                get: { viewModel.themePreference },
                set: { viewModel.setThemePreference($0) }
            )) {
                Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                Label("Light", systemImage: "sun.max.fill").tag("light")
                Label("Dark", systemImage: "moon.fill").tag("dark")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
    
    // MARK: - Sign Out Section
    
    private var signOutSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sign Out")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AttendanceColors.critical)
                Text("Clears credentials and cached attendance data for the active student account.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Log Out") {
                viewModel.logout()
            }
            .buttonStyle(.borderedProminent)
            .tint(AttendanceColors.critical)
            .controlSize(.regular)
        }
        .attendanceCard(
            cornerRadius: 14,
            padding: 16,
            borderColor: AttendanceColors.critical.opacity(0.2)
        )
    }
    
    // MARK: - Helpers
    
    private var syncStatusColor: Color {
        switch syncManager.syncState {
        case .idle: return .secondary
        case .syncing: return AttendanceColors.accent
        case .success: return AttendanceColors.safe
        case .failed: return AttendanceColors.critical
        case .skippedOutsideHours: return AttendanceColors.warning
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Add Account Sheet
    
    private var addAccountSheet: some View {
        VStack(spacing: 18) {
            Text("Add Student Account")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            
            VStack(alignment: .leading, spacing: 10) {
                TextField("Student ID / Roll Number", text: $viewModel.newStudentId)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Password", text: $viewModel.newPassword)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Custom Name / Alias (Optional)", text: $viewModel.newCustomName)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let err = viewModel.addAccountError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(AttendanceColors.critical)
            }
            
            HStack {
                Button("Cancel") {
                    viewModel.showingAddAccountSheet = false
                    viewModel.addAccountError = nil
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    Task {
                        viewModel.isAddingAccount = true
                        viewModel.addAccountError = nil
                        let success = await viewModel.login(
                            studentId: viewModel.newStudentId,
                            password: viewModel.newPassword,
                            customName: viewModel.newCustomName.isEmpty ? nil : viewModel.newCustomName
                        )
                        viewModel.isAddingAccount = false
                        if success {
                            viewModel.showingAddAccountSheet = false
                            viewModel.newStudentId = ""
                            viewModel.newPassword = ""
                            viewModel.newCustomName = ""
                        } else {
                            viewModel.addAccountError = viewModel.errorMessage
                        }
                    }
                } label: {
                    if viewModel.isAddingAccount {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text("Add Account")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isAddingAccount || viewModel.newStudentId.isEmpty || viewModel.newPassword.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
    
    // MARK: - Re-authentication Sheet
    
    private var reauthSheet: some View {
        VStack(spacing: 18) {
            Image(systemName: "key.fill")
                .font(.system(size: 28))
                .foregroundColor(AttendanceColors.warning)
            
            Text("Update Password")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            
            Text("Enter updated password for Student ID: \(viewModel.reauthStudentId). Credentials will be stored in your macOS Keychain.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            SecureField("Updated Password", text: $viewModel.reauthPassword)
                .textFieldStyle(.roundedBorder)
            
            if let err = viewModel.reauthError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(AttendanceColors.critical)
                    .multilineTextAlignment(.center)
            }
            
            HStack {
                Button("Cancel") {
                    viewModel.showingReauthSheet = false
                    viewModel.reauthError = nil
                    viewModel.reauthPassword = ""
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    Task {
                        _ = await viewModel.reauthenticate(
                            studentId: viewModel.reauthStudentId,
                            password: viewModel.reauthPassword
                        )
                    }
                } label: {
                    if viewModel.isReauthenticating {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text("Save & Reconnect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isReauthenticating || viewModel.reauthPassword.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
