import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    public init(viewModel: AttendanceViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            // Background subtle gradient
            LinearGradient(
                colors: [AttendanceColors.accent.opacity(0.06), AttendanceColors.purple.opacity(0.04), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Branding Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AttendanceColors.blueGradient)
                            .frame(width: 68, height: 68)
                            .shadow(color: AttendanceColors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                        
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 4) {
                        Text("College Attendance")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        
                        Text("Native macOS Menu Bar & Dashboard Monitor")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Login Card
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Student ID / Roll Number")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("e.g. 21B01A0501", text: $viewModel.loginStudentId)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        SecureField("Portal Password", text: $viewModel.loginPassword)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profile Alias (Optional)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("e.g. Personal Account", text: $viewModel.loginCustomName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    
                    if let error = viewModel.errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(AttendanceColors.critical)
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundColor(AttendanceColors.critical)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button {
                        Task {
                            _ = await viewModel.login(
                                studentId: viewModel.loginStudentId,
                                password: viewModel.loginPassword,
                                customName: viewModel.loginCustomName.isEmpty ? nil : viewModel.loginCustomName
                            )
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.isLoading ? "Authenticating..." : "Sign In & Connect")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isLoading || viewModel.loginStudentId.isEmpty || viewModel.loginPassword.isEmpty)
                }
                .attendanceCard(cornerRadius: 16, padding: 24)
                .frame(width: 380)
                .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: 8)
                
                // Security note
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AttendanceColors.safe)
                    Text("Credentials stored securely in macOS Keychain")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(40)
        }
    }
}
