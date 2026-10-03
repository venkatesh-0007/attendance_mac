import SwiftUI

public struct MenuBarLabelView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @State private var dashPhase: CGFloat = 0
    
    private var isRefreshing: Bool {
        viewModel.isRefreshing || viewModel.isLoading
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if viewModel.isLoggedIn, let attendance = viewModel.attendance {
                Text(String(format: "%.1f%%", attendance.overallPercentage))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        Capsule()
                            .stroke(
                                viewModel.overallStatus.color,
                                style: StrokeStyle(
                                    lineWidth: 1.2,
                                    lineCap: .round,
                                    dash: isRefreshing ? [2.5, 2.5] : [],
                                    dashPhase: dashPhase
                                )
                            )
                    )
                    .onAppear {
                        if isRefreshing {
                            withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                                dashPhase = 10
                            }
                        }
                    }
                    .onChange(of: isRefreshing) { refreshing in
                        if refreshing {
                            withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                                dashPhase = 10
                            }
                        } else {
                            dashPhase = 0
                        }
                    }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Attendance")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    Capsule()
                        .stroke(
                            Color.secondary.opacity(0.8),
                            style: StrokeStyle(
                                lineWidth: 1.2,
                                dash: isRefreshing ? [2.5, 2.5] : []
                            )
                        )
                )
            }
        }
    }
}
