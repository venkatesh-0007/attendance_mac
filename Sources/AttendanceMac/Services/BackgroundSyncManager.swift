import Foundation
import Combine
import AppKit

public enum SyncState: Equatable {
    case idle
    case syncing
    case success(Date)
    case failed(String)
    case skippedOutsideHours
    
    public var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing in background..."
        case .success(let date):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "Last synced at \(formatter.string(from: date))"
        case .failed(let err):
            return "Sync failed: \(err)"
        case .skippedOutsideHours:
            return "Paused (Outside configured college active hours)"
        }
    }
}

/// Robust background attendance synchronizer combining NSBackgroundActivityScheduler and high-frequency active timers
public final class BackgroundSyncManager: ObservableObject {
    public static let shared = BackgroundSyncManager()
    
    @Published public private(set) var syncState: SyncState = .idle
    @Published public private(set) var lastSyncDate: Date? = nil
    @Published public private(set) var nextScheduledSyncDate: Date? = nil
    @Published public private(set) var isSyncing: Bool = false
    
    private var scheduler: NSBackgroundActivityScheduler?
    private var foregroundTimer: AnyCancellable?
    private var wakeObserver: Any?
    private var currentIntervalMinutes: Int = 180
    
    public var onSyncCompleted: (() -> Void)?
    
    private init() {
        setupWakeObservation()
    }
    
    // MARK: - Lifecycle & Scheduling
    
    public func start(intervalMinutes: Int) {
        self.currentIntervalMinutes = max(5, intervalMinutes)
        stop()
        
        let intervalSeconds = TimeInterval(currentIntervalMinutes * 60)
        self.nextScheduledSyncDate = Date().addingTimeInterval(intervalSeconds)
        
        // 1. macOS Background Activity Scheduler (Power-efficient & background-wake capable)
        let backgroundActivity = NSBackgroundActivityScheduler(identifier: "com.attendance.mac.sync")
        backgroundActivity.repeats = true
        backgroundActivity.interval = intervalSeconds
        backgroundActivity.tolerance = intervalSeconds * 0.15 // 15% energy-efficient tolerance
        backgroundActivity.qualityOfService = .utility
        
        backgroundActivity.schedule { [weak self] (completion: @escaping (NSBackgroundActivityScheduler.Result) -> Void) in
            guard let self = self else {
                completion(.finished)
                return
            }
            
            Task {
                _ = await self.executeSyncCycle()
                completion(.finished)
            }
        }
        self.scheduler = backgroundActivity
        
        // 2. Foreground Combine Timer for when user actively uses the Mac app
        foregroundTimer = Timer.publish(every: intervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    _ = await self?.executeSyncCycle()
                }
            }
    }
    
    public func stop() {
        scheduler?.invalidate()
        scheduler = nil
        foregroundTimer?.cancel()
        foregroundTimer = nil
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            wakeObserver = nil
        }
        nextScheduledSyncDate = nil
    }
    
    private func setupWakeObservation() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                // Allow network interfaces and security services 4 seconds to reconnect
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self = self else { return }
                if StorageService.shared.isCurrentlyInActiveHours() {
                    _ = await self.executeSyncCycle()
                }
            }
        }
    }
    
    public func reschedule(intervalMinutes: Int) {
        start(intervalMinutes: intervalMinutes)
    }
    
    // MARK: - Sync Execution
    
    /// Executes a full synchronization cycle across all registered student accounts
    @discardableResult
    public func executeSyncCycle() async -> Bool {
        // Check active college hours if configured
        if !StorageService.shared.isCurrentlyInActiveHours() {
            await MainActor.run {
                self.syncState = .skippedOutsideHours
            }
            return true
        }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncState = .syncing
        }
        
        let storage = StorageService.shared
        let keychain = KeychainService.shared
        let api = AttendanceAPIService.shared
        let notifications = NotificationManager.shared
        
        let accounts = storage.getSavedAccounts()
        guard !accounts.isEmpty else {
            await MainActor.run {
                self.isSyncing = false
                self.syncState = .idle
            }
            return true
        }
        
        var anySuccess = false
        var anyFailureReason: String? = nil
        var updatedAccounts = accounts
        
        for (index, account) in accounts.enumerated() {
            guard let password = keychain.getPassword(for: account.studentId) else {
                // Do not mark authError during background poll! A wake lock or transient issue is not invalid credentials.
                anyFailureReason = "Keychain lock or wake transition for \(account.studentId)"
                continue
            }
            
            do {
                let response = try await api.fetchAttendance(
                    studentId: account.studentId,
                    password: password
                )
                
                anySuccess = true
                updatedAccounts[index].studentName = response.studentName ?? response.rollNumber
                updatedAccounts[index].lastUpdated = Date()
                updatedAccounts[index].authError = nil
                
                storage.saveAttendanceCache(for: account.studentId, response: response)
                
                // If this is the active account, check low attendance threshold
                if account.studentId == storage.currentStudentId {
                    let threshold = storage.targetThreshold
                    if response.overallPercentage < threshold {
                        notifications.postLowAttendanceNotification(
                            percentage: response.overallPercentage,
                            threshold: threshold
                        )
                    }
                }
            } catch let error as APIError {
                if error.isAuthFailure {
                    updatedAccounts[index].authError = error.localizedDescription
                    anyFailureReason = error.localizedDescription
                } else {
                    anyFailureReason = error.localizedDescription
                }
            } catch {
                anyFailureReason = error.localizedDescription
            }
        }
        
        storage.saveAccounts(updatedAccounts)
        
        let now = Date()
        let intervalSeconds = TimeInterval(currentIntervalMinutes * 60)
        let finalSuccess = anySuccess
        let finalFailureReason = anyFailureReason
        
        await MainActor.run {
            self.isSyncing = false
            self.lastSyncDate = now
            self.nextScheduledSyncDate = now.addingTimeInterval(intervalSeconds)
            
            if finalSuccess {
                self.syncState = .success(now)
            } else if let failMsg = finalFailureReason {
                self.syncState = .failed(failMsg)
            } else {
                self.syncState = .idle
            }
            
            self.onSyncCompleted?()
        }
        
        return anySuccess
    }
}
