import SwiftUI

public struct AttendanceGridTabView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    @State private var gridSearchText = ""
    
    private var cleanTable: CleanTable? {
        viewModel.attendance?.getCleanTable()
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if let table = cleanTable, !table.rows.isEmpty {
                let headers = table.headers
                let subjectHeader = headers.count > 1 ? headers[1] : "Subject"
                let dataHeaders = headers.count > 2 ? Array(headers.dropFirst(2)) : []
                
                // Filter rows by search
                let filteredRows = table.rows.filter { row in
                    let subjectName = row.count > 1 ? row[1] : ""
                    if gridSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        return true
                    }
                    return subjectName.localizedCaseInsensitiveContains(gridSearchText)
                }
                
                // Top Control Bar: Search & Status Legend
                HStack(spacing: 16) {
                    // Search box
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("Find subject...", text: $gridSearchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !gridSearchText.isEmpty {
                            Button {
                                gridSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
                    .cornerRadius(6)
                    .frame(maxWidth: 180)
                    
                    Divider()
                        .frame(height: 16)
                    
                    // Legend
                    HStack(spacing: 12) {
                        legendItem(title: "Present", code: "P", color: AttendanceColors.safe)
                        legendItem(title: "Absent", code: "A", color: AttendanceColors.critical)
                        legendItem(title: "Holiday", code: "H", color: AttendanceColors.cyan)
                        legendItem(title: "Leave", code: "L", color: AttendanceColors.purple)
                    }
                    
                    Spacer()
                    
                    Text("\(filteredRows.count) of \(table.rows.count) Subjects")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                    .opacity(0.6)
                
                // Frozen Column Register Table
                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // 1. Frozen Subject Column
                        VStack(alignment: .leading, spacing: 0) {
                            // Pinned Header
                            HStack {
                                Text(subjectHeader)
                                    .font(.system(size: 12, weight: .bold))
                                Spacer()
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .frame(width: 190, height: 40)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .border(Color.secondary.opacity(0.12), width: 0.5)
                            
                            // Pinned Rows
                            ForEach(Array(filteredRows.enumerated()), id: \.offset) { rowIndex, row in
                                let subjectName = row.count > 1 ? row[1] : ""
                                HStack {
                                    Text(subjectName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .frame(width: 190, height: 44)
                                .background(rowIndex % 2 == 0 ? Color(nsColor: .controlBackgroundColor).opacity(0.4) : Color.primary.opacity(0.02))
                                .border(Color.secondary.opacity(0.10), width: 0.5)
                            }
                        }
                        .frame(width: 190)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 2, y: 0)
                        .zIndex(2)
                        
                        // 2. Horizontally Scrollable Dates & Stats
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Date Headers
                                HStack(spacing: 0) {
                                    ForEach(dataHeaders, id: \.self) { header in
                                        let isPercent = header.trimmingCharacters(in: .whitespaces) == "%"
                                        Text(header)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.primary)
                                            .frame(width: isPercent ? 64 : 68, height: 40, alignment: .center)
                                            .background(Color(nsColor: .controlBackgroundColor))
                                            .border(Color.secondary.opacity(0.12), width: 0.5)
                                    }
                                }
                                
                                // Cells
                                ForEach(Array(filteredRows.enumerated()), id: \.offset) { rowIndex, row in
                                    let dataCells = row.count > 2 ? Array(row.dropFirst(2)) : []
                                    HStack(spacing: 0) {
                                        ForEach(Array(dataHeaders.enumerated()), id: \.offset) { colIndex, header in
                                            let cellValue = colIndex < dataCells.count ? dataCells[colIndex] : ""
                                            let isPercent = header.trimmingCharacters(in: .whitespaces) == "%"
                                            
                                            cellView(cellValue, width: isPercent ? 64 : 68, isEvenRow: rowIndex % 2 == 0)
                                        }
                                    }
                                }
                            }
                        }
                        .zIndex(1)
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No attendance table records available")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private func cellView(_ raw: String, width: CGFloat, isEvenRow: Bool) -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNum = Double(trimmed.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
        
        let (textColor, bgColor, isBold): (Color, Color, Bool) = {
            if trimmed.hasPrefix("P") {
                return (AttendanceColors.safe, AttendanceColors.safe.opacity(0.14), true)
            } else if trimmed.hasPrefix("A") {
                return (AttendanceColors.critical, AttendanceColors.critical.opacity(0.14), true)
            } else if trimmed.hasPrefix("H") {
                return (AttendanceColors.cyan, AttendanceColors.cyan.opacity(0.12), false)
            } else if trimmed.hasPrefix("L") {
                return (AttendanceColors.purple, AttendanceColors.purple.opacity(0.12), false)
            } else if let pct = cleanNum {
                let color = pct >= viewModel.targetThreshold ? AttendanceColors.safe : AttendanceColors.critical
                return (color, color.opacity(0.10), true)
            } else {
                return (Color.secondary, Color.clear, false)
            }
        }()
        
        ZStack {
            if bgColor != Color.clear {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(bgColor)
                    .padding(3)
            } else if isEvenRow {
                Color.primary.opacity(0.015)
            }
            
            Text(trimmed)
                .font(.system(size: 11, weight: isBold ? .bold : .medium, design: .rounded))
                .foregroundColor(textColor)
                .lineLimit(1)
        }
        .frame(width: width, height: 44)
        .border(Color.secondary.opacity(0.08), width: 0.5)
    }
    
    @ViewBuilder
    private func legendItem(title: String, code: String, color: Color) -> some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 18, height: 18)
                Text(code)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
