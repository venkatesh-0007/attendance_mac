import SwiftUI

public struct BunkSimulatorTabView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                if let attendance = viewModel.attendance {
                    let sim = attendance.calculateSimulation(
                        additionalLeaves: viewModel.simulatorExtraLeaves,
                        additionalAttended: viewModel.simulatorExtraAttended,
                        targetThreshold: viewModel.targetThreshold
                    )
                    
                    let isSimSafe = sim.simulatedPercentage >= viewModel.targetThreshold
                    
                    // Intro Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Interactive Bunk & Recovery Playground")
                                .font(.system(size: 16, weight: .bold))
                            Text("Simulate future class attendance and plan your schedule to maintain safe standing.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.simulatorExtraLeaves > 0 || viewModel.simulatorExtraAttended > 0 {
                            Button {
                                viewModel.simulatorExtraLeaves = 0
                                viewModel.simulatorExtraAttended = 0
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset Simulation")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // Comparison Cards
                    HStack(spacing: 16) {
                        // Current Standing
                        VStack(spacing: 12) {
                            Text("CURRENT STANDING")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.8)
                            
                            CircularProgressGauge(
                                percentage: sim.originalPercentage,
                                threshold: viewModel.targetThreshold,
                                size: 104,
                                strokeWidth: 10
                            )
                            
                            VStack(spacing: 3) {
                                Text("\(sim.originalAttended) / \(sim.originalHeld) Classes")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                
                                if sim.originalCanSkip > 0 {
                                    Text("Buffer: \(sim.originalCanSkip) classes safe to skip")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AttendanceColors.safe)
                                } else {
                                    Text("Deficit: Must attend \(sim.originalNeedToAttend) classes")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AttendanceColors.critical)
                                }
                            }
                        }
                        .attendanceCard(cornerRadius: 14, padding: 18)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AttendanceColors.accent)
                        
                        // Projected Standing
                        VStack(spacing: 12) {
                            Text("PROJECTED STANDING")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isSimSafe ? AttendanceColors.safe : AttendanceColors.critical)
                                .tracking(0.8)
                            
                            CircularProgressGauge(
                                percentage: sim.simulatedPercentage,
                                threshold: viewModel.targetThreshold,
                                size: 104,
                                strokeWidth: 10
                            )
                            
                            VStack(spacing: 3) {
                                Text("\(sim.simulatedAttended) / \(sim.simulatedHeld) Classes")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                
                                let diff = sim.simulatedPercentage - sim.originalPercentage
                                HStack(spacing: 4) {
                                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    Text(String(format: "%+.2f%% Overall Change", diff))
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(diff >= 0 ? AttendanceColors.safe : AttendanceColors.critical)
                            }
                        }
                        .attendanceCard(
                            cornerRadius: 14,
                            padding: 18,
                            borderColor: (isSimSafe ? AttendanceColors.safe : AttendanceColors.critical).opacity(0.3),
                            borderWidth: 1.5
                        )
                    }
                    
                    // Quick Presets
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Simulation Presets")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            presetButton(title: "Skip 1 Class", leaves: 1, attend: 0, color: AttendanceColors.warning)
                            presetButton(title: "Bunk Full Day (7 classes)", leaves: 7, attend: 0, color: AttendanceColors.critical)
                            presetButton(title: "Attend Next 5", leaves: 0, attend: 5, color: AttendanceColors.safe)
                            presetButton(title: "Attend Next 10", leaves: 0, attend: 10, color: AttendanceColors.accent)
                        }
                    }
                    
                    // Interactive Controls
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Manual Adjustment Controls")
                            .font(.system(size: 13, weight: .bold))
                        
                        HStack(spacing: 16) {
                            // Skip Stepper
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Skip Upcoming Classes", systemImage: "minus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AttendanceColors.warning)
                                
                                HStack {
                                    Button {
                                        if viewModel.simulatorExtraLeaves > 0 {
                                            viewModel.simulatorExtraLeaves -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 26, height: 26)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.simulatorExtraLeaves <= 0)
                                    
                                    Text("\(viewModel.simulatorExtraLeaves) missed")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .frame(minWidth: 90, alignment: .center)
                                    
                                    Button {
                                        viewModel.simulatorExtraLeaves += 1
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 26, height: 26)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(12)
                            
                            // Attend Stepper
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Attend Extra Classes", systemImage: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AttendanceColors.safe)
                                
                                HStack {
                                    Button {
                                        if viewModel.simulatorExtraAttended > 0 {
                                            viewModel.simulatorExtraAttended -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 26, height: 26)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.simulatorExtraAttended <= 0)
                                    
                                    Text("\(viewModel.simulatorExtraAttended) attended")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .frame(minWidth: 90, alignment: .center)
                                    
                                    Button {
                                        viewModel.simulatorExtraAttended += 1
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .bold))
                                            .frame(width: 26, height: 26)
                                            .background(Color.secondary.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.02))
                            .cornerRadius(12)
                        }
                    }
                    .attendanceCard(cornerRadius: 14, padding: 16)
                    
                    // Target Goal Recovery Matrix
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Target Goal Recovery Calculator", systemImage: "target")
                            .font(.system(size: 13, weight: .bold))
                        
                        Text("Calculate exactly how many consecutive classes you need to attend or can afford to miss for each benchmark.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        let goals = [75.0, 80.0, 85.0, 90.0]
                        VStack(spacing: 8) {
                            ForEach(goals, id: \.self) { goal in
                                recoveryRow(goal: goal, attended: attendance.attendedCount, held: attendance.heldCount)
                            }
                        }
                    }
                    .attendanceCard(cornerRadius: 14, padding: 16)
                }
            }
            .padding(20)
        }
    }
    
    @ViewBuilder
    private func presetButton(title: String, leaves: Int, attend: Int, color: Color) -> some View {
        Button {
            viewModel.simulatorExtraLeaves = leaves
            viewModel.simulatorExtraAttended = attend
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.12))
                .foregroundColor(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func recoveryRow(goal: Double, attended: Int, held: Int) -> some View {
        let currentPct = held > 0 ? (Double(attended) / Double(held)) * 100.0 : 0.0
        let isAbove = currentPct >= goal
        
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(isAbove ? AttendanceColors.safe : AttendanceColors.warning)
                    .frame(width: 8, height: 8)
                Text("\(Int(goal))% Target Goal")
                    .font(.system(size: 12, weight: .bold))
            }
            
            Spacer()
            
            if isAbove {
                let canSkip = Int(floor((100.0 * Double(attended) - goal * Double(held)) / goal))
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text(canSkip == 0 ? "Exact on target" : "Can miss \(canSkip) classes safely")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(AttendanceColors.safe)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AttendanceColors.safe.opacity(0.10))
                .clipShape(Capsule())
            } else {
                let needed = Int(ceil((goal * Double(held) - 100.0 * Double(attended)) / (100.0 - goal)))
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("Must attend next \(max(1, needed)) classes")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(AttendanceColors.critical)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AttendanceColors.critical.opacity(0.10))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(8)
    }
}

