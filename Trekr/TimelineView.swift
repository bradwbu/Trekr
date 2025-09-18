import SwiftUI

struct TimelineView: View {
    @Binding var selectedDateRange: ClosedRange<Date>?
    @State private var selectedMode: TimelineMode = .day
    @State private var selectedDate = Date()
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate = Date()
    
    enum TimelineMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case custom = "Custom"
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Mode selector
            Picker("Timeline Mode", selection: $selectedMode) {
                ForEach(TimelineMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedMode) { _ in
                updateDateRange()
            }
            
            // Date selector
            HStack {
                if selectedMode == .custom {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: startDate) { _ in
                            updateDateRange()
                        }
                    
                    Text("to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .onChange(of: endDate) { _ in
                            updateDateRange()
                        }
                } else {
                    Button(action: {
                        adjustDate(by: -1)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Text(dateRangeText)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        adjustDate(by: 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                    }
                }
            }
            .padding(.horizontal)
            
            // Today button
            Button(action: {
                selectedDate = Date()
                updateDateRange()
            }) {
                Text("Today")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            updateDateRange()
        }
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        switch selectedMode {
        case .day:
            return formatter.string(from: selectedDate)
        case .week:
            guard let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)),
                  let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) else {
                return ""
            }
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        case .custom:
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
    
    private func updateDateRange() {
        switch selectedMode {
        case .day:
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: selectedDate)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
            selectedDateRange = startOfDay...endOfDay
            
        case .week:
            let calendar = Calendar.current
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }
            selectedDateRange = weekStart...weekEnd
            
        case .month:
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: selectedDate)
            guard let monthStart = calendar.date(from: components),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }
            selectedDateRange = monthStart...nextMonth
            
        case .custom:
            // Ensure end date is not before start date
            if endDate < startDate {
                endDate = startDate
            }
            
            let calendar = Calendar.current
            let startOfStartDay = calendar.startOfDay(for: startDate)
            guard let endOfEndDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else { return }
            selectedDateRange = startOfStartDay...endOfEndDay
        }
    }
    
    private func adjustDate(by amount: Int) {
        let calendar = Calendar.current
        
        switch selectedMode {
        case .day:
            if let newDate = calendar.date(byAdding: .day, value: amount, to: selectedDate) {
                selectedDate = newDate
            }
        case .week:
            if let newDate = calendar.date(byAdding: .weekOfYear, value: amount, to: selectedDate) {
                selectedDate = newDate
            }
        case .month:
            if let newDate = calendar.date(byAdding: .month, value: amount, to: selectedDate) {
                selectedDate = newDate
            }
        case .custom:
            // For custom range, adjust both dates by the same amount
            if let newStartDate = calendar.date(byAdding: .day, value: amount, to: startDate),
               let newEndDate = calendar.date(byAdding: .day, value: amount, to: endDate) {
                startDate = newStartDate
                endDate = newEndDate
            }
        }
        
        updateDateRange()
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView(selectedDateRange: .constant(Date()...Date()))
            .previewLayout(.sizeThatFits)
    }
}