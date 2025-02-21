import SwiftUI

/// Shows a list of all events that have no start/end date (undated) with an "Unassigned" header.
struct UnassignedEventsView: View {
    @ObservedObject var eventService: EventService
    @Binding var selectedEvent: Event?
    @Binding var showingEventSheet: Bool
    
    // New state variables for deletion confirmation.
    @State private var eventToDelete: Event? = nil
    @State private var showingDeletionConfirmation: Bool = false
    
    /// Filter out tasks that are already completed.
    private var unassignedTasks: [Event] {
        eventService.undatedEvents.filter { !$0.isCompleted }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with "Unassigned" title and a plus button.
            HStack {
                Text("Unassigned")
                    .font(Serenity.Typography.screenTitle())
                    .foregroundColor(Serenity.Colors.textPrimary)
                    .padding(.horizontal, 10)
                Spacer()
                Button {
                    showingEventSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(Serenity.Colors.primary)
                }
                .padding(.horizontal, 10)
            }
            .padding()
            
            // List of unassigned events.
            List {
                if unassignedTasks.isEmpty {
                    Text("No tasks")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(unassignedTasks) { event in
                        UnassignedEventRowView(
                            event: event,
                            onToggle: { eventService.toggleEventCompletion(event, on: Date()) },
                            onTap: { selectedEvent = event }
                        )
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            eventToDelete = unassignedTasks[index]
                            showingDeletionConfirmation = true
                        }
                    }
                }
            }
            .listStyle(.plain)
            .padding(.horizontal, 4)
        }
        .background(Color.white)
        // Confirmation dialog for deletion.
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
}

/// Row view for an unassigned event without a subheading.
private struct UnassignedEventRowView: View {
    let event: Event
    let onToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: Serenity.Layout.smallPadding) {
            // Checkbox button.
            Button(action: onToggle) {
                CheckboxView(isChecked: event.isCompleted)
            }
            .buttonStyle(.plain)
            .frame(width: Serenity.Layout.minimumTapTarget, height: Serenity.Layout.minimumTapTarget)
            .accessibilityLabel(event.isCompleted ? "Mark as not completed" : "Mark as completed")
            .accessibilityAddTraits(.isButton)
            
            // Event title button (tapping calls the EventDetailView logic via selectedEvent).
            Button(action: onTap) {
                Text(event.title)
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.textPrimary)
                    .strikethrough(event.isCompleted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Serenity.Layout.tinyPadding)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview {
    UnassignedEventsView(
        eventService: EventService(),
        selectedEvent: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
}

#Preview("With Events") {
    let eventService = EventService()
    
    // Add some undated events.
    let events = [
        Event(
            title: "Undated task 1",
            notes: "No specific date",
            userId: UUID()
        ),
        Event(
            title: "Another floating task",
            notes: "To be scheduled",
            userId: UUID()
        ),
        Event(
            title: "Someday task",
            notes: "When time permits",
            userId: UUID()
        )
    ]
    
    events.forEach { eventService.previewAddEvent($0) }
    
    return UnassignedEventsView(
        eventService: eventService,
        selectedEvent: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
}
