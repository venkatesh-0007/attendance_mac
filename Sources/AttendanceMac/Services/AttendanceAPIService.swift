import Foundation

public enum APIMethod: String, CaseIterable, Identifiable {
    case auto = "auto"
    case post = "post"
    case get = "get"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .auto: return "Auto (POST with GET Fallback)"
        case .post: return "POST (Secure JSON Body)"
        case .get: return "GET (Query Parameters)"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .auto: return "Attempts secure POST body first; seamlessly falls back to GET if server denies POST."
        case .post: return "Strictly sends credentials via HTTP POST body. Zero credentials in URL query."
        case .get: return "Transmits credentials via URL query parameters (Legacy API format)."
        }
    }
}

public enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidCredentials(String)
    case sessionExpired
    case networkUnavailable(String)
    case serverError(statusCode: Int, message: String)
    case portalMaintenance
    case invalidResponseFormat(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The attendance API endpoint URL is invalid."
        case .invalidCredentials(let msg):
            return msg.isEmpty ? "Invalid Student ID or password. Please verify your credentials." : msg
        case .sessionExpired:
            return "Your college portal session has expired. Please sign in again."
        case .networkUnavailable(let reason):
            return "Network connection unavailable: \(reason)"
        case .serverError(let code, let msg):
            return "College portal server error (HTTP \(code)): \(msg)"
        case .portalMaintenance:
            return "The college attendance portal is currently down for maintenance. Please try again later."
        case .invalidResponseFormat(let details):
            return "Unable to parse college portal response: \(details)"
        case .unknown(let msg):
            return msg
        }
    }
    
    public var isAuthFailure: Bool {
        switch self {
        case .invalidCredentials, .sessionExpired:
            return true
        default:
            return false
        }
    }
}

public final class AttendanceAPIService {
    public static let shared = AttendanceAPIService()
    
    public var baseURL = "https://register-api-green.vercel.app/attendance"
    public var preferredMethod: APIMethod = .auto
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Main Fetch
    
    public func fetchAttendance(studentId: String, password: String) async throws -> AttendanceResponse {
        let cleanId = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanId.isEmpty && !cleanPassword.isEmpty else {
            throw APIError.invalidCredentials("Student ID and password cannot be blank.")
        }
        
        switch preferredMethod {
        case .post:
            return try await executePost(studentId: cleanId, password: cleanPassword)
        case .get:
            return try await executeGet(studentId: cleanId, password: cleanPassword)
        case .auto:
            do {
                return try await executePost(studentId: cleanId, password: cleanPassword)
            } catch let error as APIError {
                // If POST was rejected by server policy or method not allowed, fallback to GET
                if case .serverError(let code, _) = error, code == 403 || code == 405 || code == 404 {
                    return try await executeGet(studentId: cleanId, password: cleanPassword)
                }
                throw error
            }
        }
    }
    
    // MARK: - POST Request Implementation
    
    private func executePost(studentId: String, password: String) async throws -> AttendanceResponse {
        guard let url = URL(string: baseURL) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let bodyPayload: [String: String] = [
            "student_id": studentId,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload, options: [])
        } catch {
            throw APIError.invalidResponseFormat("Failed to serialize request payload.")
        }
        
        return try await performRequest(request)
    }
    
    // MARK: - GET Request Implementation
    
    private func executeGet(studentId: String, password: String) async throws -> AttendanceResponse {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "student_id", value: studentId),
            URLQueryItem(name: "password", value: password)
        ]
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return try await performRequest(request)
    }
    
    // MARK: - Request Execution & Response Handling
    
    private func performRequest(_ request: URLRequest) async throws -> AttendanceResponse {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let err as URLError {
            switch err.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                throw APIError.networkUnavailable(err.localizedDescription)
            case .timedOut:
                throw APIError.networkUnavailable("The connection to the portal timed out.")
            default:
                throw APIError.networkUnavailable(err.localizedDescription)
            }
        } catch {
            throw APIError.networkUnavailable(error.localizedDescription)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponseFormat("Invalid HTTP response received.")
        }
        
        let rawBodyString = String(data: data, encoding: .utf8) ?? ""
        
        // Handle HTTP Status Codes
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            if rawBodyString.localizedCaseInsensitiveContains("not allowed by policy") {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Endpoint method not permitted by server policy.")
            }
            
            // Check if response is HTML or captive portal (e.g., college/hotel Wi-Fi splash page)
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            if contentType.contains("text/html") ||
               rawBodyString.localizedCaseInsensitiveContains("<!doctype") ||
               rawBodyString.localizedCaseInsensitiveContains("<html") ||
               rawBodyString.localizedCaseInsensitiveContains("<title>login</title>") {
                throw APIError.networkUnavailable("Local Wi-Fi login or captive portal detected. Please connect to the internet.")
            }
            
            let message = extractErrorMessage(from: rawBodyString) ?? "Authentication failed. Please verify your credentials."
            throw APIError.invalidCredentials(message)
        case 404, 405:
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Service endpoint method not supported.")
        case 502, 503, 504:
            throw APIError.portalMaintenance
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: extractErrorMessage(from: rawBodyString) ?? "Unexpected status code.")
        }
        
        // Parse JSON Payload (Handle double-encoding if present)
        let decoder = JSONDecoder()
        var targetData = data
        if let rawString = try? decoder.decode(String.self, from: data),
           let unescapedData = rawString.data(using: .utf8) {
            targetData = unescapedData
        }
        
        let attendanceResponse: AttendanceResponse
        do {
            attendanceResponse = try decoder.decode(AttendanceResponse.self, from: targetData)
        } catch {
            // Check if body was a plain error message
            if let customMsg = extractErrorMessage(from: rawBodyString) {
                if customMsg.localizedCaseInsensitiveContains("password") ||
                   customMsg.localizedCaseInsensitiveContains("invalid") ||
                   customMsg.localizedCaseInsensitiveContains("credential") ||
                   customMsg.localizedCaseInsensitiveContains("user") {
                    throw APIError.invalidCredentials(customMsg)
                }
                throw APIError.unknown(customMsg)
            }
            throw APIError.invalidResponseFormat(error.localizedDescription)
        }
        
        // Check for business-level error in JSON
        if let errorMsg = attendanceResponse.error, !errorMsg.isEmpty {
            let lower = errorMsg.lowercased()
            if lower.contains("password") || lower.contains("invalid") || lower.contains("credentials") || lower.contains("not found") {
                throw APIError.invalidCredentials(errorMsg)
            }
            if lower.contains("session") || lower.contains("expired") {
                throw APIError.sessionExpired
            }
            throw APIError.unknown(errorMsg)
        }
        
        // Validate required attendance data fields
        if attendanceResponse.totalInfo == nil && attendanceResponse.subjectwiseSummary == nil {
            throw APIError.invalidResponseFormat("The server returned an empty or malformed attendance record.")
        }
        
        return attendanceResponse
    }
    
    private func extractErrorMessage(from body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        
        // Never treat HTML markup as a valid API error message
        if trimmed.localizedCaseInsensitiveContains("<!doctype") ||
           trimmed.localizedCaseInsensitiveContains("<html") ||
           trimmed.localizedCaseInsensitiveContains("<head>") {
            return nil
        }
        
        // Try parsing JSON error field
        if let data = trimmed.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let msg = dict["error"] as? String, !msg.isEmpty { return msg }
            if let msg = dict["message"] as? String, !msg.isEmpty { return msg }
            if let msg = dict["detail"] as? String, !msg.isEmpty { return msg }
        }
        
        if trimmed.count < 150 {
            return trimmed
        }
        
        return nil
    }
}
