import SwiftUI

// MARK: - WeekCalendarGridView

/// Displays a single-week calendar grid (7 days in one row) that includes the current date.
/// Tapping on a valid day calls `onSelectDay(date)`.
struct WeekCalendarGridView: View {
    @Binding var selectedDate: Date
    @ObservedObject var eventService: EventService
    let onSelectDay: (Date) -> Void

    // Tracks if the user has explicitly selected a day.
    @State private var userHasSelected: Bool = false

    // Seven columns with no extra inter-column spacing.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekDays) { calendarDay in
                DayCellView(
                    day: calendarDay.day,
                    date: calendarDay.date,
                    isCurrentMonth: calendarDay.isCurrentMonth,
                    isSelected: calendarDay.isCurrentMonth &&
                        calendarDay.date >= Date().startOfDay()  &&
                        Calendar.current.isDate(calendarDay.date, inSameDayAs: selectedDate),
                    isToday: calendarDay.isCurrentMonth && Calendar.current.isDate(calendarDay.date, inSameDayAs: Date()),
                    isPast: calendarDay.isCurrentMonth && calendarDay.date < Date().startOfDay(),
                    hasEvents: calendarDay.isCurrentMonth ? eventService.hasOccurrence(on: calendarDay.date) : false,
                    onTap: {
                        if calendarDay.date >= Date().startOfDay() {
                            userHasSelected = true
                            onSelectDay(calendarDay.date)
                        }
                    }
                )
            }
        }
        // Optional: force a view reload when selectedDate changes.
        .id(selectedDate)
    }
    
    /// Computes the 7 days (as CalendarDay values) representing the week that includes the selectedDate.
    private var weekDays: [CalendarDay] {
        var calendarWithMondayFirst = Calendar.current
        calendarWithMondayFirst.firstWeekday = 2 // Monday

        let weekStart = selectedDate.startOfWeek()
        var days: [CalendarDay] = []
        for offset in 0..<7 {
            if let date = calendarWithMondayFirst.date(byAdding: .day, value: offset, to: weekStart) {
                let isCurrentMonth = Calendar.current.component(.month, from: date) ==
                                     Calendar.current.component(.month, from: selectedDate)
                let dayNumber = Calendar.current.component(.day, from: date)
                days.append(CalendarDay(date: date, day: dayNumber, isCurrentMonth: isCurrentMonth))
            }
        }
        return days
    }
}

// MARK: - CalendarDay Model

/// A simple model representing a day in the grid.
private struct CalendarDay: Identifiable {
    let date: Date
    let day: Int
    /// True if the day belongs to the active month.
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
        // Disable tapping for cells that are either not in the active month or represent past dates.
        .disabled(isPast)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private var cellBackground: some View {
        if isSelected {
            // Selected day uses the designated selected color.
            Rectangle()
                .fill(Serenity.Colors.selectedCellColor)
        } else if isToday {
            // Today's cell uses the designated highlight color.
            Rectangle()
                .fill(Serenity.Colors.todayCellColor)
        } else {
            Color.clear
        }
    }

    /// Determines the text color based on state.
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
    WeekCalendarGridView(
        selectedDate: .constant(Date()),
        eventService: EventService()
    ) { _ in }
}

/*
#Preview("With Events") {
    var date = Date()
    let eventService = EventService()
    let sampleEvent = Event(
        title: "Sample Event",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        notes: "Sample notes",
        userId: UUID()
    )
    eventService.previewAddEvent(sampleEvent)
    
    return WeekCalendarGridView(
        selectedDate: .constant(date),
        eventService: eventService
    ) { newDate in date = newDate }
} */
