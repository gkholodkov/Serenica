//
//  EventDetailView.swift
//  Serenica
//
//  Created by Checkito12 on 20.01.25.
//

import SwiftUI

/// A bottom-up sheet for viewing and editing an Event's details.
struct EventDetailView: View {
    
    @State private var editableEvent: Event
    @State private var hasDate: Bool
    var onSave: (Event) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    init(event: Event, onSave: @escaping (Event) -> Void) {
        self.onSave = onSave
        _editableEvent = State(initialValue: event)
        _hasDate = State(initialValue: event.startDate != nil)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section(header: Text("Title")) {
                        TextField("Title", text: $editableEvent.title)
                    }
                    
                    Section(header: Text("Dates")) {
                        Toggle("Has specific date", isOn: $hasDate)
                            .onChange(of: hasDate) { _, newValue in
                                if newValue {
                                    // Initialize dates if nil when enabling specific dates
                                    let now = Date()
                                    if editableEvent.startDate == nil {
                                        editableEvent.startDate = now
                                    }
                                    if editableEvent.endDate == nil {
                                        let defaultEndDate = (editableEvent.startDate ?? now).addingTimeInterval(3600)
                                        editableEvent.endDate = defaultEndDate
                                    }
                                } else {
                                    // Clear dates when disabling specific dates
                                    editableEvent.startDate = nil
                                    editableEvent.endDate = nil
                                }
                            }
                        
                        if hasDate {
                            // Capture current time for clamping
                            let now = Date()
                            
                            // Binding for the start date: clamp to now if necessary.
                            let startBinding = Binding<Date>(
                                get: {
                                    editableEvent.startDate ?? now
                                },
                                set: { newStart in
                                    // Ensure start is not earlier than now
                                    let clampedStart = max(newStart, now)
                                    editableEvent.startDate = clampedStart
                                    // If the new start goes beyond the current end date, adjust end date.
                                    if let end = editableEvent.endDate, clampedStart > end {
                                        editableEvent.endDate = clampedStart.addingTimeInterval(3600)
                                    }
                                }
                            )
                            
                            // Binding for the end date: clamp to start date if necessary.
                            let endBinding = Binding<Date>(
                                get: {
                                    editableEvent.endDate ?? ((editableEvent.startDate ?? now).addingTimeInterval(3600))
                                },
                                set: { newEnd in
                                    let minEnd = editableEvent.startDate ?? now
                                    let clampedEnd = max(newEnd, minEnd)
                                    editableEvent.endDate = clampedEnd
                                }
                            )
                            
                            DatePicker("Start",
                                       selection: startBinding,
                                       in: now...,
                                       displayedComponents: [.date, .hourAndMinute])
                            
                            DatePicker("End",
                                       selection: endBinding,
                                       in: (editableEvent.startDate ?? now)...,
                                       displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    
                    Section(header: Text("Description")) {
                        TextEditor(text: $editableEvent.notes)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !hasDate {
                            editableEvent.startDate = nil
                            editableEvent.endDate = nil
                        }
                        onSave(editableEvent)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Example usage
    EventDetailView(
        event: Event(
            id: UUID(),
            title: "Sample",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            notes: "Sample Description",
            userId: UUID(),
            isCompleted: false
        ),
        onSave: { _ in }
    )
}
