import SwiftUI

// MARK: - MonthCalendarGridView

/// Displays a full-month calendar grid for the given selected date.
/// Tapping on a valid current-month day calls `onSelectDay(date)`.
struct MonthCalendarGridView: View {
    @Binding var selectedDate: Date
    let events: [Event]
    let onSelectDay: (Date) -> Void

    /// Tracks if the user has explicitly selected a date.
    @State private var userHasSelected: Bool = false

    // Define seven flexible columns with no extra inter-column spacing.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(calendarDays) { calendarDay in
                DayCellView(
                    day: calendarDay.day,
                    date: calendarDay.date,
                    isCurrentMonth: calendarDay.isCurrentMonth,
                    isSelected: calendarDay.isCurrentMonth && Calendar.current.isDate(calendarDay.date, inSameDayAs: selectedDate),
                    isToday: calendarDay.isCurrentMonth && Calendar.current.isDate(calendarDay.date, inSameDayAs: Date()),
                    isPast: calendarDay.isCurrentMonth && calendarDay.date < Date().startOfDay(),
                    hasEvents: calendarDay.isCurrentMonth ? hasEvents(on: calendarDay.date) : false,
                    onTap: {
                        // Only allow selection for current-month cells that are not in the past.
                        if calendarDay.isCurrentMonth && calendarDay.date >= Date().startOfDay() {
                            userHasSelected = true
                            onSelectDay(calendarDay.date)
                        }
                    }
                )
            }
        }
    }
    
    /// Computes an array of CalendarDay values to fill a fixed 6-row grid (42 cells).
    private var calendarDays: [CalendarDay] {
        let calendar = Calendar.current
        let startOfMonth = selectedDate.startOfMonth()
        let daysInMonth = selectedDate.daysInMonth()
        
        // Weekday of the first day of the month.
        let firstOfMonthWeekday = calendar.component(.weekday, from: startOfMonth)
        
        // Calculate how many leading (previous month) cells are needed.
        let leadingDays = (firstOfMonthWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [CalendarDay] = []
        
        // Append leading days from the previous month.
        if leadingDays > 0, let previousMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth) {
            let daysInPreviousMonth = previousMonth.daysInMonth()
            for day in (daysInPreviousMonth - leadingDays + 1)...daysInPreviousMonth {
                if let date = dateFor(day: day, inReferenceDate: previousMonth) {
                    days.append(CalendarDay(date: date, day: day, isCurrentMonth: false))
                }
            }
        }
        
        // Append current month days.
        for day in 1...daysInMonth {
            if let date = dateFor(day: day, inReferenceDate: startOfMonth) {
                days.append(CalendarDay(date: date, day: day, isCurrentMonth: true))
            }
        }
        
        // Calculate trailing days to fill out a total of 42 cells.
        let trailingDays = 42 - days.count
        if trailingDays > 0, let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) {
            for day in 1...trailingDays {
                if let date = dateFor(day: day, inReferenceDate: nextMonth) {
                    days.append(CalendarDay(date: date, day: day, isCurrentMonth: false))
                }
            }
        }
        
        return days
    }
    
    /// Helper to create a Date from a day number in the month of the given reference date.
    private func dateFor(day: Int, inReferenceDate referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month], from: referenceDate)
        comps.day = day
        return calendar.date(from: comps)
    }
    
    /// Returns true if the given date (assumed to be a start-of-day) overlaps an event.
    private func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        return events.contains { event in
            guard let startDate = event.startDate, let endDate = event.endDate else { return false }
            let eventStart = calendar.startOfDay(for: startDate)
            let eventEnd = calendar.startOfDay(for: endDate)
            return (min(eventStart, eventEnd)...max(eventStart, eventEnd)).contains(dayStart)
        }
    }
}

// MARK: - CalendarDay Model

/// A simple model representing a day in the calendar grid.
private struct CalendarDay: Identifiable {
    let date: Date
    let day: Int
    /// True if the day belongs to the currently displayed month.
    let isCurrentMonth: Bool
    
    var id: Date { date }
}

// MARK: - DayCellView

/// Displays an individual day cell with proper styling and event indication.
private struct DayCellView: View {
    let day: Int
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let isPast: Bool
    let hasEvents: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                cellBackground
                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(textColor)
                    if hasEvents {
                        Circle()
                            .fill(isSelected ? Color.white : Serenity.Colors.primary)
                            .frame(width: 2, height: 2)
                    }
                }
            }
        }
        // Disable tapping for cells that are either not part of the current month or are in the past.
        .disabled(!isCurrentMonth || isPast)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
    
    @ViewBuilder
    private var cellBackground: some View {
        if isSelected {
            // Selected day: filled background (e.g., color #757575).
            Rectangle()
                .fill(Serenity.Colors.selectedCellColor)
        } else if isToday {
            // Today (if not selected): subtle highlight (e.g., color #f1f1f1).
            Rectangle()
                .fill(Serenity.Colors.todayCellColor)
        } else {
            Color.clear
        }
    }
    
    /// Determines the appropriate text color based on the day state.
    private var textColor: Color {
        if isSelected {
            return .white
        } else if !isCurrentMonth {
            return Color.gray.opacity(0.3)
        } else if isPast {
            return Color.gray.opacity(0.6)
        } else {
            return Serenity.Colors.textPrimary
        }
    }
}

// MARK: - Previews

#Preview {
    MonthCalendarGridView(
        selectedDate: .constant(Date()),
        events: []
    ) { _ in }
}

#Preview("With Events") {
    let today = Date()
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
    
    return MonthCalendarGridView(
        selectedDate: .constant(today),
        events: [
            Event(
                title: "Today's Event",
                startDate: today,
                endDate: today.addingTimeInterval(3600),
                notes: "Sample event",
                userId: UUID()
            ),
            Event(
                title: "Tomorrow's Event",
                startDate: tomorrow,
                endDate: tomorrow.addingTimeInterval(3600),
                notes: "Future event",
                userId: UUID()
            )
        ]
    ) { _ in }
}
