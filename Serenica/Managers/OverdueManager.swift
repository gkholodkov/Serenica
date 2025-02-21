//
//  OverdueManager.swift
//  Serenica
//
//  Created by Checkito12 on 15.02.25.
//


//
//  OverdueManager.swift
//  Serenica
//
//  This manager is responsible for updating overdue events.
//  It separates logic for non-recurring events from recurring events.
//  For recurring events, it leverages the EventRecurrenceManager.
//

import Foundation
import CoreData

class OverdueManager {
    private let calendar = Calendar.current

    /// Updates overdue logic for non-recurring events.
    func updateNonRecurringEvents(context: NSManagedObjectContext) -> Bool {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "isCompleted == NO AND recurrenceType == %d", RecurrenceType.none.rawValue)
        
        var didChange = false
        if let events = try? context.fetch(request) {
            for entity in events {
                guard let origStart = entity.startDate, let origEnd = entity.endDate else { continue }
                
                if origEnd < now {
                    if !entity.isOverdue {
                        entity.isOverdue = true
                        didChange = true
                    }
                    // If the event started before today, shift it to start today while preserving its time.
                    if origStart < startOfToday {
                        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: origStart)
                        var newStartComponents = calendar.dateComponents([.year, .month, .day], from: now)
                        newStartComponents.hour = timeComponents.hour
                        newStartComponents.minute = timeComponents.minute
                        newStartComponents.second = timeComponents.second
                        newStartComponents.nanosecond = timeComponents.nanosecond
                        
                        if let newStart = calendar.date(from: newStartComponents), entity.startDate != newStart {
                            let duration = origEnd.timeIntervalSince(origStart)
                            entity.startDate = newStart
                            entity.endDate = newStart.addingTimeInterval(duration)
                            didChange = true
                        }
                    }
                } else if origStart < startOfToday && origEnd > now {
                    if entity.startDate != startOfToday {
                        entity.startDate = startOfToday
                        didChange = true
                    }
                }
            }
        }
        return didChange
    }
    
    /// Updates recurring events’ dates.
    func updateRecurringEvents(context: NSManagedObjectContext, recurrenceManager: EventRecurrenceManager) -> Bool {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "isCompleted == NO AND recurrenceType != %d", RecurrenceType.none.rawValue)
        
        var didChange = false
        if let events = try? context.fetch(request) {
            for entity in events {
                guard let origStart = entity.startDate, let origEnd = entity.endDate else { continue }
                
                // If the event’s end time is today but already passed, mark as overdue.
                if calendar.isDate(origEnd, inSameDayAs: now) && origEnd < now {
                    if !entity.isOverdue {
                        entity.isOverdue = true
                        didChange = true
                    }
                }
                // If the event ended before today, advance it to the next occurrence.
                else if origEnd < startOfToday {
                    let duration = origEnd.timeIntervalSince(origStart)
                    // Extract the time components from the original start date.
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: origStart)
                    // Build a new date based on today's date and the original time.
                    var newStartComponents = calendar.dateComponents([.year, .month, .day], from: now)
                    newStartComponents.hour = timeComponents.hour
                    newStartComponents.minute = timeComponents.minute
                    newStartComponents.second = timeComponents.second
                    newStartComponents.nanosecond = timeComponents.nanosecond
                    guard let newStart = calendar.date(from: newStartComponents) else { continue }
                    let newEnd = newStart.addingTimeInterval(duration)
                    
                    // Create a copy of the overdue recurring event.
                    // This copy represents the occurrence that just passed.
                    let overdueCopy = EventEntity(context: context)
                    overdueCopy.id = UUID() // New unique ID for the copy.
                    overdueCopy.title = entity.title
                    overdueCopy.startDate = newStart
                    overdueCopy.endDate = newEnd
                    overdueCopy.notes = entity.notes
                    overdueCopy.isCompleted = false
                    overdueCopy.notificationId = entity.notificationId
                    overdueCopy.notificationInterval = entity.notificationInterval
                    overdueCopy.isOverdue = true
                    // Mark as non-recurring since this is a copy of a past occurrence.
                    overdueCopy.recurrenceType = Int16(RecurrenceType.none.rawValue)
                    overdueCopy.recurrenceInterval = 0
                    overdueCopy.recurrenceEndDate = nil
                    overdueCopy.recurrenceExcludedDates = nil
                    // Link the copy to the same user.
                    overdueCopy.user = entity.user
                    didChange = true
                    if let nextOccurrence = recurrenceManager.nextOccurrence(for: entity) {
                        entity.startDate = nextOccurrence.startDate
                        entity.endDate = nextOccurrence.endDate
                        entity.isOverdue = false
                        didChange = true
                    } else {
                        // Remove the event if no next occurrence is found.
                        context.delete(entity)
                        didChange = true
                    }
                }
            }
        }
        return didChange
    }
    
    /// Updates all overdue events by handling both non-recurring and recurring events.
    func updateAllOverdueEvents(context: NSManagedObjectContext, recurrenceManager: EventRecurrenceManager) throws {
        let nonRecurringChanged = updateNonRecurringEvents(context: context)
        let recurringChanged = updateRecurringEvents(context: context, recurrenceManager: recurrenceManager)
        if nonRecurringChanged || recurringChanged {
            try context.save()
        }
    }
}
