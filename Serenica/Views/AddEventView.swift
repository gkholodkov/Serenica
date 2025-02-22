import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var eventStore: EventService

    // Core event/task properties
    @State private var title = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var notes = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasDate: Bool = false
    @State private var alertConfig = AlertConfiguration()
    
    // Recurrence-related state
    @State private var isRecurring: Bool = false
    @State private var recurrenceType: RecurrenceType = .daily
    @State private var recurrenceInterval: Int = 1
    @State private var setRecurrenceEndDate: Bool = false
    @State private var recurrenceEndDate: Date = Date().addingTimeInterval(86400)
    
    // Store the original passed-in date (from calendar)
    @Binding var passedDate: Date?
    
    // States for sheet presentation
    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false
    
    /// Computes the lower bound for the start date
    var startDateMinimum: Date {
        let calendar = Calendar.current
        if calendar.isDate(startDate, inSameDayAs: Date()) {
            return Date()
        } else {
            return calendar.startOfDay(for: startDate)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Title Section
                Section(header: Text("Title")) {
                    TextField("Enter event title", text: $title)
                }
                
                // Date Section
                Section(header: Text("Date")) {
                    Toggle("Assign a date", isOn: $hasDate)
                        .onChange(of: hasDate) { _, newValue in
                            if newValue, let passed = passedDate {
                                let candidate = passed.merge(withTimeFrom: Date())
                                startDate = candidate < Date() ? Date() : candidate
                                endDate = startDate.addingTimeInterval(3600)
                            } else {
                                alertConfig.assignReminder = false
                            }
                        }
                    
                    if hasDate {
                        Button(action: { showingStartDatePicker = true }) {
                            HStack {
                                Text("Start")
                                Spacer()
                                Text(startDate, style: .date)
                                Text(startDate, style: .time)
                            }
                        }
                        .sheet(isPresented: $showingStartDatePicker) {
                            DatePickerSheet(date: $startDate, minimumDate: startDateMinimum)
                        }
                        
                        Button(action: { showingEndDatePicker = true }) {
                            HStack {
                                Text("End")
                                Spacer()
                                Text(endDate, style: .date)
                                Text(endDate, style: .time)
                            }
                        }
                        .sheet(isPresented: $showingEndDatePicker) {
                            DatePickerSheet(date: $endDate, minimumDate: startDate)
                        }
                    }
                }
                
                // Reminder Section
                Section(header: Text("Reminder")) {
                    AlertView(config: $alertConfig)
                        .disabled(!hasDate)
                }
                
                // Recurrence Section
                RecurrenceSelectorView(
                    isRecurring: $isRecurring,
                    recurrenceType: $recurrenceType,
                    recurrenceInterval: $recurrenceInterval,
                    setRecurrenceEndDate: $setRecurrenceEndDate,
                    recurrenceEndDate: $recurrenceEndDate,
                    minimumRecurrenceDate: endDate
                )
                
                // Description Section
                Section(header: Text("Description")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(Serenity.Colors.primary)
                }
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
            .onChange(of: startDate) { _, newStart in
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: newStart)
                let lowerBound = calendar.isDate(newStart, inSameDayAs: Date()) ? Date() : dayStart
                startDate = max(newStart, lowerBound)
                if newStart > endDate {
                    endDate = calendar.date(byAdding: .hour, value: 1, to: newStart)!
                }
            }
        }
        .onAppear {
            if let incoming = passedDate {
                let now = Date()
                let calendar = Calendar.current
                let comps = calendar.dateComponents([.hour, .minute, .second], from: incoming)
                let merged: Date = (comps.hour == 0 && comps.minute == 0 && comps.second == 0)
                    ? incoming.merge(withTimeFrom: now)
                    : incoming
                let defaultStart = merged < now ? now : merged
                startDate = defaultStart
                endDate = defaultStart.addingTimeInterval(3600)
                hasDate = true
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
            notificationInterval: alertConfig.computedNotificationInterval,
            recurrenceType: isRecurring ? recurrenceType : .none,
            recurrenceInterval: isRecurring ? recurrenceInterval : 0,
            recurrenceEndDate: (isRecurring && setRecurrenceEndDate) ? recurrenceEndDate : nil,
            recurrenceExcludedDates: []
        )
        
        eventStore.addEvent(event)
        dismiss()
    }
}

#Preview {
    AddEventView(passedDate: .constant(Date()))
        .withPreviewDependencies()
}
