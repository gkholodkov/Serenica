import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var eventStore: EventStore

    // Core event/task properties
    @State private var title = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var notes = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasDate: Bool

    // Instead of separate reminder state variables, we now use a single AlertConfiguration.
    @State private var alertConfig = AlertConfiguration()

    // MARK: - Initialization
    init(date: Date?) {
        _hasDate = State(initialValue: date != nil)
        _startDate = State(initialValue: date)
        _endDate = State(initialValue: date.map { $0.addingTimeInterval(3600) })
    }
    
    // MARK: - View Body
    var body: some View {
        NavigationView {
            Form {
                // Title Section
                Section(header: Text("Title")) {
                    TextField("", text: $title)                }
                
                // Date Section
                Section(header: Text("Date")) {
                    Toggle("Assign a date", isOn: $hasDate)
                        .onChange(of: hasDate) { _ , newValue in
                            if newValue && startDate == nil {
                                let now = Date()
                                startDate = now
                                endDate = now.addingTimeInterval(3600)
                            } else {
                                alertConfig.assignReminder = false
                            }
                        }
                    
                    if hasDate {
                        let now = Date()
                        let startBinding = Binding<Date>(
                            get: { startDate ?? now },
                            set: { newStart in
                                let clampedStart = max(newStart, now)
                                startDate = clampedStart
                                if let end = endDate, clampedStart > end {
                                    endDate = clampedStart.addingTimeInterval(3600)
                                }
                            }
                        )
                        let endBinding = Binding<Date>(
                            get: { endDate ?? ((startDate ?? now).addingTimeInterval(3600)) },
                            set: { newEnd in
                                let minEnd = startDate ?? now
                                endDate = max(newEnd, minEnd)
                            }
                        )
                        DatePicker("Start", selection: startBinding, in: now..., displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End", selection: endBinding, in: (startDate ?? now)..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // Reminder Section – using the separated AlertView.
                Section(header: Text("Reminder")) {
                    AlertView(config: $alertConfig)
                        .disabled(!hasDate) // Disable if no date is assigned.
                }
                
                // Description Section
                Section(header: Text("Description")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Left: Dismiss Button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(Serenity.Colors.primary)
                }
                // Right: Save Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { saveEvent() } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.isEmpty)
                    .foregroundColor(title.isEmpty ? Serenity.Colors.disabled : Serenity.Colors.primary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Save Event Function
    private func saveEvent() {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "User not found"
            showError = true
            return
        }
        
        let event = Event(
            title: title,
            startDate: hasDate ? startDate : nil,
            endDate: hasDate ? endDate : nil,
            notes: notes,
            userId: userId,
            isCompleted: false,
            notificationId: alertConfig.assignReminder ? UUID() : nil,
            notificationInterval: alertConfig.computedNotificationInterval
        )
        
        eventStore.addEvent(event)
        dismiss()
    }
}

#Preview {
    AddEventView(date: Date())
        .withPreviewDependencies()
}
