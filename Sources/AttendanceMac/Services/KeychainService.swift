import Foundation
import Security

/// Thread-safe Keychain service providing per-account credential storage
/// with in-memory caching and sleep/wake transition resilience.
public final class KeychainService {
    public static let shared = KeychainService()
    
    private let serviceName = "com.attendance.mac.credentials"
    private let lock = NSLock()
    
    /// High-performance thread-safe in-memory cache to prevent repeated Keychain calls
    /// and eliminate errSecInteractionNotAllowed / password prompts upon macOS sleep/wake.
    private var memoryCache: [String: String] = [:]
    
    private init() {
        migrateLegacyCredentialsIfNeeded()
    }
    
    // MARK: - Per-Account Password Operations
    
    /// Securely saves or updates a student's password in the macOS Keychain and memory cache
    @discardableResult
    public func savePassword(_ password: String, for studentId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let cleanId = studentId.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
        guard !cleanId.isEmpty, let data = password.data(using: .utf8) else { return false }
        
        let normKey = cleanId.lowercased()
        memoryCache[normKey] = password
        
        // Check if an entry already exists for this studentId
        let checkQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: cleanId
        ]
        
        let existingStatus = SecItemCopyMatching(checkQuery as CFDictionary, nil)
        
        if existingStatus == errSecSuccess {
            // Update existing entry
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            let updateStatus = SecItemUpdate(checkQuery as CFDictionary, attributesToUpdate as CFDictionary)
            return updateStatus == errSecSuccess
        } else {
            // Add new entry
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: cleanId,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
    }
    
    /// Retrieves a student's password from the in-memory cache or macOS Keychain with sleep/wake retry
    public func getPassword(for studentId: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        let cleanId = studentId.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
        guard !cleanId.isEmpty else { return nil }
        
        let normKey = cleanId.lowercased()
        
        // 1. Fast in-memory cache hit (immune to macOS sleep, lock screen, and securityd restarts)
        if let cached = memoryCache[normKey], !cached.isEmpty {
            return cached
        }
        
        // 2. Query Keychain with retry loop for sleep/wake transition resilience
        var passwordFound: String? = nil
        let candidateKeys = [cleanId, cleanId.uppercased(), cleanId.lowercased()]
        
        for candidate in Set(candidateKeys) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: candidate,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            // Retry up to 3 times if security daemon is busy or system is waking from sleep
            var attempts = 0
            while attempts < 3 {
                var dataTypeRef: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
                
                if status == errSecSuccess,
                   let data = dataTypeRef as? Data,
                   let pass = String(data: data, encoding: .utf8), !pass.isEmpty {
                    passwordFound = pass
                    break
                }
                
                // If system is locked or waking from sleep (errSecInteractionNotAllowed = -25308 or errSecAuthFailed = -25293)
                if status == errSecInteractionNotAllowed || status == -25293 {
                    attempts += 1
                    Thread.sleep(forTimeInterval: 0.15 * Double(attempts))
                    continue
                }
                
                // Item not found or other non-transient status
                break
            }
            
            if passwordFound != nil { break }
        }
        
        if let found = passwordFound {
            memoryCache[normKey] = found
            return found
        }
        
        return nil
    }
    
    /// Deletes a specific student's credentials from the Keychain and memory cache
    @discardableResult
    public func deletePassword(for studentId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let cleanId = studentId.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
        guard !cleanId.isEmpty else { return false }
        
        let normKey = cleanId.lowercased()
        memoryCache.removeValue(forKey: normKey)
        
        let candidateKeys = [cleanId, cleanId.uppercased(), cleanId.lowercased()]
        var anySuccess = false
        
        for candidate in Set(candidateKeys) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: candidate
            ]
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                anySuccess = true
            }
        }
        
        return anySuccess
    }
    
    /// Checks if a password exists in memory or the Keychain for a studentId
    public func hasPassword(for studentId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let cleanId = studentId.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
        guard !cleanId.isEmpty else { return false }
        
        let normKey = cleanId.lowercased()
        if memoryCache[normKey] != nil { return true }
        
        let candidateKeys = [cleanId, cleanId.uppercased(), cleanId.lowercased()]
        for candidate in Set(candidateKeys) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: candidate,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            let status = SecItemCopyMatching(query as CFDictionary, nil)
            if status == errSecSuccess { return true }
        }
        
        return false
    }
    
    /// Deletes all credentials associated with this app from the Keychain and memory cache
    @discardableResult
    public func deleteAllPasswords() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        memoryCache.removeAll()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Legacy Migration
    
    private func migrateLegacyCredentialsIfNeeded() {
        let legacyAccountKey = "active_student_credentials"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: legacyAccountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let string = String(data: data, encoding: .utf8) {
            let parts = string.components(separatedBy: ":")
            if parts.count >= 2 {
                let studentId = parts[0]
                let password = parts.dropFirst().joined(separator: ":")
                savePassword(password, for: studentId)
            }
            
            // Delete legacy entry
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: legacyAccountKey
            ]
            SecItemDelete(deleteQuery as CFDictionary)
        }
    }
}
