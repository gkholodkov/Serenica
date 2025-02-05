//
//  AddEventView.swift
//  Serenica
//
//  Created by Checkito12 on 18.01.25.
//

import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var eventStore: EventStore

    @State private var title = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var notes = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasDate: Bool

    init(date: Date?) {
        _hasDate = State(initialValue: date != nil)
        _startDate = State(initialValue: date)
        _endDate = State(initialValue: date.map { $0.addingTimeInterval(3600) })
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Event Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Toggle("Has specific date", isOn: $hasDate)
                        .onChange(of: hasDate) { oldValue, newValue in
                            if newValue && startDate == nil {
                                let now = Date()
                                startDate = now
                                endDate = now.addingTimeInterval(3600)
                            }
                        }
                    
                    if hasDate {
                        // Capture the current time for clamping
                        let now = Date()
                        
                        // Binding for the start date: clamp to now if necessary and adjust end date if needed.
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
                        
                        // Binding for the end date: always ensure it's not earlier than startDate.
                        let endBinding = Binding<Date>(
                            get: { endDate ?? ((startDate ?? now).addingTimeInterval(3600)) },
                            set: { newEnd in
                                let minEnd = startDate ?? now
                                let clampedEnd = max(newEnd, minEnd)
                                endDate = clampedEnd
                            }
                        )
                        
                        DatePicker("Start", selection: startBinding, in: now..., displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End", selection: endBinding, in: (startDate ?? now)..., displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Serenity.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        saveEvent()
                    }
                    .disabled(title.isEmpty)
                    .foregroundColor(title.isEmpty ?
                                     Serenity.Colors.textSecondary :
                                     Serenity.Colors.primary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
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
            userId: userId
        )
        
        eventStore.addEvent(event)
        dismiss()
    }
}

#Preview {
    AddEventView(date: Date())
        .withPreviewDependencies()
}
