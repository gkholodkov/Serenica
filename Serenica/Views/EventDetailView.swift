import SwiftUI

/// A bottom‑up sheet for viewing and editing an Event’s details.
struct EventDetailView: View {
    @State private var editableEvent: Event
    @State private var initialEvent: Event
    @State private var hasDate: Bool
    @State private var alertConfig: AlertConfiguration
    
    var onSave: (Event) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    init(event: Event, onSave: @escaping (Event) -> Void) {
        self.onSave = onSave
        _editableEvent = State(initialValue: event)
        _initialEvent = State(initialValue: event)
        _hasDate = State(initialValue: event.startDate != nil)
        _alertConfig = State(initialValue: Self.defaultAlertConfig(from: event))
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
                /// should never occur, but we have to unwrap the value
                config.assignReminder = false
            }
        }
        return config
    }
    
    // MARK: - View Body
    var body: some View {
        NavigationView {
            Form {
                // Title Section
                Section(header: Text("Title")) {
                    TextField("", text: $editableEvent.title)
                        .foregroundColor(Serenity.Colors.primary)
                }
                
                // Dates Section
                Section(header: Text("Dates")) {
                    Toggle("Assign a date", isOn: $hasDate)
                        .onChange(of: hasDate) { _, newValue in
                            if newValue {
                                let now = Date()
                                if editableEvent.startDate == nil {
                                    editableEvent.startDate = now
                                }
                                if editableEvent.endDate == nil {
                                    editableEvent.endDate = (editableEvent.startDate ?? now).addingTimeInterval(3600)
                                }
                            } else {
                                editableEvent.startDate = nil
                                editableEvent.endDate = nil
                                alertConfig.assignReminder = false
                            }
                        }
                    
                    if hasDate {
                        let now = Date()
                        let startBinding = Binding<Date>(
                            get: { editableEvent.startDate ?? now },
                            set: { newStart in
                                let clampedStart = max(newStart, now)
                                editableEvent.startDate = clampedStart
                                if let end = editableEvent.endDate, clampedStart > end {
                                    editableEvent.endDate = clampedStart.addingTimeInterval(3600)
                                }
                            }
                        )
                        let endBinding = Binding<Date>(
                            get: { editableEvent.endDate ?? ((editableEvent.startDate ?? now).addingTimeInterval(3600)) },
                            set: { newEnd in
                                let minEnd = editableEvent.startDate ?? now
                                editableEvent.endDate = max(newEnd, minEnd)
                            }
                        )
                        
                        DatePicker("Start", selection: startBinding, in: now..., displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End", selection: endBinding, in: (editableEvent.startDate ?? now)..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // Reminder Section (using our separate AlertView)
                Section(header: Text("Reminder")) {
                    AlertView(config: $alertConfig)
                        .disabled(!hasDate)
                }
                
                // Description Section
                Section(header: Text("Description")) {
                    TextEditor(text: $editableEvent.notes)
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
                        if !hasDate {
                            editableEvent.startDate = nil
                            editableEvent.endDate = nil
                        }
                        // Update the event’s reminder using the alert configuration.
                        editableEvent.notificationInterval = alertConfig.computedNotificationInterval
                        editableEvent.notificationId = !alertConfig.assignReminder ? nil : (alertConfig.initiallyHadReminder ? editableEvent.notificationId : UUID())
                        onSave(editableEvent)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .foregroundColor(editableEvent.title.isEmpty ? Serenity.Colors.disabled : Serenity.Colors.primary)
                    .disabled(editableEvent.title.isEmpty || editableEvent.isEqual(to: initialEvent))
                }
            }
        }
    }
}

#Preview {
    EventDetailView(
        event: Event(
            id: UUID(),
            title: "Sample Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            notes: "Sample Description",
            userId: UUID(),
            isCompleted: false,
            notificationId: UUID(),
            notificationInterval: 15
        ),
        onSave: { _ in }
    )
}
