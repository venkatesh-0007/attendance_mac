import Foundation

// MARK: - Root API Response

public struct AttendanceResponse: Codable, Equatable {
    public let studentName: String?
    public let rollNumber: String?
    public let totalInfo: TotalInfo?
    public let subjectwiseSummary: [SubjectSummary]?
    public let attendanceTable: AttendanceTable?
    public let timetable: [TimetableDay]?
    public let facultyInformation: [FacultyInfo]?
    public let error: String?
    
    enum CodingKeys: String, CodingKey {
        case studentName = "student_name"
        case rollNumber = "roll_number"
        case totalInfo = "total_info"
        case subjectwiseSummary = "subjectwise_summary"
        case attendanceTable = "attendance_table"
        case timetable
        case facultyInformation = "faculty_information"
        case error
    }
    
    public init(
        studentName: String? = nil,
        rollNumber: String? = nil,
        totalInfo: TotalInfo? = nil,
        subjectwiseSummary: [SubjectSummary]? = nil,
        attendanceTable: AttendanceTable? = nil,
        timetable: [TimetableDay]? = nil,
        facultyInformation: [FacultyInfo]? = nil,
        error: String? = nil
    ) {
        self.studentName = studentName
        self.rollNumber = rollNumber
        self.totalInfo = totalInfo
        self.subjectwiseSummary = subjectwiseSummary
        self.attendanceTable = attendanceTable
        self.timetable = timetable
        self.facultyInformation = facultyInformation
        self.error = error
    }
    
    public var overallPercentage: Double {
        guard let pctString = totalInfo?.totalPercentage else { return 0.0 }
        let clean = pctString.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(clean) ?? 0.0
    }
    
    public var attendedCount: Int {
        totalInfo?.totalAttended ?? 0
    }
    
    public var heldCount: Int {
        totalInfo?.totalHeld ?? 0
    }
    
    public var displayName: String {
        if let name = studentName, !name.isEmpty { return name }
        if let roll = rollNumber, !roll.isEmpty { return roll }
        return "Student"
    }
    
    // MARK: - Attendance Calculations & Bunk Advice
    
    public func getBunkAdvice(targetThreshold: Double = 75.0) -> BunkAdvice {
        let percentage = overallPercentage
        let attended = attendedCount
        let held = heldCount
        let targetFactor = targetThreshold / 100.0
        
        let calculatedCanSkip: Int
        if held > 0 && percentage >= targetThreshold && targetFactor > 0 {
            let maxSkip = floor((Double(attended) - targetFactor * Double(held)) / targetFactor)
            calculatedCanSkip = max(0, Int(maxSkip))
        } else {
            calculatedCanSkip = 0
        }
        
        let periodsCanSkip = (targetThreshold == 75.0 && totalInfo?.hoursCanSkip != nil)
            ? (totalInfo?.hoursCanSkip ?? calculatedCanSkip)
            : calculatedCanSkip
        
        let calculatedNeedToAttend: Int
        let divisor = 1.0 - targetFactor
        if held > 0 && percentage < targetThreshold && divisor > 0.0 {
            let minAttend = ceil((targetFactor * Double(held) - Double(attended)) / divisor)
            calculatedNeedToAttend = max(0, Int(minAttend))
        } else {
            calculatedNeedToAttend = 0
        }
        
        let periodsNeedToAttend = (targetThreshold == 75.0 && totalInfo?.additionalHoursNeeded != nil)
            ? (totalInfo?.additionalHoursNeeded ?? calculatedNeedToAttend)
            : calculatedNeedToAttend
        
        let status: OverallAttendanceStatus
        let message: String
        let diff = percentage - targetThreshold
        let targetMargin = String(format: "%+.2f%% vs target", diff)
        
        if percentage >= targetThreshold {
            status = .safe
            if periodsCanSkip == 0 {
                message = "On track. Do not skip any upcoming classes."
            } else {
                message = "You can safely skip \(periodsCanSkip) upcoming \(periodsCanSkip == 1 ? "class" : "classes")."
            }
        } else {
            status = .critical
            message = "Attend next \(periodsNeedToAttend) consecutive \(periodsNeedToAttend == 1 ? "class" : "classes") to reach \(Int(targetThreshold))%."
        }
        
        return BunkAdvice(
            periodsCanSkip: periodsCanSkip,
            periodsNeedToAttend: periodsNeedToAttend,
            status: status,
            message: message,
            targetMargin: targetMargin
        )
    }
    
