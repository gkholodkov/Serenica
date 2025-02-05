import SwiftUI

/// A container that shows:
///  1) CalendarPart (header, monthly/weekly grid)
///  2) EventListPart (the day's tasks)
///
/// Manages:
///  - selectedDate
///  - showingEventSheet
///  - selectedEvent (shown in a sheet)
struct EventListView: View {
    @ObservedObject var eventStore: EventStore
    
    @Binding var selectedDate: Date
    @Binding var selectedEvent: Event?
    @Binding var showingEventSheet: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 1) The calendar portion (header, month/week grid, drag logic)
            CalendarPart(
                selectedDate: $selectedDate,
                events: eventStore.events,
                onAddEvent: {
                    showingEventSheet = true
                }
            )
            
            Divider()
                .background(Serenity.Colors.divider)
            
            // 2) The event list portion
            EventListPart(
                eventStore: eventStore,
                selectedDate: selectedDate
            ) { event in
                // user tapped an event row
                selectedEvent = event
            }
        }
    }
}

// MARK: - Preview
#Preview {
    EventListView(
        eventStore: EventStore(),
        selectedDate: .constant(Date()),
        selectedEvent: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
}

#Preview("With Events") {
    let eventStore = EventStore()
    let sampleEvent = Event(
        title: "Sample Event",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        notes: "Sample notes",
        userId: UUID()
    )
    eventStore.previewAddEvent(sampleEvent)
    
    return EventListView(
        eventStore: eventStore,
        selectedDate: .constant(Date()),
        selectedEvent: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
}
