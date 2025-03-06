import SwiftUI

/// Shows a list of all completed events, grouped by week and then by day.
/// Events spanning multiple days will appear on each day. On days before
/// the actual start, a default start time of 00:00 is shown; on days after
/// the actual end, a default end time of 23:59 is shown.
struct CompletedEventsView: View {
    @ObservedObject var eventService: EventService
    @Binding var selectedEvent: Event?
    
    // New state variables for deletion confirmation.
    @State private var eventToDelete: Event? = nil
    @State private var showingDeletionConfirmation: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            headerView
            listView
        }
        .confirmationDialog(
            "Delete Event",
            isPresented: $showingDeletionConfirmation,
            titleVisibility: .hidden
        ) {
            if let event = eventToDelete {
                Button("Delete", role: .destructive) {
                    eventService.deleteEvent(withId: event.id)
                    eventToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                eventToDelete = nil
            }
        } message: {
            Text("The task will be deleted.")
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        Text("Completed Events")
            .font(Serenity.Typography.screenTitle())
            .padding([.horizontal, .top])
    }
    
    // MARK: - Daily Event Grouping
    /// For events that may span multiple days, create one entry per day.
    /// For each day, if it is not the start day, we use 00:00 as the start time;
    /// if it is not the end day, we use 23:59 as the end time.
    private var dailyEvents: [(day: Date, events: [DailyEvent])] {
        let calendar = Calendar.current
        var dailyEventList: [DailyEvent] = []
        
        for event in eventService.completedEvents {
            // Assume a valid startDate; if nil, skip the event.
            guard let start = event.startDate else { continue }
            let end = event.endDate ?? start
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.startOfDay(for: end)
            
            var day = startDay
            while day <= endDay {
                // On the start day, use the event's start time; otherwise, use 00:00.
                let displayStart = calendar.isDate(day, inSameDayAs: start) ? start : day
                // On the end day, use the event's end time; otherwise, use 23:59.
                let displayEnd = calendar.isDate(day, inSameDayAs: end)
                    ? end
                    : (calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day)
                
                let dailyEvent = DailyEvent(
                    id: "\(event.id)-\(day)",
                    event: event,
                    day: day,
                    displayStart: displayStart,
                    displayEnd: displayEnd
                )
                dailyEventList.append(dailyEvent)
                
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = nextDay
            }
        }
        
        // Group daily events by day
        let groups = Dictionary(grouping: dailyEventList, by: { $0.day })
        // Sort groups descending (most recent day first)
        let sortedGroups = groups.sorted { $0.key > $1.key }
        // Map dictionary elements to tuples with label names matching our return type.
        return sortedGroups.map { (day: $0.key, events: $0.value) }
    }
    
    // MARK: - Grouping by Week
    /// Groups daily events into weeks.
    private var groupedByWeek: [(weekKey: WeekKey, days: [(day: Date, events: [DailyEvent])])] {
        let calendar = Calendar.current
        let dayGroups = dailyEvents
        
        // Group by week
        let weekGroups = Dictionary(grouping: dayGroups) { (dayGroup) -> WeekKey in
            let components = calendar.dateComponents([.year, .weekOfYear], from: dayGroup.day)
            return WeekKey(year: components.year ?? 0, week: components.weekOfYear ?? 0)
        }
        
        // Sort the week groups.
        let sortedWeekGroups = weekGroups.sorted { (lhs, rhs) -> Bool in
            if lhs.key.year == rhs.key.year {
                return lhs.key.week > rhs.key.week
            } else {
                return lhs.key.year > rhs.key.year
            }
        }
        
        // Map into the expected return type using a simple loop.
        var result: [(weekKey: WeekKey, days: [(day: Date, events: [DailyEvent])])] = []
        for (key, days) in sortedWeekGroups {
            let sortedDays = days.sorted { $0.day > $1.day }
            result.append((weekKey: key, days: sortedDays))
        }
        return result
    }
    
    // MARK: - WeekKey Definition
    /// A helper struct used for grouping events by week.
    private struct WeekKey: Hashable {
        let year: Int
        let week: Int
    }
    
    // MARK: - Section Header for Week and Day
    /// Returns a header view with the week label (only for the first day in the week) and the day subheading.
    private func sectionHeader(weekKey: WeekKey, firstDay: Date, day: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if day == firstDay {
                Text("Week \(weekKey.week)")
                    .font(Serenity.Typography.screenSubtitle())
                    .foregroundColor(Serenity.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            dayHeader(for: day)
        }
    }
    
    // MARK: - Day Header Formatter
    /// Formats a given date as a day header (e.g., "Monday – January 20").
    private func dayHeader(for date: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE – MMMM d"
        return Text(formatter.string(from: date))
            .font(Serenity.Typography.caption())
            .foregroundColor(Serenity.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - List View
    private var listView: some View {
        List {
            ForEach(groupedByWeek, id: \.weekKey) { weekGroup in
                ForEach(weekGroup.days, id: \.day) { dayGroup in
                    Section(header: sectionHeader(
                        weekKey: weekGroup.weekKey,
                        firstDay: weekGroup.days.first?.day ?? dayGroup.day,
                        day: dayGroup.day
                    )) {
                        ForEach(dayGroup.events) { dailyEvent in
                            EventRow(
                                dailyEvent: dailyEvent,
                                onTap: { selectedEvent = dailyEvent.event }
                            )
                        }
                        .onDelete { indexSet in
                            if let index = indexSet.first {
                                eventToDelete = dayGroup.events[index].event
                                showingDeletionConfirmation = true
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - DailyEvent Definition
/// Changed from private to fileprivate so it's accessible by other views in this file.
fileprivate struct DailyEvent: Identifiable {
    let id: String
    let event: Event
    let day: Date
    let displayStart: Date
    let displayEnd: Date
}

// MARK: - EventRow (Updated to use DailyEvent)
private struct EventRow: View {
    let dailyEvent: DailyEvent
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: Serenity.Layout.smallPadding) {
                    Text(dailyEvent.event.title)
                        .font(Serenity.Typography.bodyText())
                        .strikethrough(dailyEvent.event.isCompleted)
                        .foregroundColor(Serenity.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 2) {
                        Text(dailyEvent.displayStart.formatted(date: .omitted, time: .shortened))
                        Text(" - ")
                        Text(dailyEvent.displayEnd.formatted(date: .omitted, time: .shortened))
                    }
                    .font(Serenity.Typography.caption())
                    .foregroundColor(Serenity.Colors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, Serenity.Layout.smallPadding)
        }
    }
}

/*
// MARK: - Preview
#Preview {
    CompletedEventsView(
        eventService: EventService(),
        selectedEvent: .constant(nil)
    )
    .withPreviewDependencies()
}

#Preview("With Completed Events") {
    let eventService = EventService()
    
    // Add some completed events for preview purposes.
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
    
    let events = [
        Event(
            title: "Completed today",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            notes: "Today's task",
            userId: UUID(),
            isCompleted: true
        ),
        Event(
            title: "Multi-day event",
            startDate: twoDaysAgo,
            endDate: yesterday,
            notes: "Spanning multiple days",
            userId: UUID(),
            isCompleted: true
        )
    ]
    
    // Add sample events to the store.
    events.forEach { eventService.previewAddEvent($0) }
    
    return CompletedEventsView(
        eventService: eventService,
        selectedEvent: .constant(nil)
    )
    .withPreviewDependencies()
} */
