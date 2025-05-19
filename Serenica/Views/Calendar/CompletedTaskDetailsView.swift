import SwiftUI

struct CompletedTaskDetailsView: View {
    @State private var isRescheduling = false
    @Environment(\.dismiss) private var dismiss

    let event: Event
    let onReschedule: (Event) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    detailsSection
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                       isRescheduling = true
                    } label: {
                        Image(systemName: "arrow.turn.up.left")
                    }
                    .foregroundColor(Serenity.Colors.primary)
                }
            }
            .confirmationDialog("Reschedule Event", isPresented: $isRescheduling, titleVisibility: .hidden) {
                Button("Yes", role: .none) {
                    saveRescheduleChanges()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let startText = event.startDate != nil
                ? " on \(formattedDate(availableRescheduleDates(for: event).start!))"
                : ""
                Text("Do you want to reschedule this event\(startText)?")
            }
        }
    }

    // MARK: - UI Sections

    private var detailsSection: some View {
        Section(header: Text("Details")) {
            HStack {
                Text("Title")
                Spacer()
                Text(event.title)
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.textPrimary)
            }

            HStack {
                Text("Start Date")
                Spacer()
                Text(event.startDate.map(formattedDate) ?? "N/A")
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.textPrimary)
            }

            HStack {
                Text("End Date")
                Spacer()
                Text(event.endDate.map(formattedDate) ?? "N/A")
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.textPrimary)
            }
            
            HStack {
                Text("Notes")
                Spacer()
                Text(event.notes)
                    .font(Serenity.Typography.bodyText())
                    .foregroundColor(Serenity.Colors.textPrimary)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func saveRescheduleChanges() {
        var updatedEvent = event
        let (start, end) = availableRescheduleDates(for: event)
        updatedEvent.startDate = start
        updatedEvent.endDate = end
        updatedEvent.isCompleted = false
        onReschedule(updatedEvent)
        isRescheduling = false
    }
    
    private func availableRescheduleDates(for event: Event) -> (start: Date?, end: Date?) {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let originalStartDate = event.startDate, let originalEndDate = event.endDate else {
            return (nil, nil)
        }
        
        if originalStartDate <= today || originalEndDate <= today {
            // Calculate the original time components from start date
            let startComponents = calendar.dateComponents([.hour, .minute, .second], from: originalStartDate)
            
            // Create a new date with today’s date and original start time components
            let nextPossibleStart = calendar.nextDate(after: now, matching: startComponents, matchingPolicy: .nextTime)!
            
            // Calculate original duration
            let duration = originalEndDate.timeIntervalSince(originalStartDate)
            
            // Set the updated start and end date based on calculated nextPossibleStart
            return (nextPossibleStart, nextPossibleStart.addingTimeInterval(duration))
        }
        
        return (event.startDate, event.endDate)
    }
}

// MARK: - Preview

struct CompletedTaskDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEvent = Event(
            id: UUID(),
            title: "Project Meeting",
            startDate: Date().addingTimeInterval(3600),
            endDate: Date().addingTimeInterval(7200),
            notes: "Discuss project milestones milesotnes milestones milestones milestones milestones milestones milestones milestones milestones milestones.",
            userId: UUID(),
            isCompleted: true,
            notificationId: nil,
            notificationInterval: nil
        )

        CompletedTaskDetailsView(
            event: sampleEvent,
            onReschedule: { _ in }
        )
    }
}
