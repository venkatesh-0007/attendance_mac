import SwiftUI

public struct OverviewTabView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    @State private var isLivePulsing = false
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                if let attendance = viewModel.attendance {
                    let advice = attendance.getBunkAdvice(targetThreshold: viewModel.targetThreshold)
                    let isSafe = advice.status == .safe
                    let statusColor = isSafe ? AttendanceColors.safe : AttendanceColors.critical
                    
                    // 1. Status Banner
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: advice.status.iconName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(statusColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isSafe ? "Good Standing" : "Attendance Warning")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(advice.message)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(advice.targetMargin)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(statusColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(statusColor.opacity(0.12))
                                .clipShape(Capsule())
                            
                            Text("Target: \(Int(viewModel.targetThreshold))%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill((isSafe ? Color.green : Color.red).opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(statusColor.opacity(0.25), lineWidth: 1)
                    )
                    
                    // 2. Large Gauge + Summary Metrics
                    HStack(alignment: .center, spacing: 24) {
                        CircularProgressGauge(
                            percentage: attendance.overallPercentage,
                            threshold: viewModel.targetThreshold,
                            size: 135,
                            strokeWidth: 14
                        )
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                MetricCard(
                                    title: "Classes Attended",
                                    value: "\(attendance.attendedCount)",
                                    subtitle: "of \(attendance.heldCount) total held",
                                    iconName: "checkmark.circle.fill",
                                    accentColor: AttendanceColors.safe
                                )
                                
                                MetricCard(
                                    title: "Total Held",
                                    value: "\(attendance.heldCount)",
                                    subtitle: "completed periods",
                                    iconName: "clock.arrow.circlepath",
                                    accentColor: AttendanceColors.accent
                                )
                            }
                            
                            HStack(spacing: 12) {
                                if isSafe {
                                    MetricCard(
                                        title: "Periods Can Skip",
                                        value: "\(advice.periodsCanSkip)",
                                        subtitle: "buffer above \(Int(viewModel.targetThreshold))%",
                                        iconName: "arrow.down.right.and.arrow.up.left",
                                        accentColor: AttendanceColors.accent
                                    )
                                } else {
                                    MetricCard(
                                        title: "Periods Needed",
                                        value: "\(advice.periodsNeedToAttend)",
                                        subtitle: "to reach target \(Int(viewModel.targetThreshold))%",
                                        iconName: "exclamationmark.triangle.fill",
                                        accentColor: AttendanceColors.critical
                                    )
                                }
                                
                                MetricCard(
                                    title: "Target Goal",
                                    value: String(format: "%.0f%%", viewModel.targetThreshold),
                                    subtitle: "minimum threshold",
                                    iconName: "target",
                                    accentColor: AttendanceColors.warning
                                )
                            }
                        }
                    }
                    .attendanceCard(cornerRadius: 16, padding: 18)
                    
                    // 3. Today's Period Status
                    VStack(alignment: .leading, spacing: 14) {
                        let timeline = viewModel.todayTimeline
                        let summary = attendance.getTodaySummary()
                        
                        HStack {
                            Label("Today's Attendance Register", systemImage: "checklist")
                                .font(.system(size: 14, weight: .bold))
                            
                            Spacer()
                            
                            if timeline.isEmpty {
                                Text("No periods marked for today yet")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            } else {
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Circle().fill(AttendanceColors.safe).frame(width: 6, height: 6)
                                        Text("\(summary.present) Present")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(AttendanceColors.safe.opacity(0.12))
                                    .clipShape(Capsule())
                                    
                                    HStack(spacing: 4) {
                                        Circle().fill(AttendanceColors.critical).frame(width: 6, height: 6)
                                        Text("\(summary.absent) Absent")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(AttendanceColors.critical.opacity(0.12))
                                    .clipShape(Capsule())
                                    
                                    if summary.pending > 0 {
                                        Text("\(summary.pending) Upcoming")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        if !timeline.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(Array(timeline.enumerated()), id: \.offset) { index, status in
                                    PeriodCircle(number: index + 1, status: status)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .attendanceCard(cornerRadius: 14, padding: 16)
                    
                    // 4. Today's Schedule
                    let todayClasses = viewModel.todayClasses
                    if !todayClasses.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Today's Class Schedule", systemImage: "calendar.badge.clock")
                                    .font(.system(size: 14, weight: .bold))
                                
                                Spacer()
                                
                                Text("\(todayClasses.count) Classes")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(todayClasses) { cls in
                                    HStack(spacing: 14) {
                                        if cls.isOngoing {
                                            HStack(spacing: 5) {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 7, height: 7)
                                                    .scaleEffect(isLivePulsing ? 1.3 : 1.0)
                                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLivePulsing)
                                                Text("LIVE")
                                                    .font(.system(size: 10, weight: .heavy))
                                                    .foregroundColor(.red)
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(Color.red.opacity(0.12))
                                            .clipShape(Capsule())
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(cls.subject)
                                                .font(.system(size: 13, weight: .semibold))
                                            
                                            HStack(spacing: 8) {
                                                if let faculty = cls.faculty {
                                                    Label(faculty, systemImage: "person.fill")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                                if let room = cls.room {
                                                    Text("• Room \(room)")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text(cls.time)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(cls.isOngoing ? .red : AttendanceColors.accent)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 4)
                                            .background((cls.isOngoing ? Color.red : AttendanceColors.accent).opacity(0.10))
                                            .clipShape(Capsule())
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(cls.isOngoing ? Color.red.opacity(0.06) : Color.primary.opacity(0.02))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(cls.isOngoing ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .attendanceCard(cornerRadius: 14, padding: 16)
                        .onAppear {
                            isLivePulsing = true
                        }
                    }
                } else {
                    ProgressView("Loading attendance...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(20)
        }
    }
}
