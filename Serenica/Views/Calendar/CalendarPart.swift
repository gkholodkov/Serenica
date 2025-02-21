import SwiftUI

// MARK: - CalendarPart
/// This view orchestrates the calendar display by hosting the header, a fixed weekday header row,
/// and an animated grid container that cross–fades between Month and Week grid views.
struct CalendarPart: View {
    // External state
    @Binding var selectedDate: Date
    @ObservedObject var eventService: EventService
    let onAddEvent: () -> Void

    // Instead of separate mode and gesture offset state, we use a single progress value.
    // 0.0 means “month view” and 1.0 means “week view”.
    @State private var progress: CGFloat = 0.0
    // This is used to capture the progress at the start of a drag gesture.
    @State private var initialProgress: CGFloat = 0.0

    // MARK: Grid Height Constants (grid only)
    private let monthGridHeight: CGFloat = 350
    private let weekGridHeight: CGFloat  = 80

    /// Total vertical difference between the two grid heights.
    private var totalDragDistance: CGFloat {
        monthGridHeight - weekGridHeight
    }

    /// Derived “mode” for convenience.
    /// (When progress is exactly 0 or 1, we’re fully in month or week mode respectively.)
    private var currentMode: CalendarViewMode {
        progress < 0.5 ? .month : .week
    }

    /// Interpolated grid height.
    private var interpolatedGridHeight: CGFloat {
        monthGridHeight - progress * totalDragDistance
    }

    /// Opacity for the month view (fades out as progress → 1).
    private var monthOpacity: Double {
        Double(1 - progress)
    }

    /// Opacity for the week view (fades in as progress → 1).
    private var weekOpacity: Double {
        Double(progress)
    }

    /// Computes a vertical offset for the month grid so that the row containing the selected date
    /// aligns to the top when fully in week view.
    private var selectedWeekOffset: CGFloat {
        let calendar = Calendar.current
        let startOfMonth = selectedDate.startOfMonth()
        let firstOfMonthWeekday = calendar.component(.weekday, from: startOfMonth)
        // Number of leading cells (from previous month)
        let leadingDays = (firstOfMonthWeekday - calendar.firstWeekday + 7) % 7
        let day = calendar.component(.day, from: selectedDate)
        let gridIndex = leadingDays + (day - 1)
        let weekIndex = CGFloat(gridIndex / 7)
        let rowHeight = monthGridHeight / 6
        return weekIndex * rowHeight
    }

    /// When in week view, we do not allow navigating to weeks earlier than the week containing today.
    private var canNavigateToPreviousWeek: Bool {
        if currentMode == .week {
            let currentWeekStart = Date().startOfWeek()
            let selectedWeekStart = selectedDate.startOfWeek()
            return selectedWeekStart > currentWeekStart
        }
        return true // In month mode, no such constraint.
    }

    /// For the month grid, as progress moves from 0 to 1, we translate upward so that the selected row aligns.
    private var monthGridOffset: CGFloat {
        -selectedWeekOffset * progress
    }

    var body: some View {
        VStack(spacing: 0) {
            calendarHeader

            // Fixed weekday header.
            weekdayHeader

            // Animated grid container cross-fading between Month and Week views.
            ZStack {
                MonthCalendarGridView(
                    selectedDate: $selectedDate,
                    eventService: eventService
                ) { dayDate in
                    selectedDate = dayDate
                }
                .opacity(monthOpacity)
                .offset(y: monthGridOffset)

                WeekCalendarGridView(
                    selectedDate: $selectedDate,
                    eventService: eventService
                ) { dayDate in
                    selectedDate = dayDate
                }
                .opacity(weekOpacity)
            }
            .frame(height: interpolatedGridHeight)
            .padding(.horizontal, 10)
            .clipped()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // On the very first update of a drag, capture the current progress.
                        if value.translation == .zero {
                            initialProgress = progress
                        }
                        // Update progress based on the vertical translation.
                        // In month view (initialProgress == 0), dragging up (negative translation)
                        // increases progress; in week view (initialProgress == 1), dragging down (positive)
                        // decreases progress.
                        let delta = value.translation.height / totalDragDistance
                        let newProgress = initialProgress - delta
                        progress = min(max(newProgress, 0), 1)
                    }
                    .onEnded { _ in
                        // Snap to the nearest “mode” based on a threshold.
                        // Here we use 0.5; you could tweak this value if needed.
                        let target: CGFloat = progress >= 0.5 ? 1 : 0
                        withAnimation(.easeInOut) {
                            progress = target
                        }
                    }
            )
        }
    }
}

