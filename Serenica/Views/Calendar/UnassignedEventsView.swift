import SwiftUI

/// Shows a list of all events that have no start/end date (undated) with an "Unassigned" header.
struct UnassignedEventsView: View {
    @ObservedObject var eventStore: EventStore
    @Binding var selectedEvent: Event?
    @Binding var showingEventSheet: Bool
    
    /// Filter out tasks that are already completed.
    private var unassignedTasks: [Event] {
        eventStore.undatedEvents.filter { !$0.isCompleted }
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
                            onToggle: { eventStore.toggleEventCompletion(event) },
                            onTap: { selectedEvent = event }
                        )
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let event = unassignedTasks[index]
                            eventStore.deleteEvent(withId: event.id)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .padding(.horizontal, 4)
        }
        .background(Color.white)
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
        eventStore: EventStore(),
        selectedEvent: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
}

#Preview("With Events") {
    let eventStore = EventStore()
    
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
    
    events.forEach { eventStore.previewAddEvent($0) }
    
    return UnassignedEventsView(
        eventStore: eventStore,
        selectedEvent: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
}
