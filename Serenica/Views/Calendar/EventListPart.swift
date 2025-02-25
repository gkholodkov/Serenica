import SwiftUI

// MARK: - Main List View

/// Displays a list of event occurrences for the given date without a header grouping.
/// Each row shows a square checkbox on the left, the primary title, and a subheading that only displays the timespan.
struct EventListPart: View {
    @ObservedObject var eventService: EventService
    let selectedDate: Date
    /// Called when the user taps on an event row (excluding the checkbox).
    let onSelectEvent: (EventOccurrence) -> Void
    
    // Existing state variables for managing a pending toggle action.
    @State private var pendingToggleCompleteEvent: Event? = nil
    @State private var prendingToggleRemoveEvent: Event? = nil
    @State private var countdown: Int = 3
    // A timer publisher that fires every second.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // New state variables for deletion confirmation.
    @State private var eventToDelete: EventOccurrence? = nil
    @State private var showingDeletionConfirmation: Bool = false
    
    var body: some View {
        ZStack {
            List {
                if filteredOccurrences.isEmpty {
                    Text("No tasks")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        // Hide the separator for this empty state row.
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredOccurrences) { occurrence in
                        EventOccurrenceRowView(
                            occurrence: occurrence,
                            // Instead of immediately toggling, start the pending toggle action.
                            onToggle: { startPendingToggle(for: occurrence.event) },
                            onTap: { onSelectEvent(occurrence) },
                            pendingToggleCompleteEvent: pendingToggleCompleteEvent,
                            selectedDate: selectedDate
                        )
                        // Remove the divider/separator between rows.
                        .listRowSeparator(.hidden)
                    }
                    // Instead of deleting immediately, trigger the confirmation dialog.
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            eventToDelete = filteredOccurrences[index]
                            showingDeletionConfirmation = true
                        }
                    }
                }
            }
            .listStyle(.plain)
            
            // When there's a pending toggle, overlay the custom alert at the bottom.
            if pendingToggleCompleteEvent != nil {
                VStack {
                    Spacer()
                    CompletionUndoAlert(countdown: countdown, cancelAction: cancelPendingToggle)
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut, value: pendingToggleCompleteEvent)
            }
        }
        // Drive the countdown: if there's a pending toggle, decrease the count.
        .onReceive(timer) { _ in
            guard pendingToggleCompleteEvent != nil else { return }
            if countdown > 0 {
                countdown -= 1
            } else {
                // Countdown finished: perform the toggle and clear the pending state.
                if let event = pendingToggleCompleteEvent {
                    eventService.toggleEventCompletion(event, on: selectedDate)
                }
                pendingToggleCompleteEvent = nil
            }
        }
        // Present the confirmation dialog when an event is pending deletion.
        .confirmationDialog(
            "Delete Event",
            isPresented: $showingDeletionConfirmation,
            titleVisibility: .hidden
        ) {
            if let event = eventToDelete?.event {
                // For recurring events, offer two delete options.
                if event.recurrenceType != .none {
                    Button("Delete", role: .destructive) {
                        eventService.deleteOccurrence(of: event, on: eventToDelete?.occurrenceStart ?? selectedDate)
                        eventToDelete = nil
                    }
                    Button("Delete for all future events", role: .destructive) {
                        eventService.deleteAllFutureOccurences(of: event, on: eventToDelete?.occurrenceStart ?? selectedDate)
                        eventToDelete = nil
                    }
                    Button("Delete for all events", role: .destructive) {
                        eventService.deleteEvent(withId: event.id, initialNotificationId: event.notificationId)
                        eventToDelete = nil
                    }
                } else {
                    // For non-recurring events, offer only one delete option.
                    Button("Delete", role: .destructive) {
                        eventService.deleteEvent(withId: event.id, initialNotificationId: event.notificationId)
                        eventToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                eventToDelete = nil
            }
        } message: {
            Text("The task will be deleted.")
        }
    }
    
    // Starts the pending toggle for an event.
    private func startPendingToggle(for event: Event) {
        pendingToggleCompleteEvent = event
        countdown = 3
    }
}

// MARK: - Filtering Helper

extension EventListPart {
    /// Returns all event occurrences (both from non‑recurring and recurring events) that occur on the selected date.
    private var filteredOccurrences: [EventOccurrence] {
        eventService.occurrences(on: selectedDate)
    }
}

// MARK: - Row View

/// Displays an individual event occurrence row with a checkbox and two lines of text.
private struct EventOccurrenceRowView: View {
    let occurrence: EventOccurrence
    let onToggle: () -> Void
    let onTap: () -> Void
    let pendingToggleCompleteEvent: Event?
    let selectedDate: Date
    
    var body: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            // If the event is overdue, display a red vertical line.
            if occurrence.event.isOverdue && occurrence.occurrenceStart == occurrence.event.startDate {
                Rectangle()
                    .fill(Serenity.Colors.overdueEvent)
                    .frame(width: 4)
            }
            
            // MARK: Checkbox
            Button(action: onToggle) {
                CheckboxView(isChecked: occurrence.event.isCompleted || occurrence.event.id == pendingToggleCompleteEvent?.id)
            }
            .buttonStyle(.plain)
            .frame(width: Serenity.Layout.minimumTapTarget, height: Serenity.Layout.minimumTapTarget)
            .accessibilityLabel(occurrence.event.isCompleted ? "Mark as not completed" : "Mark as completed")
            .accessibilityAddTraits(.isButton)
            
            // MARK: Text Content
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: Serenity.Layout.smallPadding) {
                    // Primary text: event title.
                    Text(occurrence.event.title)
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textPrimary)
                        .strikethrough(occurrence.event.isCompleted || occurrence.event.id == pendingToggleCompleteEvent?.id)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Secondary text: display the occurrence's timespan.
                    HStack(spacing: 2) {
                        Text(Calendar.current.isDate(occurrence.occurrenceStart, inSameDayAs: selectedDate) ? occurrence.occurrenceStart.formatted(date: .omitted, time: .shortened) : "00:00")
                        Text(" - ")
                        Text(Calendar.current.isDate(occurrence.occurrenceEnd, inSameDayAs: selectedDate) ? occurrence.occurrenceEnd.formatted(date: .omitted, time: .shortened) : "00:00")
                        if occurrence.event.notificationId != nil {
                            Image(systemName: "bell.badge")
                        }
                    }
                    .font(Serenity.Typography.caption())
                    .foregroundColor(Serenity.Colors.textSecondary)
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
        pendingToggleCompleteEvent = nil
    }
}

// MARK: - Previews

#Preview {
    EventListPart(
        eventService: EventService(),
        selectedDate: Date()
    ) { _ in }
    .withPreviewDependencies()
}

#Preview("With Events") {
    let eventService = EventService()
    let sampleEvent = Event(
        title: "Sample Event",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        notes: "Sample notes",
        userId: UUID(),
        notificationId: UUID()
    )
    eventService.previewAddEvent(sampleEvent)
    
    return EventListPart(
        eventService: eventService,
        selectedDate: Date()
    ) { _ in }
    .withPreviewDependencies()
}
