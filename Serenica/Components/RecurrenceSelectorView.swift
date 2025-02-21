//
//  RecurrenceSelectorView.swift
//  Serenica
//
//  Created by Checkito12 on 16.02.25.
//


import SwiftUI

struct RecurrenceSelectorView: View {
    @Binding var isRecurring: Bool
    @Binding var recurrenceType: RecurrenceType
    @Binding var recurrenceInterval: Int
    @Binding var setRecurrenceEndDate: Bool
    @Binding var recurrenceEndDate: Date

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
                    Stepper("Repeat every \(recurrenceInterval) \(recurrenceType.unitName)", value: $recurrenceInterval, in: 1...30)
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
                        in: Date()...Date.distantFuture,
                        displayedComponents: [.date]
                    )
                }
            }
        }
    }
}


#Preview {
    RecurrenceSelectorView(isRecurring: .constant(true), recurrenceType: .constant(.monthly), recurrenceInterval: .constant(2), setRecurrenceEndDate: .constant(false), recurrenceEndDate: .constant(Date()))
}
