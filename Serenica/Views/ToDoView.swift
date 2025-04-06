import SwiftUI

struct ToDoView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var eventService: EventService
    
    // UI State
    @State private var selectedTab = 1
    @State private var selectedDate = Date()
    @State private var showingEventSheet = false
    @State private var selectedEvent: Event? = nil
    @State private var selectedEventOccurrence: EventOccurrence? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented Picker for the 3 tabs
            Picker("View", selection: $selectedTab) {
                Text("Unassigned").tag(0)
                Text("Calendar").tag(1)
                Text("Completed").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(Serenity.Layout.standardPadding)
            .background(Serenity.Colors.background)
            .tint(Serenity.Colors.primary)
            
            // Show one of the three subviews
            Group {
                switch selectedTab {
                case 0:
                    // Unassigned / undated tasks
                    UnassignedEventsView(
                        eventService: eventService,
                        selectedEvent: $selectedEvent,
                        selectedEventOccurrence: $selectedEventOccurrence,
                        showingEventSheet: $showingEventSheet
                    )
                case 1:
                    // Active tasks (calendar + day-based event list)
                    EventListView(
                        eventService: eventService,
                        selectedDate: $selectedDate,
                        selectedEvent: $selectedEvent,
                        selectedEventOccurrence: $selectedEventOccurrence,
                        showingEventSheet: $showingEventSheet
                    )
                default:
                    // Completed tasks
                    CompletedEventsView(
                        eventService: eventService,
                        selectedEvent: $selectedEvent
                    )
                }
            }
            .background(Serenity.Colors.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        
        // Add new event sheet
        .sheet(isPresented: $showingEventSheet) {
            AddEventView(
                passedDate: (selectedTab == 1)
                    ? Binding<Date?>(
                        get: { selectedDate },
                        set: { newValue in
                            // If the child sets `passedDate` to nil, decide how you want to handle that.
                            // Here, we fall back to Date() if nil is assigned.
                            selectedDate = newValue ?? Date()
                        }
                    )
                    : .constant(nil)        // otherwise pass nil
                )
                .environmentObject(eventService)
        }
        
        // Event detail sheet
        .sheet(item: $selectedEvent) { event in
            if (selectedTab == 2) {
                CompletedTaskDetailsView(event: event)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .padding(.top, Serenity.Layout.standardPadding)
                    .background(.ultraThickMaterial)
            }
            else {
                EventDetailView(
                    event: event,
                    occurrence: $selectedEventOccurrence,
                    onSave: { updatedEvent in
                        // Handle updating the event.
                        eventService.updateEvent(updatedEvent)
                    },
                    onSaveOccurrence: { updatedOccurrence in
                        // Handle updating only this single occurrence.
                        eventService.updateSingleOccurrence(of: selectedEvent!, on: selectedDate, with: updatedOccurrence)
                    },
                    onSaveFutureOccurrences: { updatedOccurrence in
                        // Handle updating all future occurrences of the event.
                        eventService.updateAllFutureOccurrences(of: selectedEvent!, on: selectedDate, with: updatedOccurrence)
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .padding(.top, Serenity.Layout.standardPadding)
                .background(.ultraThickMaterial)
            }
        }
        
        // Once we appear, ensure eventService uses the correct authService
        .onAppear {
            eventService.updateAuthService(authService)
            eventService.updateOverdueAndRefreshDates()
        }
    }
}

/*
// MARK: - Preview

#Preview {
    ToDoView()
        .withPreviewDependencies()
}
*/