    // MARK: - Clean Table Extraction
    
    public func getCleanTable() -> CleanTable? {
        guard let table = attendanceTable,
              let rawHeaders = table.headers,
              let rawRows = table.rows,
              !rawHeaders.isEmpty, !rawRows.isEmpty else {
            return nil
        }
        
        let headers: [String]
        if !rawHeaders.isEmpty && rawHeaders[0].count > 100 {
            headers = Array(rawHeaders.dropFirst())
        } else {
            headers = rawHeaders
        }
        
        let rows = rawRows.filter { row in
            guard !row.isEmpty else { return false }
            let first = row.first?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            let second = row.count > 1 ? (row[1].trimmingCharacters(in: .whitespaces).lowercased()) : ""
            return first != "sl.no" && !first.isEmpty && second != "subject"
        }
        
        let percentIdx = headers.firstIndex { $0.trimmingCharacters(in: .whitespaces) == "%" }
        let finalHeaders: [String]
        let finalRows: [[String]]
        
        if let pIdx = percentIdx {
            finalHeaders = Array(headers.prefix(pIdx + 1))
            finalRows = rows.map { row in
                Array(row.prefix(pIdx + 1))
            }
        } else {
            finalHeaders = headers
            finalRows = rows
        }
        
        return CleanTable(headers: finalHeaders, rows: finalRows)
    }
    
    // MARK: - Today's Attendance Timeline
    
    private func isDateHeader(_ header: String) -> Bool {
        let clean = header.trimmingCharacters(in: .whitespaces).lowercased()
        if clean.isEmpty { return false }
        let nonDateKeywords = [
            "sl", "s.no", "no", "subject", "sub", "atted", "held", "att", "tot", "total",
            "%", "percent", "percentage", "cna", "ratio", "status", "action"
        ]
        if nonDateKeywords.contains(where: { clean.contains($0) }) { return false }
        
        let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let hasDigits = clean.contains { $0.isNumber }
        let hasMonth = monthNames.contains { clean.contains($0) }
        return hasDigits || hasMonth
    }
    
    public func getTodayColumnIndex(todayDate: Date = Date()) -> Int {
        guard let cleanTable = getCleanTable() else { return -1 }
        let headers = cleanTable.headers
        
        let calendar = Calendar.current
        let targetDay = calendar.component(.day, from: todayDate)
        let targetMonth = calendar.component(.month, from: todayDate)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "dd/MM"
        let todaySlash = formatter.string(from: todayDate)
        
        let matchedIndex = headers.firstIndex { header in
            guard isDateHeader(header) else { return false }
            let clean = header.trimmingCharacters(in: .whitespaces).lowercased()
            
            if clean.contains(todaySlash.lowercased()) {
                return true
            }
            
            let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
            if let foundMonthIdx = monthNames.firstIndex(where: { clean.contains($0) }) {
                let hMonth = foundMonthIdx + 1
                let digits = clean.filter { $0.isNumber }
                if let hDay = Int(digits), hDay == targetDay && hMonth == targetMonth {
                    return true
                }
            }
            
            let parts = clean.components(separatedBy: CharacterSet(charactersIn: "/- .")).compactMap { Int($0) }
            if parts.count >= 2 {
                let hDay = parts[0]
                let hMonth = parts[1]
                return hDay == targetDay && hMonth == targetMonth
            }
            return false
        }
        
        return matchedIndex ?? -1
    }
    
