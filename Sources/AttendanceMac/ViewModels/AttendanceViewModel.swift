import SwiftUI
import Combine

public enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case subjects = "Subjects"
    case timetable = "Timetable"
    case grid = "Attendance Grid"
    case simulator = "Bunk Simulator"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .overview: return "gauge.medium"
        case .subjects: return "books.vertical.fill"
        case .timetable: return "calendar.badge.clock"
        case .grid: return "tablecells.fill"
        case .simulator: return "function"
        case .settings: return "gearshape.fill"
        }
    }
}

@MainActor
public final class AttendanceViewModel: ObservableObject {
    public static let shared = AttendanceViewModel()
    
    // MARK: - Core Published Properties
    
    @Published public var attendance: AttendanceResponse?
    @Published public var isLoading: Bool = false
    @Published public var isRefreshing: Bool = false
    @Published public var isLoggedIn: Bool = false
    @Published public var errorMessage: String? = nil
    
    @Published public var currentAccount: UserAccount?
    @Published public var savedAccounts: [UserAccount] = []
    
    @Published public var targetThreshold: Double = 75.0
    @Published public var refreshIntervalMinutes: Int = 180
    @Published public var themePreference: String = "system"
    @Published public var autoSyncActiveHours: Bool = true
    @Published public var preferredAPIMethod: APIMethod = .auto
    @Published public var lastUpdated: Date? = nil
    @Published public var activeTab: DashboardTab = .overview
    
    // MARK: - UI & Form State
    
    @Published public var loginStudentId: String = ""
    @Published public var loginPassword: String = ""
    @Published public var loginCustomName: String = ""
    
    @Published public var menuBarLoginStudentId: String = ""
    @Published public var menuBarLoginPassword: String = ""
    
    @Published public var timetableSelectedDay: String = ""
    
    @Published public var simulatorExtraLeaves: Int = 0
    @Published public var simulatorExtraAttended: Int = 0
    
    @Published public var subjectsSearchText: String = ""
    @Published public var subjectSimDeltas: [String: Int] = [:]
    
    // Add Account Sheet State
    @Published public var showingAddAccountSheet: Bool = false
    @Published public var newStudentId: String = ""
    @Published public var newPassword: String = ""
    @Published public var newCustomName: String = ""
    @Published public var addAccountError: String? = nil
    @Published public var isAddingAccount: Bool = false
    
    // Re-authentication Sheet State (for invalid/expired credentials)
    @Published public var showingReauthSheet: Bool = false
    @Published public var reauthStudentId: String = ""
    @Published public var reauthPassword: String = ""
    @Published public var reauthError: String? = nil
    @Published public var isReauthenticating: Bool = false
    
    @Published public var editingAliasId: String? = nil
    @Published public var editingAliasText: String = ""
    
    // Exposed Managers
    public let launchAtLogin = LaunchAtLoginManager.shared
    public let syncManager = BackgroundSyncManager.shared
    
    // Private Dependencies
    private let api = AttendanceAPIService.shared
    private let keychain = KeychainService.shared
    private let storage = StorageService.shared
    private let notifications = NotificationManager.shared
    
    public init() {
        loadSettings()
        loadInitialState()
        setupBackgroundSync()
    }
    
    // MARK: - Setup & Initialization
    
    private func loadSettings() {
        targetThreshold = storage.targetThreshold
        refreshIntervalMinutes = storage.refreshIntervalMinutes
        themePreference = storage.themePreference
        autoSyncActiveHours = storage.autoSyncActiveHoursOnly
        savedAccounts = storage.getSavedAccounts()
        
        if let method = APIMethod(rawValue: storage.preferredAPIMethod) {
            preferredAPIMethod = method
            api.preferredMethod = method
        }
    }
    
    private func loadInitialState() {
        notifications.requestAuthorization()
        
        let accounts = storage.getSavedAccounts()
        
        // Pre-warm in-memory credential cache for all saved accounts so sleep/wake never blocks
        for acc in accounts {
            _ = keychain.getPassword(for: acc.studentId)
        }
        
        let currentId = storage.currentStudentId ?? accounts.first?.studentId
        
        if let id = currentId, let account = accounts.first(where: { $0.studentId == id }) {
            currentAccount = account
            isLoggedIn = true
            
            // Load cache immediately
            if let cached = storage.getCachedAttendance(for: id) {
                attendance = cached
                lastUpdated = storage.getLastUpdated(for: id)
            }
            
            // Perform background refresh on launch
            Task {
                await refreshSilently()
            }
        } else {
            isLoggedIn = false
        }
    }
    
