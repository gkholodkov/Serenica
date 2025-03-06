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
    @ObservedObject var eventService: EventService
    
    @Binding var selectedDate: Date
    @Binding var selectedEvent: Event?
    @Binding var selectedEventOccurrence: EventOccurrence?
    @Binding var showingEventSheet: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 1) The calendar portion (header, month/week grid, drag logic)
            CalendarPart(
                selectedDate: $selectedDate,
                eventService: eventService,
                onAddEvent: {
                    showingEventSheet = true
                }
            )
            
            Divider()
                .background(Serenity.Colors.divider)
            
            // 2) The event list portion
            EventListPart(
                eventService: eventService,
                selectedDate: selectedDate
            ) { occurrence in
                // user tapped an event row
                selectedEvent = occurrence.event
                selectedEventOccurrence = occurrence
                print(eventService.recurringEvents)
            }
        }
    }
}

/*
// MARK: - Preview
#Preview {
    EventListView(
        eventService: EventService(),
        selectedDate: .constant(Date()),
        selectedEvent: .constant(nil),
        selectedEventOccurrence: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
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
    eventService.previewAddEvent(sampleEvent)
    
    return EventListView(
        eventService: eventService,
        selectedDate: .constant(Date()),
        selectedEvent: .constant(nil),
        selectedEventOccurrence: .constant(nil),
        showingEventSheet: .constant(false)
    )
    .withPreviewDependencies()
}
*/
