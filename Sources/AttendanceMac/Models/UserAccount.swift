import Foundation

public struct UserAccount: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var studentId: String
    public var studentName: String?
    public var customName: String?
    public var lastUpdated: Date?
    public var authError: String?
    
    public init(
        id: UUID = UUID(),
        studentId: String,
        studentName: String? = nil,
        customName: String? = nil,
        lastUpdated: Date? = nil,
        authError: String? = nil
    ) {
        self.id = id
        self.studentId = studentId
        self.studentName = studentName
        self.customName = customName
        self.lastUpdated = lastUpdated
        self.authError = authError
    }
    
    public var displayName: String {
        if let custom = customName, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return custom
        }
        if let name = studentName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return "Student (\(studentId))"
    }
    
    public var subtitle: String {
        return studentId
    }
    
    public var hasAuthError: Bool {
        return authError != nil && !(authError?.isEmpty ?? true)
    }
}