    private func setupBackgroundSync() {
        syncManager.onSyncCompleted = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleBackgroundSyncCompletion()
            }
        }
        syncManager.start(intervalMinutes: refreshIntervalMinutes)
    }
    
    private func handleBackgroundSyncCompletion() {
        savedAccounts = storage.getSavedAccounts()
        guard let currentId = currentAccount?.studentId else { return }
        
        if let updated = savedAccounts.first(where: { $0.studentId == currentId }) {
            self.currentAccount = updated
        }
        
        if let cached = storage.getCachedAttendance(for: currentId) {
            self.attendance = cached
            self.lastUpdated = storage.getLastUpdated(for: currentId)
        }
    }
    
    // MARK: - Authentication
    
    public func login(studentId: String, password: String, customName: String? = nil) async -> Bool {
        let cleanId = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanId.isEmpty && !cleanPass.isEmpty else {
            errorMessage = "Please enter both Student ID and Password."
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await api.fetchAttendance(studentId: cleanId, password: cleanPass)
            
            let name = response.studentName ?? response.rollNumber
            let account = UserAccount(
                studentId: cleanId,
                studentName: name,
                customName: customName,
                lastUpdated: Date(),
                authError: nil
            )
            
            // Save credentials exclusively to Keychain (never in UserDefaults)
            keychain.savePassword(cleanPass, for: cleanId)
            storage.currentStudentId = cleanId
            storage.addOrUpdateAccount(account)
            storage.saveAttendanceCache(for: cleanId, response: response)
            
            self.attendance = response
            self.currentAccount = account
            self.savedAccounts = storage.getSavedAccounts()
            self.lastUpdated = Date()
            self.isLoggedIn = true
            self.isLoading = false
            
            // Clear inputs
            self.loginStudentId = ""
            self.loginPassword = ""
            self.loginCustomName = ""
            self.menuBarLoginStudentId = ""
            self.menuBarLoginPassword = ""
            
            // Check for low attendance notification
            checkThresholdAlert(response.overallPercentage)
            
            return true
        } catch let err as APIError {
            isLoading = false
            errorMessage = err.localizedDescription
            return false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    public func reauthenticate(studentId: String, password: String) async -> Bool {
        let cleanId = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanId.isEmpty && !cleanPass.isEmpty else {
            reauthError = "Please enter a valid password."
            return false
        }
        
        isReauthenticating = true
        reauthError = nil
        
        do {
            let response = try await api.fetchAttendance(studentId: cleanId, password: cleanPass)
            
            // Save new password in Keychain
            keychain.savePassword(cleanPass, for: cleanId)
            
            // Update account to clear authError
            if var account = savedAccounts.first(where: { $0.studentId == cleanId }) {
                account.studentName = response.studentName ?? response.rollNumber
                account.lastUpdated = Date()
                account.authError = nil
                storage.addOrUpdateAccount(account)
                
                if currentAccount?.studentId == cleanId {
                    currentAccount = account
                    attendance = response
                    lastUpdated = Date()
                }
            }
            
            savedAccounts = storage.getSavedAccounts()
            storage.saveAttendanceCache(for: cleanId, response: response)
            
            isReauthenticating = false
            showingReauthSheet = false
            reauthPassword = ""
            reauthStudentId = ""
            return true
        } catch let err as APIError {
            isReauthenticating = false
            reauthError = err.localizedDescription
            return false
        } catch {
            isReauthenticating = false
            reauthError = error.localizedDescription
            return false
        }
    }
    
    public func promptReauth(for studentId: String) {
        reauthStudentId = studentId
        reauthPassword = ""
        reauthError = nil
        showingReauthSheet = true
    }
    
    public func logout() {
        if let id = currentAccount?.studentId {
            storage.clearCache(for: id)
            keychain.deletePassword(for: id)
        }
        storage.currentStudentId = nil
        
        attendance = nil
        currentAccount = nil
        isLoggedIn = false
        lastUpdated = nil
        errorMessage = nil
    }
    
    // MARK: - Data Refresh
    
    public func refresh() async {
        guard let account = currentAccount else { return }
        
        // Retrieve password securely from in-memory cache or Keychain
        guard let password = keychain.getPassword(for: account.studentId) else {
            errorMessage = "Keychain is unlocking. Please try refreshing again in a moment."
            // NOTE: Never markAuthError here; a sleep/wake lock or transient daemon state is not invalid credentials!
            return
        }
        
        isRefreshing = true
        errorMessage = nil
        
        do {
            let response = try await api.fetchAttendance(
                studentId: account.studentId,
                password: password
            )
            
            let name = response.studentName ?? response.rollNumber
            var updatedAccount = account
            updatedAccount.studentName = name
            updatedAccount.lastUpdated = Date()
            updatedAccount.authError = nil
            
            storage.addOrUpdateAccount(updatedAccount)
            storage.saveAttendanceCache(for: account.studentId, response: response)
            
            self.attendance = response
            self.currentAccount = updatedAccount
            self.savedAccounts = storage.getSavedAccounts()
            self.lastUpdated = Date()
            self.isRefreshing = false
            
            checkThresholdAlert(response.overallPercentage)
        } catch let err as APIError {
            isRefreshing = false
            errorMessage = err.localizedDescription
            if err.isAuthFailure {
                markAuthError(on: account, message: err.localizedDescription)
            }
        } catch {
            isRefreshing = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func refreshSilently() async {
        guard let account = currentAccount else { return }
        guard let password = keychain.getPassword(for: account.studentId) else {
            // Keychain busy during wake/background cycle; do not disrupt account or mark error
            return
        }
        
        do {
            let response = try await api.fetchAttendance(
                studentId: account.studentId,
                password: password
            )
            
            var updated = account
            updated.studentName = response.studentName ?? response.rollNumber
            updated.lastUpdated = Date()
            updated.authError = nil
            storage.addOrUpdateAccount(updated)
            storage.saveAttendanceCache(for: account.studentId, response: response)
            
            self.currentAccount = updated
            self.attendance = response
            self.lastUpdated = Date()
            self.savedAccounts = storage.getSavedAccounts()
            checkThresholdAlert(response.overallPercentage)
        } catch let err as APIError {
            if err.isAuthFailure {
                markAuthError(on: account, message: err.localizedDescription)
            }
        } catch {
            // Network failure during background poll is quiet
        }
    }
    
    private func markAuthError(on account: UserAccount, message: String) {
        var updated = account
        updated.authError = message
        storage.addOrUpdateAccount(updated)
        savedAccounts = storage.getSavedAccounts()
        if currentAccount?.studentId == account.studentId {
            currentAccount = updated
        }
    }
    
    // MARK: - Account Management
    
    public func switchAccount(to studentId: String) async {
        guard let target = savedAccounts.first(where: { $0.studentId == studentId }) else { return }
        
        currentAccount = target
        storage.currentStudentId = target.studentId
        
        if let cached = storage.getCachedAttendance(for: target.studentId) {
            attendance = cached
            lastUpdated = storage.getLastUpdated(for: target.studentId)
        } else {
            attendance = nil
            lastUpdated = nil
        }
        
        await refresh()
    }
    
    public func removeAccount(studentId: String) {
        keychain.deletePassword(for: studentId)
        storage.removeAccount(studentId: studentId)
        savedAccounts = storage.getSavedAccounts()
        
        if currentAccount?.studentId == studentId {
            if let first = savedAccounts.first {
                Task {
                    await switchAccount(to: first.studentId)
                }
            } else {
                logout()
            }
        }
    }
    
    public func updateAccountAlias(studentId: String, customName: String) {
        var accounts = savedAccounts
        if let idx = accounts.firstIndex(where: { $0.studentId == studentId }) {
            accounts[idx].customName = customName.isEmpty ? nil : customName
            storage.saveAccounts(accounts)
            savedAccounts = accounts
            if currentAccount?.studentId == studentId {
                currentAccount = accounts[idx]
            }
        }
    }
    
    // MARK: - Preferences Update
    
    public func setTargetThreshold(_ newThreshold: Double) {
        targetThreshold = newThreshold
        storage.targetThreshold = newThreshold
    }
    
    public func setRefreshInterval(_ minutes: Int) {
        refreshIntervalMinutes = minutes
        storage.refreshIntervalMinutes = minutes
        syncManager.reschedule(intervalMinutes: minutes)
    }
    
    public func setThemePreference(_ theme: String) {
        themePreference = theme
        storage.themePreference = theme
    }
    
    public func setAutoSyncActiveHours(_ enabled: Bool) {
        autoSyncActiveHours = enabled
        storage.autoSyncActiveHoursOnly = enabled
    }
    
    public func setAPIMethod(_ method: APIMethod) {
        preferredAPIMethod = method
        api.preferredMethod = method
        storage.preferredAPIMethod = method.rawValue
    }
    
    // MARK: - Computed Status Helpers
    
    public var overallPercentage: Double {
        attendance?.overallPercentage ?? 0.0
    }
    
    public var overallStatus: OverallAttendanceStatus {
        if overallPercentage >= targetThreshold {
            return .safe
        } else {
            return .critical
        }
    }
    
    public var menuBarDisplayString: String {
        if let attendance = attendance {
            return String(format: "%.1f%%", attendance.overallPercentage)
        } else if isLoading || isRefreshing {
            return "Syncing..."
        } else {
            return "Attendance"
        }
    }
    
    public var bunkAdvice: BunkAdvice? {
        attendance?.getBunkAdvice(targetThreshold: targetThreshold)
    }
    
    public var todayTimeline: [AttendanceStatus] {
        attendance?.getTodayAttendanceTimeline() ?? []
    }
    
    public var todayGridAttendance: GridDayAttendance? {
        attendance?.getTodayGridAttendance()
    }
    
    public var todayClasses: [TimetableClass] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        let todayName = formatter.string(from: Date())
        
        return attendance?.timetable?.first(where: {
            $0.day.caseInsensitiveCompare(todayName) == .orderedSame
        })?.classes ?? []
    }
    
    private func checkThresholdAlert(_ percentage: Double) {
        if percentage < targetThreshold {
            notifications.postLowAttendanceNotification(
                percentage: percentage,
                threshold: targetThreshold
            )
        }
    }
}
