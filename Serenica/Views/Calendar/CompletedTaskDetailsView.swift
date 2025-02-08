//
//  CompletedTaskDetailsView.swift
//  Serenica
//
//  Created by Checkito12 on 08.02.25.
//


import SwiftUI

// MARK: - TicketDetailsView

/// A view that displays a completed Event’s details in a read‑only format.
struct CompletedTaskDetailsView: View {
    let event: Event

    var body: some View {
        NavigationView {
            Form {
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
                    if let start = event.startDate {
                        Text(formattedDate(start))
                            .font(Serenity.Typography.bodyText())
                            .foregroundColor(Serenity.Colors.textPrimary)
                    } else {
                        Text("N/A")
                            .font(Serenity.Typography.bodyText())
                            .foregroundColor(Serenity.Colors.textPrimary)
                    }
                }
                
                HStack {
                    Text("End Date")
                    Spacer()
                    if let end = event.endDate {
                        Text(formattedDate(end))
                            .font(Serenity.Typography.bodyText())
                            .foregroundColor(Serenity.Colors.textPrimary)
                    } else {
                        Text("N/A")
                            .font(Serenity.Typography.bodyText())
                            .foregroundColor(Serenity.Colors.textPrimary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(Serenity.Typography.subtitle())
                        .foregroundColor(Serenity.Colors.textPrimary)
                    Text(event.notes)
                        .font(Serenity.Typography.bodyText())
                        .foregroundColor(Serenity.Colors.textPrimary)
                }

            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Helper Method
    
    /// Formats a Date using a medium date and short time style.
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct CompletedTaskDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample event for preview purposes.
        let sampleEvent = Event(
            id: UUID(),
            title: "Project Meeting",
            startDate: Date().addingTimeInterval(-3600), // 1 hour ago
            endDate: Date().addingTimeInterval(3600),      // 1 hour later
            notes: "Discuss project milestones.",
            userId: UUID(),
            isCompleted: true,
            notificationId: nil,
            notificationInterval: nil
        )
        CompletedTaskDetailsView(event: sampleEvent)
            .previewLayout(.sizeThatFits)
    }
}
