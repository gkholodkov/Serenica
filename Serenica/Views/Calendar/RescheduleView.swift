import SwiftUI

// MARK: - RescheduleView

/// A view that displays a completed Event’s details (read-only) and lets the user reschedule it.
/// Uses WeekCalendarGridView for selecting new start and end dates to stay consistent with the application style.
struct RescheduleView: View {
    let event: Event
    /// Closure called with the newly rescheduled event.
    var onReschedule: (Event) -> Void

    // MARK: - State Variables

    /// Controls whether the rescheduling UI is visible.
    @State private var isRescheduleMode = false
    /// The new start date (and time) selected by the user.
    @State private var newStartDate: Date = Date()
    /// The new end date (and time) selected by the user.
    @State private var newEndDate: Date = Date()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Read-Only Event Details
            Group {
                Text("Title:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                Text(event.title)
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.textPrimary)
                
                Text("Start Date:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                if let start = event.startDate {
                    Text(formattedDate(start))
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textPrimary)
                } else {
                    Text("N/A")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textPrimary)
                }
                
                Text("End Date:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                if let end = event.endDate {
                    Text(formattedDate(end))
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textPrimary)
                } else {
                    Text("N/A")
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textPrimary)
                }
                
                Text("Notes:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                Text(event.notes)
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.textPrimary)
            }
            
            Divider()
            
            // MARK: Rescheduling Section
            if isRescheduleMode {
                // --- New Start Date Section ---
                Text("Select New Start Date:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                DatePickerView(
                    selectedDate: $newStartDate,
                    specialDate: Date().startOfDay(),
                    onSelectDay: { selected in
                        // Merge the selected day with the current time portion.
                        newStartDate = merge(date: selected, time: newStartDate)
                        // Ensure newEndDate is not before newStartDate.
                        if newEndDate < newStartDate {
                            newEndDate = newStartDate
                        }
                    }
                )
                // Week grid views typically are compact; adjust height as needed.
                .frame(height: 60)
                
                Text("Select Start Time:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                DatePicker(
                    "",
                    selection: $newStartDate,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                
                // --- New End Date Section ---
                Text("Select New End Date:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                DatePickerView(
                    selectedDate: $newEndDate,
                    specialDate: newStartDate.startOfDay(),
                    onSelectDay: { selected in
                        // Allow selection only if the chosen date is not before newStartDate.
                        if selected >= newStartDate.startOfDay() {
                            newEndDate = merge(date: selected, time: newEndDate)
                        }
                    }
                )
                .frame(height: 60)
                
                Text("Select End Time:")
                    .font(Serenity.Typography.bodyText().weight(.semibold))
                    .foregroundColor(Serenity.Colors.textPrimary)
                DatePicker(
                    "",
                    selection: $newEndDate,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                
                Button(action: {
                    // Create a new Event with a new id and updated dates.
                    let rescheduledEvent = Event(
                        id: UUID(),
                        title: event.title,
                        startDate: newStartDate,
                        endDate: newEndDate,
                        notes: event.notes,
                        userId: event.userId,
                        isCompleted: false  // Rescheduled events are now pending.
                    )
                    onReschedule(rescheduledEvent)
                    isRescheduleMode = false
                }) {
                    Text("Confirm Reschedule")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Serenity.Colors.primary)
                .padding(.top, 8)
            } else {
                Button(action: {
                    // Initialize the new dates (using the event’s values or defaults).
                    newStartDate = event.startDate ?? Date()
                    newEndDate = event.endDate ?? newStartDate
                    if newStartDate < Date() { newStartDate = Date() }
                    if newEndDate < newStartDate { newEndDate = newStartDate }
                    isRescheduleMode = true
                }) {
                    Text("Reschedule")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Serenity.Colors.primary)
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    /// Formats a Date using a medium date and short time style.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Merges the date components (year, month, day) of `date` with the time components of `time`.
    private func merge(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        merged.second = timeComponents.second
        return calendar.date(from: merged) ?? date
    }
}

// MARK: - Preview

struct RescheduleView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample event for preview purposes.
        let sampleEvent = Event(
            id: UUID(),
            title: "Project Meeting",
            startDate: Date().addingTimeInterval(-3600), // 1 hour ago
            endDate: Date().addingTimeInterval(3600),      // 1 hour later
            notes: "Discuss project milestones.",
            userId: UUID(),
            isCompleted: true
        )
        
        RescheduleView(event: sampleEvent) { newEvent in
            print("Rescheduled Event:")
            print("New Start: \(newEvent.startDate?.description ?? "N/A")")
            print("New End: \(newEvent.endDate?.description ?? "N/A")")
        }
        .previewLayout(.sizeThatFits)
    }
}
