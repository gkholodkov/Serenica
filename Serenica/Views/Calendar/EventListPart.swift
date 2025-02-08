import SwiftUI

// MARK: - Main List View

/// Displays a list of events for the given date without a header grouping.
/// Each row shows a square checkbox on the left, the primary title, and a subheading
/// that only displays the timespan.
struct EventListPart: View {
    @ObservedObject var eventStore: EventStore
    let selectedDate: Date

    /// Called when the user taps on an event row (excluding the checkbox).
    let onSelectEvent: (Event) -> Void
    
    // New state variables for managing a pending toggle action.
    @State private var pendingToggleEvent: Event? = nil
    @State private var countdown: Int = 3
    // A timer publisher that fires every second.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            List {
                if filteredEvents.isEmpty {
                    Text("No tasks")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        // Hide the separator for this empty state row.
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredEvents) { event in
                        EventRowView(
                            event: event,
                            // Instead of immediately toggling, start the pending toggle action.
                            onToggle: { startPendingToggle(for: event) },
                            onTap: { onSelectEvent(event) },
                            pendingToggleEvent: pendingToggleEvent
                        )
                        // Remove the divider/separator between rows.
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            eventStore.deleteEvent(withId: filteredEvents[index].id)
                        }
                    }
                }
            }
            .listStyle(.plain)
            
            // When there's a pending toggle, overlay the custom alert at the bottom.
            if pendingToggleEvent != nil {
                VStack {
                    Spacer()
                    CompletionUndoAlert(countdown: countdown, cancelAction: cancelPendingToggle)
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: pendingToggleEvent)
            }
        }
        // Drive the countdown: if there's a pending toggle, decrease the count.
        .onReceive(timer) { _ in
            guard pendingToggleEvent != nil else { return }
            if countdown > 0 {
                countdown -= 1
            } else {
                // Countdown finished: perform the toggle and clear the pending state.
                if let event = pendingToggleEvent {
                    eventStore.toggleEventCompletion(event)
                }
                pendingToggleEvent = nil
            }
        }
    }
    
    // Starts the pending toggle for an event.
    private func startPendingToggle(for event: Event) {
        pendingToggleEvent = event
        countdown = 3
    }
}

// MARK: - Filtering Helper

extension EventListPart {
    /// Returns all events that occur on the selected date.
    private var filteredEvents: [Event] {
        let selectedDayStart = Calendar.current.startOfDay(for: selectedDate)
        return eventStore.events.filter { event in
            guard let startDate = event.startDate,
                  let endDate = event.endDate else { return false }
            let startDay = Calendar.current.startOfDay(for: startDate)
            let endDay = Calendar.current.startOfDay(for: endDate)
            let rangeStart = min(startDay, endDay)
            let rangeEnd = max(startDay, endDay)
            return (rangeStart ... rangeEnd).contains(selectedDayStart)
        }
    }
}

// MARK: - Row View

/// Displays an individual event row with a checkbox and two lines of text.
/// The primary text is the event title, and the secondary text shows only the timespan.
private struct EventRowView: View {
    let event: Event
    let onToggle: () -> Void
    let onTap: () -> Void
    let pendingToggleEvent: Event?

    var body: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            // MARK: Checkbox
            Button(action: onToggle) {
                CheckboxView(isChecked: event.isCompleted || event.id == pendingToggleEvent?.id)
            }
            .buttonStyle(.plain)
            .frame(width: Serenity.Layout.minimumTapTarget, height: Serenity.Layout.minimumTapTarget)
            .accessibilityLabel(event.isCompleted  ? "Mark as not completed" : "Mark as completed")
            .accessibilityAddTraits(.isButton)
            
            // MARK: Text Content
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: Serenity.Layout.smallPadding) {
                    // Primary text: event title
                    Text(event.title)
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textPrimary)
                        .strikethrough(event.isCompleted || event.id == pendingToggleEvent?.id)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Secondary text: only display timespan (omitting the date)
                    if let startDate = event.startDate {
                        HStack(spacing: 2) {
                            Text(startDate.formatted(date: .omitted, time: .shortened))
                            if let endDate = event.endDate {
                                Text(" - ")
                                Text(endDate.formatted(date: .omitted, time: .shortened))
                                if (event.notificationId != nil) {
                                    Image(systemName: "bell.badge")
                                }
                            }
                        }
                        .font(Serenity.Typography.caption())
                        .foregroundColor(Serenity.Colors.textSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Serenity.Layout.smallPadding)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cancel Pending Toggle Action

extension EventListPart {
    private func cancelPendingToggle() {
        pendingToggleEvent = nil
    }
}

// MARK: - Previews

#Preview {
    EventListPart(
        eventStore: EventStore(),
        selectedDate: Date()
    ) { _ in }
    .withPreviewDependencies()
}

#Preview("With Events") {
    let eventStore = EventStore()
    let sampleEvent = Event(
        title: "Sample Event",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        notes: "Sample notes",
        userId: UUID(),
        notificationId: UUID()
    )
    eventStore.previewAddEvent(sampleEvent)
    
    return EventListPart(
        eventStore: eventStore,
        selectedDate: Date()
    ) { _ in }
    .withPreviewDependencies()
}
