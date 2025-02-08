//
//  ToDoView.swift
//  Serenica
//
//  Created by Checkito12 on 02.02.25.
//


import SwiftUI

struct ToDoView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    
    // Main EventStore
    @StateObject private var eventStore = EventStore()
    
    // UI State
    @State private var selectedTab = 1
    @State private var selectedDate = Date()
    @State private var showingEventSheet = false
    @State private var selectedEvent: Event? = nil
    
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
                        eventStore: eventStore,
                        selectedEvent: $selectedEvent,
                        showingEventSheet: $showingEventSheet
                    )
                case 1:
                    // Active tasks (calendar + day-based event list)
                    EventListView(
                        eventStore: eventStore,
                        selectedDate: $selectedDate,
                        selectedEvent: $selectedEvent,
                        showingEventSheet: $showingEventSheet
                    )
                default:
                    // Completed tasks
                    CompletedEventsView(
                        eventStore: eventStore,
                        selectedEvent: $selectedEvent
                    )
                }
            }
            .background(Serenity.Colors.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear() {
            eventStore.refreshEvents()
        }
        
        // Add new event sheet
        .sheet(isPresented: $showingEventSheet) {
            AddEventView(date: (selectedTab == 1) ? selectedDate : nil)
                .environmentObject(eventStore)
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
                EventDetailView(event: event) { updated in
                    eventStore.updateEvent(updated)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .padding(.top, Serenity.Layout.standardPadding)
                .background(.ultraThickMaterial)
            }
        }
        
        // Once we appear, ensure eventStore uses the correct authService
        .onAppear {
            eventStore.updateAuthService(authService)
        }
    }
}

// MARK: - Preview

#Preview {
    ToDoView()
        .withPreviewDependencies()
}
