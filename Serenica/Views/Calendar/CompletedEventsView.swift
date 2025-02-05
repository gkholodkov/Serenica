//
//  CompletedEventsView.swift
//  Serenica
//
//  Created by Checkito12 on 31.01.25.
//

import SwiftUI

/// Shows a list of all completed events, grouped by week and then by day.
struct CompletedEventsView: View {
    @ObservedObject var eventStore: EventStore
    @Binding var selectedEvent: Event?
    
    var body: some View {
        VStack(alignment: .leading) {
            headerView
            listView
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        Text("Completed Events")
            .font(Serenity.Typography.screenTitle())
            .padding([.horizontal, .top])
    }
    
    // MARK: - List View
    private var listView: some View {
        List {
            ForEach(groupedByWeek, id: \.weekKey) { weekGroup in
                ForEach(weekGroup.days, id: \.0) { dayGroup in
                    Section(header: sectionHeader(
                        weekKey: weekGroup.weekKey,
                        firstDay: weekGroup.days.first?.0 ?? dayGroup.0,
                        day: dayGroup.0
                    )) {
                        ForEach(dayGroup.1) { event in
                            EventRow(
                                event: event,
                                onToggle: {
                                    eventStore.toggleEventCompletion(event)
                                },
                                onTap: {
                                    // Optionally: selectedEvent = event
                                }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let e = dayGroup.1[index]
                                eventStore.deleteEvent(withId: e.id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Grouping Completed Tasks by Day
    /// Groups completed events by day using the start of day.
    private var groupedCompletedTasks: [(Date, [Event])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: eventStore.completedEvents) { event in
            calendar.startOfDay(for: event.startDate ?? Date())
        }
        return groups.sorted { $0.key > $1.key }
    }
    
    // MARK: - WeekKey Definition
    /// A helper struct used for grouping events by week.
    private struct WeekKey: Hashable {
        let year: Int
        let week: Int
    }
    
    // MARK: - Grouping by Week
    /// Groups the already grouped (by day) events into weeks.
    private var groupedByWeek: [(weekKey: WeekKey, days: [(Date, [Event])])] {
        let calendar = Calendar.current
        let dayGroups = groupedCompletedTasks
        let weekGroups = Dictionary(grouping: dayGroups) { (date, _) -> WeekKey in
            let components = calendar.dateComponents([.year, .weekOfYear], from: date)
            return WeekKey(year: components.year ?? 0, week: components.weekOfYear ?? 0)
        }
        let sortedWeekGroups = weekGroups.sorted { lhs, rhs in
            if lhs.key.year == rhs.key.year {
                return lhs.key.week > rhs.key.week
            } else {
                return lhs.key.year > rhs.key.year
            }
        }
        return sortedWeekGroups.map { (key, days) in
            let sortedDays = days.sorted { $0.0 > $1.0 }
            return (weekKey: key, days: sortedDays)
        }
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
}

// MARK: - EventRow (inline for this file)

private struct EventRow: View {
    let event: Event
    let onToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            // Checkbox with a checkmark icon or empty circle.
            Button(action: onToggle) {
                CheckboxView(isChecked: event.isCompleted)
            }
            .buttonStyle(.plain)
            .frame(
                width: Serenity.Layout.minimumTapTarget,
                height: Serenity.Layout.minimumTapTarget
            )
            
            // Event title with strikethrough styling.
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: Serenity.Layout.smallPadding) {
                    Text(event.title)
                        .font(Serenity.Typography.bodyText())
                        .strikethrough(event.isCompleted)
                        .foregroundColor(Serenity.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let startDate = event.startDate {
                        HStack(spacing: 2) {
                            Text(startDate.formatted(date: .omitted, time: .shortened))
                            if let endDate = event.endDate {
                                Text(" - ")
                                Text(endDate.formatted(date: .omitted, time: .shortened))
                            }
                        }
                        .font(Serenity.Typography.caption())
                        .foregroundColor(Serenity.Colors.textSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, Serenity.Layout.smallPadding)
        }
    }
}

// MARK: - Preview
#Preview {
    CompletedEventsView(
        eventStore: EventStore(),
        selectedEvent: .constant(nil)
    )
    .withPreviewDependencies()
}

#Preview("With Completed Events") {
    let eventStore = EventStore()
    
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
            title: "Completed yesterday",
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(3600),
            notes: "Yesterday's task",
            userId: UUID(),
            isCompleted: true
        ),
        Event(
            title: "Completed two days ago",
            startDate: twoDaysAgo,
            endDate: twoDaysAgo.addingTimeInterval(3600),
            notes: "Old task",
            userId: UUID(),
            isCompleted: true
        )
    ]
    
    // Add sample events to the store.
    events.forEach { eventStore.previewAddEvent($0) }
    
    return CompletedEventsView(
        eventStore: eventStore,
        selectedEvent: .constant(nil)
    )
    .withPreviewDependencies()
}
