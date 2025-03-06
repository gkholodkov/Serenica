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
    
    // States for sheet presentation and date picker expansion
    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var expandedPicker: ExpandedPicker? = nil
    
    /// Fixed lower bound captured when the view appears.
    @State private var initialNow: Date = Date()
    
    /// Computes the lower bound for the start date using a fixed value.
    var startDateMinimum: Date {
        initialNow
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
                                // Merge passed date with the fixed initial time
                                let candidate = passed.merge(withTimeFrom: initialNow)
                                startDate = candidate < initialNow ? initialNow : candidate
                                endDate = startDate.addingTimeInterval(3600)
                            } else {
                                alertConfig.assignReminder = false
                                isRecurring = false
                            }
                        }
                    
                    if hasDate {
                        // Start Date Row
                        VStack {
                            Button(action: {
                                withAnimation {
                                    expandedPicker = (expandedPicker == .start) ? nil : .start
                                }
                            }) {
                                HStack {
                                    Text("Start")
                                    Spacer()
                                    Text(startDate, style: .date)
                                        .foregroundColor(expandedPicker == .start ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                    Text(startDate, style: .time)
                                        .foregroundColor(expandedPicker == .start ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                }
                            }
                            if expandedPicker == .start {
                                WheelDatePicker(date: $startDate, minimumDate: startDateMinimum)
                                    .frame(height: 216)
                            }
                        }
                        
                        // End Date Row
                        VStack {
                            Button(action: {
                                withAnimation {
                                    expandedPicker = (expandedPicker == .end) ? nil : .end
                                }
                            }) {
                                HStack {
                                    Text("End")
                                    Spacer()
                                    Text(endDate, style: .date)
                                        .foregroundColor(expandedPicker == .end ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                    Text(endDate, style: .time)
                                        .foregroundColor(expandedPicker == .end ? Serenity.Colors.secondary : Serenity.Colors.primary)
                                }
                            }
                            if expandedPicker == .end {
                                WheelDatePicker(date: $endDate, minimumDate: startDate)
                                    .frame(height: 216)
                            }
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
                    minimumRecurrenceDate: $endDate,
                    expandedPicker: $expandedPicker
                )
                .disabled(!hasDate)
                
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
            // Capture a fixed "now" value when the view appears
            .onAppear {
                initialNow = Date()
                if let incoming = passedDate {
                    let calendar = Calendar.current
                    let comps = calendar.dateComponents([.hour, .minute, .second], from: incoming)
                    // If the incoming date has no time components, merge with the fixed initialNow
                    let merged: Date = (comps.hour == 0 && comps.minute == 0 && comps.second == 0)
                        ? incoming.merge(withTimeFrom: initialNow)
                        : incoming
                    let defaultStart = merged < initialNow ? initialNow : merged
                    startDate = defaultStart
                    endDate = defaultStart.addingTimeInterval(3600)
                    hasDate = true
                }
            }
            // Use the fixed initialNow to compute a stable lower bound for startDate
            .onChange(of: startDate) { _, newStart in
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: newStart)
                // Instead of calling Date() each time, we use the captured initialNow
                let lowerBound = calendar.isDate(newStart, inSameDayAs: initialNow) ? initialNow : dayStart
                let computedStart = max(newStart, lowerBound)
                if computedStart != startDate {
                    startDate = computedStart
                }
                if newStart > endDate {
                    endDate = calendar.date(byAdding: .hour, value: 1, to: newStart)!
                }
            }
            .onChange(of: endDate) { _, newEnd in
                let calendar = Calendar.current
                endDate = max(newEnd, startDate)
                if calendar.startOfDay(for: newEnd) > recurrenceEndDate {
                    recurrenceEndDate = calendar.date(byAdding: .day, value: 1, to: newEnd)!
                }
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

/*
#Preview {
    AddEventView(passedDate: .constant(Date()))
        .withPreviewDependencies()
}
*/