    public func getTodayAttendanceTimeline(todayDate: Date = Date()) -> [AttendanceStatus] {
        guard let cleanTable = getCleanTable() else { return [] }
        let rows = cleanTable.rows
        let columnIndex = getTodayColumnIndex(todayDate: todayDate)
        guard columnIndex >= 0 else { return [] }
        
        var timeline: [AttendanceStatus] = []
        for row in rows {
            if columnIndex < row.count {
                let cellStatus = row[columnIndex].trimmingCharacters(in: .whitespaces).uppercased()
                if !cellStatus.isEmpty && cellStatus != "-" && cellStatus != "0" {
                    for char in cellStatus {
                        if ["P", "A", "H", "L"].contains(char) {
                            timeline.append(AttendanceStatus.from(character: char))
                        }
                    }
                }
            }
        }
        
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US")
        dayFormatter.dateFormat = "EEEE"
        let dayName = dayFormatter.string(from: todayDate)
        
        if let dayTimetable = timetable?.first(where: { $0.day.caseInsensitiveCompare(dayName) == .orderedSame }),
           !dayTimetable.classes.isEmpty {
            let totalScheduled = dayTimetable.classes.count
            let currentMarked = timeline.count
            if totalScheduled > currentMarked {
                for _ in 0..<(totalScheduled - currentMarked) {
                    timeline.append(.upcoming)
                }
            }
        }
        
        return timeline
    }
    
    public func getTodaySummary(todayDate: Date = Date()) -> (present: Int, absent: Int, pending: Int, total: Int) {
        let timeline = getTodayAttendanceTimeline(todayDate: todayDate)
        let present = timeline.filter { $0 == .present }.count
        let absent = timeline.filter { $0 == .absent }.count
        let pending = timeline.filter { $0 == .upcoming }.count
        return (present, absent, pending, timeline.count)
    }
    
    // MARK: - Attendance Grid Day Extraction
    
    public func getLatestDateColumnIndex() -> Int {
        guard let cleanTable = getCleanTable() else { return -1 }
        let headers = cleanTable.headers
        for (index, header) in headers.enumerated().reversed() {
            if isDateHeader(header) {
                return index
            }
        }
        return -1
    }
    
    public func getLatestMarkedDateColumnIndex() -> Int {
        guard let cleanTable = getCleanTable() else { return -1 }
        let headers = cleanTable.headers
        for (index, header) in headers.enumerated().reversed() {
            guard isDateHeader(header) else { continue }
            let hasMark = cleanTable.rows.contains { row in
                if index < row.count {
                    let cell = row[index].trimmingCharacters(in: .whitespaces)
                    return !cell.isEmpty && cell != "-" && cell != "0"
                }
                return false
            }
            if hasMark {
                return index
            }
        }
        return getLatestDateColumnIndex()
    }
    
    public func getGridAttendance(forColumnIndex columnIndex: Int, isToday: Bool) -> GridDayAttendance? {
        guard let cleanTable = getCleanTable(), columnIndex >= 0, columnIndex < cleanTable.headers.count else {
            return nil
        }
        let dateHeader = cleanTable.headers[columnIndex]
        var records: [TodayGridSubjectRecord] = []
        var timeline: [AttendanceStatus] = []
        
        for row in cleanTable.rows {
            guard columnIndex < row.count else { continue }
            let cell = row[columnIndex].trimmingCharacters(in: .whitespaces)
            let subject = row.count > 1 ? row[1].trimmingCharacters(in: .whitespaces) : "Subject"
            
            if !cell.isEmpty && cell != "-" && cell != "0" {
                let status = AttendanceStatus.from(string: cell)
                records.append(TodayGridSubjectRecord(
                    subjectName: subject,
                    statusString: cell,
                    status: status
                ))
                for char in cell.uppercased() {
                    if ["P", "A", "H", "L"].contains(char) {
                        timeline.append(AttendanceStatus.from(character: char))
                    }
                }
            }
        }
        
        let present = timeline.filter { $0 == .present }.count
        let absent = timeline.filter { $0 == .absent }.count
        let other = timeline.filter { $0 != .present && $0 != .absent }.count
        
        return GridDayAttendance(
            dateHeader: dateHeader,
            isToday: isToday,
            records: records,
            timeline: timeline,
            presentCount: present,
            absentCount: absent,
            otherCount: other
        )
    }
    
    public func getTodayGridAttendance(todayDate: Date = Date()) -> GridDayAttendance {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "dd/MM"
        let dateString = formatter.string(from: todayDate)
        
        let todayIdx = getTodayColumnIndex(todayDate: todayDate)
        if todayIdx >= 0, let grid = getGridAttendance(forColumnIndex: todayIdx, isToday: true) {
            return grid
        }
        
        let timeline = getTodayAttendanceTimeline(todayDate: todayDate)
        let present = timeline.filter { $0 == .present }.count
        let absent = timeline.filter { $0 == .absent }.count
        let other = timeline.filter { $0 != .present && $0 != .absent && $0 != .upcoming }.count
        
        return GridDayAttendance(
            dateHeader: dateString,
            isToday: true,
            records: [],
            timeline: timeline,
            presentCount: present,
            absentCount: absent,
            otherCount: other
        )
    }
    
