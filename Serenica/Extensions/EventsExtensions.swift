//
//  EventsExtensions.swift
//  Serenica
//
//  Created by Checkito12 on 06.02.25.
//

import Foundation

extension Notification.Name {
    static let eventNeedsNotification = Notification.Name("eventNeedsNotification")
    static let eventRemovedNotification = Notification.Name("eventRemovedNotification")
}

struct EventOccurrence: Identifiable {
    let id = UUID()
    let event: Event
    let occurrenceStart: Date
    let occurrenceEnd: Date
}


extension RecurrenceType: CaseIterable, Identifiable {
    public var id: RecurrenceType { self }
    
    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .daily:
            return "Daily"
        case .workingDays:
            return "Working Days"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }
    
    var unitName: String {
        switch self {
        case .none:
            return ""
        case .daily:
            return "day(s)"
        case .workingDays:
            return "working day"
        case .weekly:
            return "week(s)"
        case .monthly:
            return "month(s)"
        case .yearly:
            return "year(s)"
        }
    }
    
    public static var allCases: [RecurrenceType] {
        return [.none, .daily, .workingDays, .weekly, .monthly, .yearly]
    }
}

extension Event {
    /// Compares this Event with another Event field by field.
    /// - Parameter other: The Event to compare with.
    /// - Returns: `true` if all fields are equal, `false` otherwise.
    func isEqual(to other: Event) -> Bool {
        return self.id == other.id &&
               self.title == other.title &&
               self.startDate == other.startDate &&
               self.endDate == other.endDate &&
               self.notes == other.notes &&
               self.userId == other.userId &&
               self.isCompleted == other.isCompleted &&
               self.notificationId == other.notificationId &&
               self.notificationInterval == other.notificationInterval
    }
}


