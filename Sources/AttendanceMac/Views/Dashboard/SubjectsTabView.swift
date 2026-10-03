import SwiftUI

public struct SubjectsTabView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    public enum SubjectFilter: String, CaseIterable {
        case all = "All"
        case safe = "Safe"
        case atRisk = "At Risk"
    }
    
    @State private var filterMode: SubjectFilter = .all
    
    private var allSubjects: [SubjectSummary] {
        viewModel.attendance?.subjectwiseSummary ?? []
    }
    
    private var filteredSubjects: [SubjectSummary] {
        var list = allSubjects
        
        // Text filter
        let query = viewModel.subjectsSearchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            list = list.filter { $0.subjectName.localizedCaseInsensitiveContains(query) }
        }
        
        // Status filter
        switch filterMode {
        case .all:
            break
        case .safe:
            list = list.filter { $0.percentageDouble >= viewModel.targetThreshold }
        case .atRisk:
            list = list.filter { $0.percentageDouble < viewModel.targetThreshold }
        }
        
        return list
    }
    
    private var safeCount: Int {
        allSubjects.filter { $0.percentageDouble >= viewModel.targetThreshold }.count
    }
    
    private var atRiskCount: Int {
        allSubjects.filter { $0.percentageDouble < viewModel.targetThreshold }.count
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Filter Bar & Search Header
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        
                        TextField("Filter subjects by name or code...", text: $viewModel.subjectsSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        
                        if !viewModel.subjectsSearchText.isEmpty {
                            Button {
                                viewModel.subjectsSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    
                    if !viewModel.subjectSimDeltas.isEmpty {
                        Button {
                            viewModel.subjectSimDeltas.removeAll()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset (\(viewModel.subjectSimDeltas.count))")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Reset all interactive simulated classes")
                    }
                }
                
                // Status Filter Chips
                HStack(spacing: 8) {
                    filterChip(.all, label: "All Subjects", count: allSubjects.count)
                    filterChip(.safe, label: "Safe (≥\(Int(viewModel.targetThreshold))%)", count: safeCount, color: AttendanceColors.safe)
                    filterChip(.atRisk, label: "At Risk (<\(Int(viewModel.targetThreshold))%)", count: atRiskCount, color: AttendanceColors.critical)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
                .opacity(0.6)
            
            // Subjects List
            ScrollView(.vertical, showsIndicators: true) {
                if filteredSubjects.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 38))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(allSubjects.isEmpty ? "No subject attendance records found" : "No subjects match your current filter")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSubjects) { subject in
                            subjectCard(subject)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    @ViewBuilder
    private func filterChip(_ mode: SubjectFilter, label: String, count: Int, color: Color? = nil) -> some View {
        let isSelected = filterMode == mode
        Button {
            filterMode = mode
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? (color ?? AttendanceColors.accent) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.10), lineWidth: 1)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func subjectCard(_ subject: SubjectSummary) -> some View {
        let delta = viewModel.subjectSimDeltas[subject.subjectName] ?? 0
        let baseAttended = subject.attended
        let baseHeld = subject.held
        
        let simAttended = delta > 0 ? baseAttended + delta : baseAttended
        let simHeld = baseHeld + abs(delta)
        let simPct = simHeld > 0 ? (Double(simAttended) / Double(simHeld)) * 100.0 : subject.percentageDouble
        let isSafe = simPct >= viewModel.targetThreshold
        let (canSkip, needAttend) = subject.calculateAdvice(targetThreshold: viewModel.targetThreshold)
        let statusColor = isSafe ? AttendanceColors.safe : AttendanceColors.critical
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.subjectName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("\(simAttended) Attended • \(simHeld) Total Held")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", simPct))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                    
                    if delta != 0 {
                        Text(delta > 0 ? "+\(delta) simulated attended" : "\(delta) simulated missed")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(delta > 0 ? AttendanceColors.safe : AttendanceColors.warning)
                    }
                }
            }
            
            // Progress Bar with Target Goal Flag
            GeometryReader { geo in
                let width = geo.size.width
                let progressWidth = max(0, min(width * CGFloat(simPct / 100.0), width))
                let thresholdX = max(0, min(width * CGFloat(viewModel.targetThreshold / 100.0), width))
                
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 8)
                    
                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isSafe ? [AttendanceColors.safe, Color(red: 0.15, green: 0.88, blue: 0.55)] : [AttendanceColors.critical, Color(red: 1.0, green: 0.45, blue: 0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth, height: 8)
                    
                    // Threshold target marker line & diamond
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 2, height: 12)
                    }
                    .position(x: thresholdX, y: 4)
                    .help("Target Goal: \(Int(viewModel.targetThreshold))%")
                }
            }
            .frame(height: 12)
            
            HStack {
                // Advice badge
                if isSafe {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                        Text(canSkip == 0 ? "Exact on track" : "Can miss \(canSkip) classes")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(AttendanceColors.safe)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AttendanceColors.safe.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text("Must attend \(needAttend) classes")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(AttendanceColors.critical)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AttendanceColors.critical.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Quick Simulator Stepper
                HStack(spacing: 6) {
                    Text("Simulate:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button {
                        viewModel.subjectSimDeltas[subject.subjectName] = delta - 1
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Simulate missing this class (-1)")
                    
                    Text(delta == 0 ? "0" : (delta > 0 ? "+\(delta)" : "\(delta)"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(delta == 0 ? .primary : (delta > 0 ? AttendanceColors.safe : AttendanceColors.warning))
                        .frame(minWidth: 26)
                    
                    Button {
                        viewModel.subjectSimDeltas[subject.subjectName] = delta + 1
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Simulate attending this class (+1)")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(8)
            }
        }
        .attendanceCard(cornerRadius: 14, padding: 16)
    }
}
