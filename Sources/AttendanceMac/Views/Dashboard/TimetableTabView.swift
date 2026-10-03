import SwiftUI

public struct TimetableTabView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @State private var facultySearchQuery: String = ""
    @State private var copiedFacultyId: String? = nil
    
    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    
    private var todayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
    
    private var currentDay: String {
        if viewModel.timetableSelectedDay.isEmpty {
            return days.contains(todayName) ? todayName : "Monday"
        }
        return viewModel.timetableSelectedDay
    }
    
    private var selectedClasses: [TimetableClass] {
        guard let list = viewModel.attendance?.timetable else { return [] }
        let dayData = list.first { $0.day.caseInsensitiveCompare(currentDay) == .orderedSame }
        return dayData?.classes ?? []
    }
    
    private var faculties: [FacultyInfo] {
        let all = viewModel.attendance?.facultyInformation ?? []
        let query = facultySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return all
        }
        return all.filter {
            $0.name.lowercased().contains(query) ||
            ($0.subject?.lowercased().contains(query) ?? false) ||
            ($0.email?.lowercased().contains(query) ?? false) ||
            ($0.phone?.contains(query) ?? false)
        }
    }
    
    private func classCountForDay(_ day: String) -> Int {
        guard let list = viewModel.attendance?.timetable else { return 0 }
        let dayData = list.first { $0.day.caseInsensitiveCompare(day) == .orderedSame }
        return dayData?.classes.count ?? 0
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Day selector tabs
            daySelectorBar
            
            Divider()
                .opacity(0.5)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Day Summary Card
                    daySummaryBanner
                    
                    // Scheduled Classes Section
                    classesSection
                    
                    // Faculty Directory Section
                    facultyDirectorySection
                }
                .padding(22)
            }
        }
        .onAppear {
            if viewModel.timetableSelectedDay.isEmpty {
                viewModel.timetableSelectedDay = days.contains(todayName) ? todayName : "Monday"
            }
        }
    }
    
    // MARK: - Day Selector Bar
    
    private var daySelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let isSelected = day == currentDay
                    let isToday = day == todayName
                    let count = classCountForDay(day)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.timetableSelectedDay = day
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(day.prefix(3).uppercased())
                                .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                            
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                                    )
                            }
                            
                            if isToday {
                                Circle()
                                    .fill(isSelected ? Color.white : AttendanceColors.accent)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? AttendanceColors.accent : Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    }
    
    // MARK: - Day Summary Banner
    
    private var daySummaryBanner: some View {
        let isToday = currentDay == todayName
        let hasOngoing = isToday && selectedClasses.contains(where: { $0.isOngoing })
        
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(currentDay)'s Schedule")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    
                    if isToday {
                        Text("TODAY")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AttendanceColors.accent))
                            .foregroundColor(.white)
                    }
                    
                    if hasOngoing {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AttendanceColors.critical)
                                .frame(width: 6, height: 6)
                            Text("CLASS IN SESSION")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(AttendanceColors.critical)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AttendanceColors.critical.opacity(0.12)))
                    }
                }
                
                Text(selectedClasses.isEmpty ? "No scheduled lectures or labs" : "\(selectedClasses.count) period\(selectedClasses.count == 1 ? "" : "s") planned")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !selectedClasses.isEmpty, let first = selectedClasses.first, let last = selectedClasses.last {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SPAN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(first.time.components(separatedBy: "-").first?.trimmingCharacters(in: .whitespaces) ?? "") → \(last.time.components(separatedBy: "-").last?.trimmingCharacters(in: .whitespaces) ?? "")")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
        .attendanceCard(cornerRadius: 14, padding: 14)
    }
    
    // MARK: - Scheduled Classes Section
    
    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Periods & Timeline")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
            
            if selectedClasses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange.opacity(0.8))
                    
                    VStack(spacing: 3) {
                        Text("No Classes Scheduled")
                            .font(.system(size: 14, weight: .bold))
                        Text("There are no lectures or labs listed for \(currentDay). Enjoy your free time or use it for independent study!")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .attendanceCard(cornerRadius: 14, padding: 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(selectedClasses.enumerated()), id: \.element.id) { index, cls in
                        classCard(cls, periodNumber: index + 1)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func classCard(_ cls: TimetableClass, periodNumber: Int) -> some View {
        let isToday = currentDay == todayName
        let isOngoing = isToday && cls.isOngoing
        
        HStack(spacing: 0) {
            // Left color accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(isOngoing ? AttendanceColors.critical : AttendanceColors.accent)
                .frame(width: 4)
                .padding(.vertical, 6)
            
            HStack(alignment: .center, spacing: 16) {
                // Period Badge & Time
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("P\(periodNumber)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isOngoing ? AttendanceColors.critical.opacity(0.15) : AttendanceColors.accent.opacity(0.12))
                            )
                            .foregroundColor(isOngoing ? AttendanceColors.critical : AttendanceColors.accent)
                        
                        if isOngoing {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AttendanceColors.critical))
                        }
                    }
                    
                    Text(cls.time)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(isOngoing ? AttendanceColors.critical : .secondary)
                }
                .frame(width: 140, alignment: .leading)
                
                // Subject and Faculty Details
                VStack(alignment: .leading, spacing: 5) {
                    Text(cls.subject)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        if let faculty = cls.faculty, !faculty.isEmpty {
                            Label(faculty, systemImage: "person.crop.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        if let room = cls.room, !room.isEmpty {
                            Label(room, systemImage: "door.left.hand.open")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .attendanceCard(
            cornerRadius: 12,
            padding: 0,
            borderColor: isOngoing ? AttendanceColors.critical.opacity(0.4) : nil,
            borderWidth: isOngoing ? 1.5 : 1
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOngoing ? AttendanceColors.critical.opacity(0.04) : Color.clear)
        )
    }
    
    // MARK: - Faculty Directory Section
    
    private var facultyDirectorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .padding(.vertical, 6)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Faculty Directory")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Contact details for professors and instructors")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    TextField("Search faculty or subject...", text: $facultySearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                    
                    if !facultySearchQuery.isEmpty {
                        Button {
                            facultySearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 220)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            
            if faculties.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(facultySearchQuery.isEmpty ? "No faculty records available" : "No faculty found matching \"\(facultySearchQuery)\"")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .attendanceCard(cornerRadius: 12, padding: 16)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    ForEach(faculties) { faculty in
                        facultyCard(faculty)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func facultyCard(_ faculty: FacultyInfo) -> some View {
        let isCopied = copiedFacultyId == faculty.id
        let initials = faculty.name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map { String($0) }
            .joined()
            .uppercased()
        
        HStack(spacing: 12) {
            // Avatar with initials
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AttendanceColors.accent.opacity(0.85), AttendanceColors.purple.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 38, height: 38)
                
                Text(initials.isEmpty ? "F" : initials)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(faculty.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let sub = faculty.subject, !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if isCopied {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Copied!")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AttendanceColors.safe)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AttendanceColors.safe.opacity(0.12)))
                    .transition(.opacity)
                }
                
                if let email = faculty.email, !email.isEmpty {
                    Button {
                        if let url = URL(string: "mailto:\(email)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AttendanceColors.accent)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(AttendanceColors.accent.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Send email to \(email)")
                }
                
                if let phone = faculty.phone, !phone.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(phone, forType: .string)
                        withAnimation {
                            copiedFacultyId = faculty.id
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                if copiedFacultyId == faculty.id {
                                    copiedFacultyId = nil
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AttendanceColors.safe)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(AttendanceColors.safe.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Copy phone number: \(phone)")
                }
            }
        }
        .attendanceCard(cornerRadius: 12, padding: 12)
    }
}