    public func getTodayOrLatestGridAttendance(todayDate: Date = Date()) -> GridDayAttendance? {
        return getTodayGridAttendance(todayDate: todayDate)
    }
    
    // MARK: - Simulation
    
    public func calculateSimulation(
        additionalLeaves: Int,
        additionalAttended: Int,
        targetThreshold: Double = 75.0
    ) -> SimulationResult {
        let curAttended = attendedCount
        let curHeld = heldCount
        let curPct = overallPercentage
        
        let simAttended = curAttended + additionalAttended
        let simHeld = curHeld + additionalLeaves + additionalAttended
        let simPct = simHeld > 0 ? (Double(simAttended) / Double(simHeld)) * 100.0 : curPct
        
        let targetFactor = targetThreshold / 100.0
        let origCanSkip = (curHeld > 0 && curPct >= targetThreshold && targetFactor > 0)
            ? max(0, Int(floor((Double(curAttended) - targetFactor * Double(curHeld)) / targetFactor)))
            : 0
        let simCanSkip = (simHeld > 0 && simPct >= targetThreshold && targetFactor > 0)
            ? max(0, Int(floor((Double(simAttended) - targetFactor * Double(simHeld)) / targetFactor)))
            : 0
            
        let divisor = 1.0 - targetFactor
        let origNeed = (curHeld > 0 && curPct < targetThreshold && divisor > 0)
            ? max(0, Int(ceil((targetFactor * Double(curHeld) - Double(curAttended)) / divisor)))
            : 0
        let simNeed = (simHeld > 0 && simPct < targetThreshold && divisor > 0)
            ? max(0, Int(ceil((targetFactor * Double(simHeld) - Double(simAttended)) / divisor)))
            : 0
            
        return SimulationResult(
            originalPercentage: curPct,
            simulatedPercentage: simPct,
            originalAttended: curAttended,
            simulatedAttended: simAttended,
            originalHeld: curHeld,
            simulatedHeld: simHeld,
            originalCanSkip: origCanSkip,
            simulatedCanSkip: simCanSkip,
            originalNeedToAttend: origNeed,
            simulatedNeedToAttend: simNeed,
            addedLeaves: additionalLeaves,
            addedAttends: additionalAttended
        )
    }
}

// MARK: - Total Info

public struct TotalInfo: Codable, Equatable {
    public let totalAttended: Int
    public let totalHeld: Int
    public let totalPercentage: String
    public let hoursCanSkip: Int?
    public let additionalHoursNeeded: Int?
    
    enum CodingKeys: String, CodingKey {
        case totalAttended = "total_attended"
        case totalHeld = "total_held"
        case totalPercentage = "total_percentage"
        case hoursCanSkip = "hours_can_skip"
        case additionalHoursNeeded = "additional_hours_needed"
    }
}

// MARK: - Subject Summary

public struct SubjectSummary: Codable, Identifiable, Equatable {
    public var id: String { subjectName }
    public let subjectName: String
    public let attended: Int
    public let held: Int
    public let percentage: String
    public let hoursCanSkip: Int?
    public let hoursNeeded: Int?
    
    enum CodingKeys: String, CodingKey {
        case subjectName = "subject_name"
        case attended
        case held
        case percentage
        case hoursCanSkip = "hours_can_skip"
        case hoursNeeded = "hours_needed"
    }
    
    public var percentageDouble: Double {
        let clean = percentage.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        return Double(clean) ?? 0.0
    }
    
