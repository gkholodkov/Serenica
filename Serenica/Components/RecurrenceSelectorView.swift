import SwiftUI

struct RecurrenceSelectorView: View {
    @Binding var isRecurring: Bool
    @Binding var recurrenceType: RecurrenceType
    @Binding var recurrenceInterval: Int
    @Binding var setRecurrenceEndDate: Bool
    @Binding var recurrenceEndDate: Date

    /// New property to enforce that the recurrence end date is not before the event’s end date.
    var minimumRecurrenceDate: Date = Date()

    var body: some View {
        Section(header: Text("Recurring")) {
            Toggle("Repeat Event", isOn: $isRecurring)
            
            if isRecurring {
                Picker("Frequency", selection: $recurrenceType) {
                    // Exclude .none from options.
                    ForEach(RecurrenceType.allCases.filter { $0 != .none }, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
                .onChange(of: recurrenceType) { _, newValue in
                    // For workingDays, enforce a recurrenceInterval of 1.
                    if newValue == .workingDays {
                        recurrenceInterval = 1
                    }
                }
                
                if recurrenceType != .workingDays {
                    Stepper("Repeat every \(recurrenceInterval) \(recurrenceType.unitName)",
                            value: $recurrenceInterval, in: 1...30)
                } else {
                    // For workingDays, just display the fixed interval.
                    Text("Repeat every \(recurrenceType.unitName)")
                        .foregroundColor(Serenity.Colors.secondary)
                }
                
                Toggle("End Repeat", isOn: $setRecurrenceEndDate)
                
                if setRecurrenceEndDate {
                    DatePicker(
                        "End Date",
                        selection: $recurrenceEndDate,
                        in: minimumRecurrenceDate...Date.distantFuture,
                        displayedComponents: [.date]
                    )
                    .onAppear {
                        // Ensure the recurrenceEndDate isn't below the minimum.
                        if recurrenceEndDate < minimumRecurrenceDate {
                            recurrenceEndDate = minimumRecurrenceDate
                        }
                    }
                    .onChange(of: minimumRecurrenceDate) { _, newMin in
                        if recurrenceEndDate < newMin {
                            recurrenceEndDate = newMin
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RecurrenceSelectorView(
        isRecurring: .constant(true),
        recurrenceType: .constant(.monthly),
        recurrenceInterval: .constant(2),
        setRecurrenceEndDate: .constant(true),
        recurrenceEndDate: .constant(Date().addingTimeInterval(86400)),
        minimumRecurrenceDate: Date().addingTimeInterval(3600)
    )
}
