import Foundation

public final class StorageService {
    public static let shared = StorageService()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let keyTargetThreshold = "target_threshold"
    private let keyRefreshInterval = "refresh_interval_minutes"
    private let keyThemePreference = "theme_preference"
    private let keyAutoSyncActiveHours = "auto_sync_active_hours"
    private let keyActiveStartHour = "active_start_hour"
    private let keyActiveEndHour = "active_end_hour"
    private let keyApiMethod = "preferred_api_method"
    private let keyCurrentStudentId = "current_student_id"
    private let keySavedAccounts = "saved_accounts_json"
    private let keyCachePrefix = "attendance_cache_"
    private let keyLastUpdatedPrefix = "last_updated_"
    
    private init() {
        registerDefaults()
    }
    
    private func registerDefaults() {
        defaults.register(defaults: [
            keyTargetThreshold: 75.0,
            keyRefreshInterval: 180, // 3 hours
            keyThemePreference: "system",
            keyAutoSyncActiveHours: true,
            keyActiveStartHour: 9,
            keyActiveEndHour: 16,
            keyApiMethod: "auto"
        ])
    }
    
    // MARK: - Preferences
    
    public var preferredAPIMethod: String {
        get { defaults.string(forKey: keyApiMethod) ?? "auto" }
        set { defaults.set(newValue, forKey: keyApiMethod) }
    }
    
    public var targetThreshold: Double {
        get { defaults.double(forKey: keyTargetThreshold) }
        set { defaults.set(newValue, forKey: keyTargetThreshold) }
    }
    
    public var refreshIntervalMinutes: Int {
        get { defaults.integer(forKey: keyRefreshInterval) }
        set { defaults.set(newValue, forKey: keyRefreshInterval) }
    }
    
    public var themePreference: String {
        get { defaults.string(forKey: keyThemePreference) ?? "system" }
        set { defaults.set(newValue, forKey: keyThemePreference) }
    }
    
    public var autoSyncActiveHoursOnly: Bool {
        get { defaults.bool(forKey: keyAutoSyncActiveHours) }
        set { defaults.set(newValue, forKey: keyAutoSyncActiveHours) }
    }
    
    public var activeStartHour: Int {
        get { defaults.integer(forKey: keyActiveStartHour) }
        set { defaults.set(newValue, forKey: keyActiveStartHour) }
    }
    
    public var activeEndHour: Int {
        get { defaults.integer(forKey: keyActiveEndHour) }
        set { defaults.set(newValue, forKey: keyActiveEndHour) }
    }
    
    public var currentStudentId: String? {
        get { defaults.string(forKey: keyCurrentStudentId) }
        set { defaults.set(newValue, forKey: keyCurrentStudentId) }
    }
    
    public func isCurrentlyInActiveHours() -> Bool {
        guard autoSyncActiveHoursOnly else { return true }
        let currentHour = Calendar.current.component(.hour, from: Date())
        if activeStartHour <= activeEndHour {
            return currentHour >= activeStartHour && currentHour < activeEndHour
        } else {
            return currentHour >= activeStartHour || currentHour < activeEndHour
        }
    }
    
    // MARK: - Saved Accounts
    
    public func getSavedAccounts() -> [UserAccount] {
        guard let data = defaults.data(forKey: keySavedAccounts) else { return [] }
        return (try? JSONDecoder().decode([UserAccount].self, from: data)) ?? []
    }
    
    public func saveAccounts(_ accounts: [UserAccount]) {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: keySavedAccounts)
        }
    }
    
    public func addOrUpdateAccount(_ account: UserAccount) {
        var accounts = getSavedAccounts()
        if let idx = accounts.firstIndex(where: { $0.studentId == account.studentId }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        saveAccounts(accounts)
    }
    
    public func removeAccount(studentId: String) {
        var accounts = getSavedAccounts()
        accounts.removeAll { $0.studentId == studentId }
        saveAccounts(accounts)
        clearCache(for: studentId)
        
        if currentStudentId == studentId {
            currentStudentId = accounts.first?.studentId
        }
    }
    
    // MARK: - Cache & Last Updated
    
    public func getCachedAttendance(for studentId: String) -> AttendanceResponse? {
        guard let data = defaults.data(forKey: keyCachePrefix + studentId) else { return nil }
        return try? JSONDecoder().decode(AttendanceResponse.self, from: data)
    }
    
    public func saveAttendanceCache(for studentId: String, response: AttendanceResponse) {
        if let data = try? JSONEncoder().encode(response) {
            defaults.set(data, forKey: keyCachePrefix + studentId)
            defaults.set(Date().timeIntervalSince1970, forKey: keyLastUpdatedPrefix + studentId)
        }
    }
    
    public func getLastUpdated(for studentId: String) -> Date? {
        let timestamp = defaults.double(forKey: keyLastUpdatedPrefix + studentId)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    public func clearCache(for studentId: String) {
        defaults.removeObject(forKey: keyCachePrefix + studentId)
        defaults.removeObject(forKey: keyLastUpdatedPrefix + studentId)
    }
}