    public func calculateAdvice(targetThreshold: Double = 75.0) -> (canSkip: Int, needAttend: Int) {
        let pct = percentageDouble
        let targetFactor = targetThreshold / 100.0
        
        let canSkip: Int
        if held > 0 && pct >= targetThreshold && targetFactor > 0 {
            let maxSkip = floor((Double(attended) - targetFactor * Double(held)) / targetFactor)
            canSkip = max(0, Int(maxSkip))
        } else {
            canSkip = 0
        }
        
        let needAttend: Int
        let divisor = 1.0 - targetFactor
        if held > 0 && pct < targetThreshold && divisor > 0.0 {
            let minAttend = ceil((targetFactor * Double(held) - Double(attended)) / divisor)
            needAttend = max(0, Int(minAttend))
        } else {
            needAttend = 0
        }
        
        let finalSkip = (targetThreshold == 75.0 && hoursCanSkip != nil) ? (hoursCanSkip ?? canSkip) : canSkip
        let finalNeed = (targetThreshold == 75.0 && hoursNeeded != nil) ? (hoursNeeded ?? needAttend) : needAttend
        return (finalSkip, finalNeed)
    }
}

// MARK: - Attendance Table

public struct AttendanceTable: Codable, Equatable {
    public let headers: [String]?
    public let rows: [[String]]?
}

// MARK: - Timetable Day & Class

public struct TimetableDay: Codable, Identifiable, Equatable {
    public var id: String { day }
    public let day: String
    public let classes: [TimetableClass]
}

public struct TimetableClass: Codable, Identifiable, Equatable {
    public var id: String { "\(subject)-\(time)" }
    public let subject: String
    public let time: String
    public let room: String?
    public let faculty: String?
    
    public var isOngoing: Bool {
        let parts = time.components(separatedBy: "-")
        guard parts.count == 2 else { return false }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "hh:mm a"
        
        guard let start = formatter.date(from: parts[0].trimmingCharacters(in: .whitespaces)),
              let end = formatter.date(from: parts[1].trimmingCharacters(in: .whitespaces)) else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        let nowH = calendar.component(.hour, from: now)
        let nowM = calendar.component(.minute, from: now)
        let currentMinutes = nowH * 60 + nowM
        
        let startH = calendar.component(.hour, from: start)
        let startM = calendar.component(.minute, from: start)
        let startMinutes = startH * 60 + startM
        
        let endH = calendar.component(.hour, from: end)
        let endM = calendar.component(.minute, from: end)
        let endMinutes = endH * 60 + endM
        
        return currentMinutes >= startMinutes && currentMinutes <= endMinutes
    }
}

// MARK: - Faculty Info

public struct FacultyInfo: Codable, Identifiable, Equatable {
    public var id: String { "\(name)-\(subject ?? "")" }
    public let name: String
    public let subject: String?
    public let email: String?
    public let phone: String?
}

// MARK: - Supporting Clean Table & Calculation Structs

public struct CleanTable: Equatable {
    public let headers: [String]
    public let rows: [[String]]
}

public struct BunkAdvice: Equatable {
    public let periodsCanSkip: Int
    public let periodsNeedToAttend: Int
    public let status: OverallAttendanceStatus
    public let message: String
    public let targetMargin: String
}

public struct SimulationResult: Equatable {
    public let originalPercentage: Double
    public let simulatedPercentage: Double
    public let originalAttended: Int
    public let simulatedAttended: Int
    public let originalHeld: Int
    public let simulatedHeld: Int
    public let originalCanSkip: Int
    public let simulatedCanSkip: Int
    public let originalNeedToAttend: Int
    public let simulatedNeedToAttend: Int
    public let addedLeaves: Int
    public let addedAttends: Int
}

public struct TodayGridSubjectRecord: Identifiable, Equatable {
    public var id: String { "\(subjectName)-\(statusString)" }
    public let subjectName: String
    public let statusString: String
    public let status: AttendanceStatus
    
    public init(subjectName: String, statusString: String, status: AttendanceStatus) {
        self.subjectName = subjectName
        self.statusString = statusString
        self.status = status
    }
}

public struct GridDayAttendance: Equatable {
    public let dateHeader: String
    public let isToday: Bool
    public let records: [TodayGridSubjectRecord]
    public let timeline: [AttendanceStatus]
    public let presentCount: Int
    public let absentCount: Int
    public let otherCount: Int
    
    public init(
        dateHeader: String,
        isToday: Bool,
        records: [TodayGridSubjectRecord],
        timeline: [AttendanceStatus],
        presentCount: Int,
        absentCount: Int,
        otherCount: Int
    ) {
        self.dateHeader = dateHeader
        self.isToday = isToday
        self.records = records
        self.timeline = timeline
        self.presentCount = presentCount
        self.absentCount = absentCount
        self.otherCount = otherCount
    }
}

