import SwiftUI

// MARK: - CalendarPart
/// A calendar view that cross-fades and repositions its month and week grid views
/// based on a fully responsive vertical drag gesture, and navigates via horizontal drags.
struct CalendarPart: View {
    // External state
    @Binding var selectedDate: Date
    @ObservedObject var eventService: EventService
    let onAddEvent: () -> Void

    // MARK: Internal State
    /// progress: 0.0 is fully month view; 1.0 is fully week view.
    @State private var progress: CGFloat = 0.0
    /// Captures the progress when the drag begins.
    @State private var initialProgress: CGFloat = 0.0
    @State private var isDragging: Bool = false

    // MARK: Grid Height Constants
    private let monthGridHeight: CGFloat = 350
    private let weekGridHeight: CGFloat  = 80

    /// Total vertical difference between the two grid heights.
    private var totalDragDistance: CGFloat {
        monthGridHeight - weekGridHeight
    }

    // MARK: Derived Properties
    /// Determines whether we’re showing month or week mode.
    private var currentMode: CalendarViewMode {
        progress < 0.5 ? .month : .week
    }

    /// Interpolated grid height based on current progress.
    private var interpolatedGridHeight: CGFloat {
        monthGridHeight - progress * totalDragDistance
    }

    /// Opacity values for cross-fading between views.
    private var monthOpacity: Double { Double(1 - progress) }
    private var weekOpacity: Double { Double(progress) }

    /// Computes the vertical offset for the month grid so that the row containing the
    /// selected date aligns to the top when in week view.
    private var selectedWeekOffset: CGFloat {
        let calendar = Calendar.current
        let startOfMonth = selectedDate.startOfMonth()
        let firstOfMonthWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = (firstOfMonthWeekday - calendar.firstWeekday + 7) % 7
        let day = calendar.component(.day, from: selectedDate)
        let gridIndex = leadingDays + (day - 1)
        let weekIndex = CGFloat(gridIndex / 7)
        let rowHeight = monthGridHeight / 6
        return weekIndex * rowHeight
    }

    /// The month grid moves upward proportionally so that its selected week aligns.
    private var monthGridOffset: CGFloat {
        -selectedWeekOffset * progress
    }

    var body: some View {
        VStack(spacing: 0) {
            calendarHeader
            weekdayHeader

            // Animated container that cross-fades between Month and Week grid views.
            ZStack {
                // Month grid view
                MonthCalendarGridView(
                    selectedDate: $selectedDate,
                    eventService: eventService
                ) { dayDate in
                    selectedDate = dayDate
                }
                .opacity(monthOpacity)
                .offset(y: monthGridOffset)

                // Week grid view
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
            // Vertical drag for the responsive transition
            .highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            initialProgress = progress
                        }
                        
                        // Calculate vertical progress change.
                        let dragFactor: CGFloat = 0.9
                        let delta = (value.translation.height / totalDragDistance) * dragFactor
                        let newProgress = initialProgress - delta
                        progress = min(max(newProgress, 0), 1)
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        // Snap to either mode based on final progress and gesture velocity.
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let velocityThreshold: CGFloat = 50
                        let target: CGFloat = abs(velocity) > velocityThreshold
                            ? (velocity < 0 ? 1 : 0)
                            : (progress >= 0.5 ? 1 : 0)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            progress = target
                        }
                    }
            )
            // Horizontal drag for navigating to previous/next month or week.
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        // Ensure the drag is predominantly horizontal.
                        if abs(value.translation.width) > abs(value.translation.height) {
                            let threshold: CGFloat = 50
                            if value.translation.width < -threshold {
                                // Swipe left: navigate forward.
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if currentMode == .month {
                                        selectedDate = selectedDate.nextMonth()
                                    } else {
                                        selectedDate = selectedDate.nextWeek()
                                    }
                                }
                            } else if value.translation.width > threshold {
                                // Swipe right: navigate backward.
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if currentMode == .month {
                                        let candidate = selectedDate.previousMonth()
                                        let earliestMonth = Date().startOfMonth()
                                        if candidate >= earliestMonth {
                                            selectedDate = candidate
                                        }
                                    } else {
                                        if canNavigateToPreviousWeek {
                                            selectedDate = selectedDate.previousWeek()
                                        }
                                    }
                                }
                            }
                        }
                    }
            )
            .onChange(of: selectedDate) { _, _ in
                // When the date is changed externally, maintain the current progress.
            }
        }
    }
}

// MARK: - View Components & Gestures
extension CalendarPart {
    /// The header with navigation arrows (now unused), a "Today" button, and an add-event button.
    private var calendarHeader: some View {
        HStack {
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

            ZStack {
                VStack(spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.month(.wide)))
                        .font(Serenity.Typography.screenTitle())
                    Text(selectedDate.formatted(.dateTime.year()))
                        .font(Serenity.Typography.caption())
                }
                .opacity(monthOpacity)
                
                VStack(spacing: 2) {
                    let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: Date())
                    let mainText = isToday ? "Today" : DateFormatter.weekdayFormatter.string(from: selectedDate)
                    Text(mainText)
                        .font(Serenity.Typography.screenTitle())
                    Text(DateFormatter.monthFormatter.string(from: selectedDate))
                        .font(Serenity.Typography.caption())
                }
                .opacity(weekOpacity)
            }
            .id(selectedDate)
            .animation(.easeInOut, value: selectedDate)

            Spacer()

            Button(action: onAddEvent) {
                Image(systemName: "plus")
                    .foregroundColor(Serenity.Colors.primary)
                    .font(Serenity.Typography.screenIcon())
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

    /// When in week view, disallow navigating to weeks earlier than the week containing today.
    private var canNavigateToPreviousWeek: Bool {
        if currentMode == .week {
            let currentWeekStart = Date().startOfWeek()
            let selectedWeekStart = selectedDate.startOfWeek()
            return selectedWeekStart > currentWeekStart
        }
        return true
    }
}

// MARK: - Supporting Types
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