// MARK: - View Components & Gestures
extension CalendarPart {
    /// The header with navigation arrows, a “Today” button, and an add-event button.
    private var calendarHeader: some View {
        HStack {
            // Left Arrow: In month view, goes to the previous month;
            // in week view, goes to the previous week (if allowed).
            Button {
                withAnimation {
                    if currentMode == .month {
                        let candidate = selectedDate.previousMonth()
                        let earliestMonth = Date().startOfMonth()
                        if candidate >= earliestMonth { selectedDate = candidate }
                    } else {
                        if canNavigateToPreviousWeek {
                            selectedDate = selectedDate.previousWeek()
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Serenity.Colors.primary)
                    .font(.title3)
            }
            .frame(width: Serenity.Layout.minimumTapTarget)
            .disabled(currentMode == .week ? !canNavigateToPreviousWeek : false)

            // Today Button: Resets selectedDate to today.
            Button {
                withAnimation {
                    selectedDate = Date()
                }
            } label: {
                Text("Today")
                    .font(Serenity.Typography.caption())
                    .foregroundColor(Serenity.Colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .stroke(Serenity.Colors.primary, lineWidth: 1)
                    )
            }

            Spacer()

            // Header Title: Varies based on the current mode.
            if currentMode == .month {
                VStack(spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.month(.wide)))
                        .font(Serenity.Typography.screenTitle())
                    Text(selectedDate.formatted(.dateTime.year()))
                        .font(Serenity.Typography.caption())
                }
                .transition(.opacity)
                .id(selectedDate)
                .animation(.easeInOut, value: selectedDate)
            } else {
                // Week view header:
                let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
                let mainText = isToday ? "Today" : DateFormatter.weekdayFormatter.string(from: selectedDate)
                let subText = DateFormatter.monthFormatter.string(from: selectedDate)
                VStack(spacing: 2) {
                    Text(mainText)
                        .font(Serenity.Typography.screenTitle())
                    Text(subText)
                        .font(Serenity.Typography.caption())
                }
                .transition(.opacity)
                .id(selectedDate)
                .animation(.easeInOut, value: selectedDate)
            }

            Spacer()

            // Right Arrow: Navigates to the next month or week.
            Button {
                withAnimation {
                    if currentMode == .month {
                        selectedDate = selectedDate.nextMonth()
                    } else {
                        selectedDate = selectedDate.nextWeek()
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Serenity.Colors.primary)
                    .font(.title3)
            }
            .frame(width: Serenity.Layout.minimumTapTarget)

            // Add Event Button.
            Button(action: onAddEvent) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Serenity.Colors.primary)
                    .font(.title2)
            }
            .padding(.leading, Serenity.Layout.standardPadding)
        }
        .padding()
    }

    /// A fixed weekday header row.
    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { label in
                Text(label)
                    .font(Serenity.Typography.caption())
                    .foregroundColor(Serenity.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
    }
}

// MARK: - Supporting Types and Extensions
private enum CalendarViewMode {
    case month, week
}

// MARK: - Previews

#Preview {
    CalendarPart(
        selectedDate: .constant(Date()),
        eventService: EventService(),
        onAddEvent: {}
    )
}

#Preview("With Events") {
    let eventService = EventService()
    let sampleEvent = Event(
        title: "Sample Event",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        notes: "Sample notes",
        userId: UUID()
    )
    eventService.addEvent(sampleEvent)
    return CalendarPart(
        selectedDate: .constant(Date()),
        eventService: eventService,
        onAddEvent: {}
    )
}
