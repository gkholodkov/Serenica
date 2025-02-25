import SwiftUI

struct EventDetailView: View {
    // The base event being edited.
    let event: Event
    // Binding for an optional occurrence (if editing a single occurrence in a recurring series).
    @Binding var occurrence: EventOccurrence?
    
    // Callbacks for saving.
    let onSave: (Event) -> Void
    let onSaveOccurrence: ((Event) -> Void)?
    let onSaveFutureOccurrences: ((Event) -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Local state copies – these are set on first appearance.
    @State private var initialEvent: Event? = nil
    @State private var editableEvent: Event? = nil
    @State private var hasDate: Bool = false
    @State private var alertConfig: AlertConfiguration = AlertConfiguration()
    @State private var showUpdateChoice: Bool = false

    // Recurrence‑related state
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: RecurrenceType = .daily
    @State private var recurrenceInterval: Int = 1
    @State private var setRecurrenceEndDate: Bool = false
    @State private var recurrenceEndDate: Date = Date().addingTimeInterval(86400)
    @State private var expandedPicker: ExpandedPicker? = nil

    // A fixed lower bound for date pickers.
    @State private var initialNow: Date = Date()

    /// A computed property that returns the current editable event with merged recurrence fields.
    private var currentEvent: Event? {
        guard var e = editableEvent else { return nil }
        e.recurrenceType = isRecurring ? recurrenceType : .none
        e.recurrenceInterval = isRecurring ? recurrenceInterval : 0
        e.recurrenceEndDate = (isRecurring && setRecurrenceEndDate) ? recurrenceEndDate : nil
        return e
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let _ = editableEvent, currentEvent != nil {
                    Form {
                        // MARK: Title Section
                        Section(header: Text("Title")) {
                            TextField("Enter event title", text: Binding(
                                get: { editableEvent?.title ?? "" },
                                set: { newVal in
                                    editableEvent?.title = newVal
                                }
                            ))
                            .foregroundColor(Serenity.Colors.primary)
                        }
                        
                        // MARK: Dates Section with Custom Date Pickers
                        Section(header: Text("Dates")) {
                            Toggle("Assign a date", isOn: $hasDate)
                                .onChange(of: hasDate) { _, newValue in
                                    if newValue {
                                        let now = Date()
                                        if editableEvent?.startDate == nil {
                                            editableEvent?.startDate = now
                                        }
                                        if editableEvent?.endDate == nil {
                                            editableEvent?.endDate = (editableEvent?.startDate ?? now).addingTimeInterval(3600)
                                        }
                                    } else {
                                        editableEvent?.startDate = nil
                                        editableEvent?.endDate = nil
                                        alertConfig.assignReminder = false
                                        isRecurring = false
                                    }
                                }
                            
                            if hasDate {
                                // Custom Start Date Picker
                                VStack {
                                    Button(action: {
                                        withAnimation {
                                            expandedPicker = (expandedPicker == .start) ? nil : .start
                                        }
                                    }) {
                                        HStack {
                                            Text("Start")
                                            Spacer()
                                            if let start = editableEvent?.startDate {
                                                Text(start, style: .date)
                                                    .foregroundColor(expandedPicker == .start ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                                Text(start, style: .time)
                                                    .foregroundColor(expandedPicker == .start ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                            }
                                        }
                                    }
                                    if expandedPicker == .start {
                                        WheelDatePicker(date: Binding<Date>(
                                            get: {
                                                editableEvent?
                                                    .startDate
                                                ?? Date()
                                            },
                                            set: { newStart in
                                                editableEvent?.startDate = newStart
                                                if let end = editableEvent?.endDate, newStart > end {
                                                    editableEvent?.endDate = newStart.addingTimeInterval(3600)
                                                }
                                            }
                                        ), minimumDate: initialNow)
                                        .frame(height: 216)
                                    }
                                }
                                
                                // Custom End Date Picker
                                VStack {
                                    Button(action: {
                                        withAnimation {
                                            expandedPicker = (expandedPicker == .end) ? nil : .end
                                        }
                                    }) {
                                        HStack {
                                            Text("End")
                                            Spacer()
                                            if let end = editableEvent?.endDate {
                                                Text(end, style: .date)
                                                    .foregroundColor(expandedPicker == .end ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                                Text(end, style: .time)
                                                    .foregroundColor(expandedPicker == .end ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                            }
                                        }
                                    }
                                    if expandedPicker == .end {
                                        WheelDatePicker(date: Binding<Date>(
                                            get: { editableEvent?.endDate ?? Date() },
                                            set: { newEnd in
                                                let minEnd = editableEvent?.startDate ?? Date()
                                                editableEvent?.endDate = max(newEnd, minEnd)
                                            }
                                        ), minimumDate: editableEvent?.startDate ?? Date())
                                        .frame(height: 216)
                                    }
                                }
                            }
                        }
                        
                        // MARK: Reminder Section
                        Section(header: Text("Reminder")) {
                            AlertView(config: $alertConfig)
                                .disabled(!hasDate)
                        }
                        
                        // MARK: Recurrence Section
                        RecurrenceSelectorView(
                            isRecurring: $isRecurring,
                            recurrenceType: $recurrenceType,
                            recurrenceInterval: $recurrenceInterval,
                            setRecurrenceEndDate: $setRecurrenceEndDate,
                            recurrenceEndDate: $recurrenceEndDate,
                            minimumRecurrenceDate: Binding(
                                get: { editableEvent?.endDate ?? Date() },
                                set: { _ in }
                            ),
                            expandedPicker: $expandedPicker
                        )
                        .disabled(!hasDate)
                                                
                        // MARK: Description Section
                        Section(header: Text("Description")) {
                            TextEditor(text: Binding(
                                get: { editableEvent?.notes ?? "" },
                                set: { newNotes in
                                    editableEvent?.notes = newNotes
                                }
                            ))
                            .frame(minHeight: 100)
                        }
                    }
                    .navigationTitle("Task Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .foregroundColor(Serenity.Colors.primary)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                guard let updated = currentEvent, let initial = initialEvent else { return }
                                
                                // If the event is recurring and no recurrence fields have changed
                                // and an occurrence is selected, then offer the update choice.
                                if initial.recurrenceType != .none &&
                                   occurrence != nil {
                                    showUpdateChoice = true
                                } else {
                                    onSave(updated)
                                    dismiss()
                                }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .foregroundColor((editableEvent?.title.isEmpty ?? true) || (currentEvent == initialEvent) ? Serenity.Colors.disabled : Serenity.Colors.primary)
                            .disabled((currentEvent?.title.isEmpty ?? true) || (currentEvent == initialEvent))
                        }
                    }
                    .confirmationDialog("Update Recurring Event", isPresented: $showUpdateChoice, titleVisibility: .hidden) {
                        if let updated = currentEvent, let original = initialEvent, occurrence != nil && !recurrenceFieldsChanged(updated: updated, initial: original){
                            Button("Update This Occurrence", role: .none) {
                                if let onSaveOccurrence = onSaveOccurrence {
                                    onSaveOccurrence(updated)
                                } else {
                                    onSave(updated)
                                }
                            }
                        }
                        Button("Update All Future Occurrences", role: .none) {
                            if let updated = currentEvent, let onSaveFutureOccurrences = onSaveFutureOccurrences {
                                onSaveFutureOccurrences(updated)
                            }
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("Would you like to update only this occurrence or the entire series?")
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .onAppear {
            // Initialize state only once when the view appears.
            if initialEvent == nil {
                initialNow = Date()
                initialEvent = event
                if let occ = occurrence {
                    var modified = event
                    modified.startDate = occ.occurrenceStart
                    modified.endDate = occ.occurrenceEnd
                    editableEvent = modified
                    hasDate = true
                } else {
                    editableEvent = event
                    hasDate = event.startDate != nil
                }
                alertConfig = Self.defaultAlertConfig(from: event)
                
                // Initialize recurrence state from the event.
                if event.recurrenceType != .none {
                    isRecurring = true
                    recurrenceType = event.recurrenceType
                    recurrenceInterval = event.recurrenceInterval
                    if let recEnd = event.recurrenceEndDate {
                        setRecurrenceEndDate = true
                        recurrenceEndDate = recEnd
                    } else {
                        setRecurrenceEndDate = false
                    }
                } else {
                    isRecurring = false
                }
            }
        }
    }
    
    /// Returns true if any recurrence field has been modified.
    private func recurrenceFieldsChanged(updated: Event, initial: Event) -> Bool {
        return updated.recurrenceType != initial.recurrenceType ||
               updated.recurrenceInterval != initial.recurrenceInterval ||
               updated.recurrenceEndDate != initial.recurrenceEndDate
    }
    
    /// Derives a default AlertConfiguration from the event’s notificationInterval.
    static func defaultAlertConfig(from event: Event) -> AlertConfiguration {
        var config = AlertConfiguration()
        if event.notificationId != nil {
            if let interval = event.notificationInterval {
                config.initiallyHadReminder = true
                config.assignReminder = true
                if interval == 15 {
                    config.alertOption = .fifteen
                } else if interval == 30 {
                    config.alertOption = .thirty
                } else if interval == 60 {
                    config.alertOption = .oneHour
                } else if interval == 120 {
                    config.alertOption = .twoHours
                } else if interval == 1440 {
                    config.alertOption = .oneDay
                } else {
                    config.alertOption = .custom
                    let intvl = interval
                    if intvl < 60 {
                        config.customTimeUnit = .minutes
                    } else if intvl < 1440 {
                        config.customTimeUnit = .hours
                    } else if intvl < 10080 {
                        config.customTimeUnit = .days
                    } else if intvl < 43200 {
                        config.customTimeUnit = .weeks
                    } else if intvl < 525600 {
                        config.customTimeUnit = .months
                    } else {
                        config.customTimeUnit = .years
                    }
                    config.customTimeValue = intvl / config.customTimeUnit.multiplier
                }
            } else {
                config.assignReminder = false
            }
        }
        return config
    }
}

#Preview {
    // Preview for non‑recurring event (confirmation dialog will not appear).
    EventDetailView(
        event: Event(
            id: UUID(),
            title: "Non‑Recurring Sample",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            notes: "Description",
            userId: UUID(),
            isCompleted: false,
            notificationId: UUID(),
            notificationInterval: 15
        ),
        occurrence: .constant(nil),
        onSave: { updatedEvent in
            // Update logic for non‑recurring event.
        },
        onSaveOccurrence: { updatedOccurrence in },
        onSaveFutureOccurrences: { updatedOccurrence in }
    )
    .withPreviewDependencies()
}

#Preview("Recurring Occurrence") {
    // Preview for recurring event with an occurrence.
    let recurringEvent = Event(
        id: UUID(),
        title: "Recurring Sample",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        notes: "Description",
        userId: UUID(),
        isCompleted: false,
        notificationId: UUID(),
        notificationInterval: 15,
        isOverdue: false,
        recurrenceType: .weekly,
        recurrenceInterval: 1,
        recurrenceEndDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
        recurrenceExcludedDates: []
    )
    let occurrence = EventOccurrence(
        event: recurringEvent,
        occurrenceStart: Date(),
        occurrenceEnd: Date().addingTimeInterval(3600)
    )
    
    return EventDetailView(
        event: recurringEvent,
        occurrence: .constant(occurrence),
        onSave: { updatedEvent in
            // Update logic for entire series.
        },
        onSaveOccurrence: { updatedOccurrence in
            // Update logic for this single occurrence.
        },
        onSaveFutureOccurrences: { updatedOccurrence in
            // Update logic for all future occurrence.
        }
    )
    .withPreviewDependencies()
}