extension EventService {
    /// Computes the candidate occurrence for a recurring event on the given day.
    /// Returns nil if the recurrence rule doesn’t schedule an occurrence on that day.
    func candidateOccurrence(for event: Event, on date: Date) -> (start: Date, end: Date)? {
        guard let eventStart = event.startDate, let eventEnd = event.endDate else { return nil }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let eventDayStart = calendar.startOfDay(for: eventStart)
        let duration = eventEnd.timeIntervalSince(eventStart)
        
        switch event.recurrenceType {
        case .daily:
            let daysDiff = calendar.dateComponents([.day], from: eventDayStart, to: dayStart).day ?? -1
            if daysDiff >= 0 && daysDiff % event.recurrenceInterval == 0 {
                if let occurrenceStart = calendar.date(byAdding: .day, value: daysDiff, to: eventStart) {
                    return (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
                }
            }
        case .weekly:
            let weekdayStart = calendar.component(.weekday, from: eventStart)
            let weekdayTarget = calendar.component(.weekday, from: dayStart)
            if weekdayStart == weekdayTarget {
                let weeksDiff = calendar.dateComponents([.weekOfYear], from: eventDayStart, to: dayStart).weekOfYear ?? -1
                if weeksDiff >= 0 && weeksDiff % event.recurrenceInterval == 0 {
                    if let occurrenceStart = calendar.date(byAdding: .weekOfYear, value: weeksDiff, to: eventStart) {
                        return (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
                    }
                }
            }
        case .monthly:
            let monthsDiff = calendar.dateComponents([.month], from: eventDayStart, to: dayStart).month ?? -1
            if monthsDiff >= 0 && monthsDiff % event.recurrenceInterval == 0 {
                if let occurrenceStart = calendar.date(byAdding: .month, value: monthsDiff, to: eventStart),
                    calendar.isDate(occurrenceStart, inSameDayAs: dayStart) {
                    return (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
                }
            }
        case .yearly:
            let yearsDiff = calendar.dateComponents([.year], from: eventDayStart, to: dayStart).year ?? -1
            if yearsDiff >= 0 && yearsDiff % event.recurrenceInterval == 0 {
                if let occurrenceStart = calendar.date(byAdding: .year, value: yearsDiff, to: eventStart),
                    calendar.isDate(occurrenceStart, inSameDayAs: dayStart) {
                    return (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
                }
            }
        case .workingDays:
            // For working days, if the day isn’t a weekend and is after the event’s start:
            if !calendar.isDateInWeekend(dayStart) && dayStart >= eventDayStart {
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: eventStart)
                if let occurrenceStart = calendar.date(bySettingHour: timeComponents.hour!,
                                                        minute: timeComponents.minute!,
                                                        second: timeComponents.second!,
                                                        of: dayStart) {
                    return (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
                }
            }
        case .none:
            return nil
        }
        return nil
    }
    
    /// Returns all occurrences (from non-recurring and recurring events) that overlap the given date.
    func occurrences(on date: Date) -> [EventOccurrence] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        var results: [EventOccurrence] = []
        
        // Include non-recurring events that span this day.
        for event in events {
            if let start = event.startDate, let end = event.endDate, start < dayEnd && end > dayStart {
                results.append(EventOccurrence(event: event, occurrenceStart: start, occurrenceEnd: end))
            }
        }
        
        // For recurring events, compute candidate occurrences for the given day...
        for event in recurringEvents {
            // Occurrence that “starts” on this day.
            if let occ = candidateOccurrence(for: event, on: date) {
                // Check excluded dates.
                if let excluded = event.recurrenceExcludedDates,
                    excluded.contains(where: { calendar.isDate($0, inSameDayAs: occ.start) }) {
                    // Skip if excluded.
                } else {
                    results.append(EventOccurrence(event: event, occurrenceStart: occ.start, occurrenceEnd: occ.end))
                }
            }
            // Also, check for a spill-over occurrence from the previous day.
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: date),
                let prevOcc = candidateOccurrence(for: event, on: previousDay),
                prevOcc.end > dayStart {
                if let excluded = event.recurrenceExcludedDates,
                    excluded.contains(where: { calendar.isDate($0, inSameDayAs: prevOcc.start) }) {
                    // Skip if excluded.
                } else {
                    results.append(EventOccurrence(event: event, occurrenceStart: prevOcc.start, occurrenceEnd: prevOcc.end))
                }
            }
        }
        
        return results.sorted { $0.occurrenceStart < $1.occurrenceStart }
    }
    
    /// Checks whether a given recurring event occurs on the provided date.
    private func recurringOccurs(_ event: Event, on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        // Exclude the target day if it is in the event's excluded dates.
        if event.recurrenceExcludedDates?.contains(where: { calendar.isDate($0, inSameDayAs: targetDay) }) == true {
            return false
        }
        
        if let endDate = event.recurrenceEndDate, date >= endDate {
            return false
        }
        
        guard let eventStart = event.startDate else { return false }
        let startDay = calendar.startOfDay(for: eventStart)
        
        switch event.recurrenceType {
        case .daily:
            let daysDiff = calendar.dateComponents([.day], from: startDay, to: targetDay).day ?? -1
            return daysDiff >= 0 && daysDiff % event.recurrenceInterval == 0
            
        case .workingDays:
            if calendar.isDateInWeekend(targetDay) { return false }
            return targetDay >= startDay
            
        case .weekly:
            let weekdayStart = calendar.component(.weekday, from: eventStart)
            let weekdayTarget = calendar.component(.weekday, from: targetDay)
            if weekdayStart != weekdayTarget { return false }
            let weeksDiff = calendar.dateComponents([.weekOfYear], from: startDay, to: targetDay).weekOfYear ?? -1
            return weeksDiff >= 0 && weeksDiff % event.recurrenceInterval == 0
            
        case .monthly:
            let monthsDiff = calendar.dateComponents([.month], from: startDay, to: targetDay).month ?? -1
            if monthsDiff < 0 || monthsDiff % event.recurrenceInterval != 0 { return false }
            if let candidate = calendar.date(byAdding: .month, value: monthsDiff, to: eventStart) {
                return calendar.isDate(candidate, inSameDayAs: targetDay)
            }
            return false
            
        case .yearly:
            let yearsDiff = calendar.dateComponents([.year], from: startDay, to: targetDay).year ?? -1
            if yearsDiff < 0 || yearsDiff % event.recurrenceInterval != 0 { return false }
            if let candidate = calendar.date(byAdding: .year, value: yearsDiff, to: eventStart) {
                return calendar.isDate(candidate, inSameDayAs: targetDay)
            }
            return false
            
        case .none:
            return false
        }
    }
    
    /// Returns true if there is at least one recurring event occurrence on the given date.
    func hasRecurringEvent(on date: Date) -> Bool {
        return recurringEvents.contains { recurringOccurs($0, on: date) }
    }
    
    /// Returns an array of recurring events that occur on the given date.
    func recurringEvents(on date: Date) -> [Event] {
        return recurringEvents.filter { recurringOccurs($0, on: date) }
    }
    
    /// Helper methods calculating the next occurence after the given date
    func nextOccurrence(for event: Event, after date: Date) -> (startDate: Date, endDate: Date)? {
        // Ensure we have a valid start and end, and compute the duration.
        guard let eventStart = event.startDate,
              let eventEnd = event.endDate else { return nil }
        
        let duration = eventEnd.timeIntervalSince(eventStart)
        guard duration > 0 else { return nil }
        
        let calendar = Calendar.current
        var candidate: Date?
        
        switch event.recurrenceType {
        case .daily:
            let intervalSeconds = 86400.0 * Double(event.recurrenceInterval)
            if date < eventStart {
                candidate = eventStart
            } else {
                let secondsSinceStart = date.timeIntervalSince(eventStart)
                let intervalsPassed = ceil(secondsSinceStart / intervalSeconds)
                candidate = eventStart.addingTimeInterval(intervalsPassed * intervalSeconds)
                // If candidate is not strictly after date, advance by one interval.
                if let cand = candidate, cand <= date {
                    candidate = cand.addingTimeInterval(intervalSeconds)
                }
            }
            
        case .weekly:
            let intervalSeconds = 7 * 86400.0 * Double(event.recurrenceInterval)
            if date < eventStart {
                candidate = eventStart
            } else {
                let secondsSinceStart = date.timeIntervalSince(eventStart)
                let intervalsPassed = ceil(secondsSinceStart / intervalSeconds)
                candidate = eventStart.addingTimeInterval(intervalsPassed * intervalSeconds)
                if let cand = candidate, cand <= date {
                    candidate = cand.addingTimeInterval(intervalSeconds)
                }
            }
            
        case .monthly:
            if date < eventStart {
                candidate = eventStart
            } else {
                let monthsDiff = calendar.dateComponents([.month], from: eventStart, to: date).month ?? 0
                let intervalsPassed = monthsDiff / event.recurrenceInterval
                candidate = calendar.date(byAdding: .month, value: intervalsPassed * event.recurrenceInterval, to: eventStart)
                if let cand = candidate, cand <= date {
                    candidate = calendar.date(byAdding: .month, value: event.recurrenceInterval, to: cand)
                }
            }
            
        case .yearly:
            if date < eventStart {
                candidate = eventStart
            } else {
                let yearsDiff = calendar.dateComponents([.year], from: eventStart, to: date).year ?? 0
                let intervalsPassed = yearsDiff / event.recurrenceInterval
                candidate = calendar.date(byAdding: .year, value: intervalsPassed * event.recurrenceInterval, to: eventStart)
                if let cand = candidate, cand <= date {
                    candidate = calendar.date(byAdding: .year, value: event.recurrenceInterval, to: cand)
                }
            }
            
        case .workingDays:
            // For working days, preserve the original time-of-day.
            let candidateDate = date < eventStart ? eventStart : date
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: eventStart)
            candidate = calendar.date(bySettingHour: timeComponents.hour!, minute: timeComponents.minute!, second: timeComponents.second!, of: candidateDate)
            // Ensure candidate is strictly after the provided date.
            while let cand = candidate, (cand <= date || calendar.isDateInWeekend(cand)) {
                candidate = calendar.date(byAdding: .day, value: 1, to: cand)
                if let newCand = candidate {
                    candidate = calendar.date(bySettingHour: timeComponents.hour!, minute: timeComponents.minute!, second: timeComponents.second!, of: newCand)
                }
            }
            
        case .none:
            return nil
        }
        
        // Skip any candidate dates that are excluded.
        let maxIterations = 1000
        var iterations = 0
        while let cand = candidate,
              event.recurrenceExcludedDates?.contains(where: { calendar.isDate($0, inSameDayAs: cand) }) == true {
            iterations += 1
            if iterations > maxIterations { return nil }
            
            switch event.recurrenceType {
            case .daily:
                candidate = calendar.date(byAdding: .day, value: event.recurrenceInterval, to: cand)
            case .weekly:
                candidate = calendar.date(byAdding: .day, value: event.recurrenceInterval * 7, to: cand)
            case .monthly:
                candidate = calendar.date(byAdding: .month, value: event.recurrenceInterval, to: cand)
            case .yearly:
                candidate = calendar.date(byAdding: .year, value: event.recurrenceInterval, to: cand)
            case .workingDays:
                candidate = calendar.date(byAdding: .day, value: 1, to: cand)
                while let newCandidate = candidate, calendar.isDateInWeekend(newCandidate) {
                    candidate = calendar.date(byAdding: .day, value: 1, to: newCandidate)
                }
            case .none:
                return nil
            }
        }
        
        // Ensure the candidate occurs before the recurrence's end (if one exists).
        if let cand = candidate, let recurrenceEndDate = event.recurrenceEndDate, cand >= recurrenceEndDate {
            return nil
        }
        
        if let cand = candidate {
            let candidateEnd = cand.addingTimeInterval(duration)
            return (startDate: cand, endDate: candidateEnd)
        }
        
        return nil
    }


    
    /// Returns true if at least one recurring event occurs after the provided date (and before its recurrence end date, if specified).
    func hasRecurringEventsAfter(_ date: Date) -> Bool {
        return recurringEvents.contains { event in
            nextOccurrence(for: event, after: date) != nil
        }
    }

    /// Checks whether a given event occurs (spans) the provided date.
    private func occurs(_ event: Event, on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        guard let eventStart = event.startDate,
              let eventEnd = event.endDate else { return false }
        
        let startDay = calendar.startOfDay(for: eventStart)
        let endDay = calendar.startOfDay(for: eventEnd)
        
        return (min(startDay, endDay)...max(startDay, endDay)).contains(targetDay)
    }
    
    /// Returns true if the given date (assumed to be start-of-day) overlaps any non-recurring event.
    func hasEvents(on date: Date) -> Bool {
        return events.contains { occurs($0, on: date) }
    }
    
    /// Returns an array of non-recurring events that occur on the given date.
    func events(on date: Date) -> [Event] {
        return events.filter { occurs($0, on: date) }
    }
    
    func hasOccurrence(on date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return occurrences(on: date).contains { occurrence in
            let startDay = calendar.startOfDay(for: occurrence.occurrenceStart)
            let endDay = calendar.startOfDay(for: occurrence.occurrenceEnd)
            // Check that targetDay is between the start and end day (inclusive)
            return (min(startDay, endDay)...max(startDay, endDay)).contains(targetDay)
        }
    }
}
