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
    
    var name: String {
        switch self {
        case .none:
            return "none"
        case .daily:
            return "daily"
        case .workingDays:
            return "workingDays"
        case .weekly:
            return "weekly"
        case .monthly:
            return "monthly"
        case .yearly:
            return "yearly"
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
    
    public static func fromString(_ input: String) -> RecurrenceType? {
        return RecurrenceType.allCases.first { $0.name == input }
    }
    
    public static var allCases: [RecurrenceType] {
        return [.none, .daily, .workingDays, .weekly, .monthly, .yearly]
    }
}

extension Event {
    ///  Returns the summary of the event
    var summary: String {
        let dateStr = startDate?.formatted(.dateTime) ?? "Undated"
        return "\(title) - \(dateStr) - recurrence: \(recurrenceType.displayName)"
    }
    
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
    
    func hasOccurrence(on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        // Must have valid start & end
        guard let eventStart = startDate, let eventEnd = endDate else {
            return false
        }
            
        // Non‑recurring: simply check span
        if recurrenceType == .none {
            return eventStart < dayEnd && eventEnd >= dayStart
        }
            
        // Recurring: candidate that “starts” on this day
        if let occ = candidateOccurrence(on: date),
            occ.end >= dayStart {
            return true
        }
            
        // Recurring: spill‑over from the previous day
        if let previousDay = calendar.date(byAdding: .day, value: -1, to: date),
            let prevOcc = candidateOccurrence(on: previousDay),
            prevOcc.end >= dayStart {
            return true
        }
            
        return false
    }
        
    /// Computes the single occurrence (start/end) for this event on the given date,
    /// or `nil` if there is no occurrence that day.
    private func candidateOccurrence(on date: Date) -> (start: Date, end: Date)? {
        guard let eventStart = startDate, let eventEnd = endDate else {
            return nil
        }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let eventDayStart = calendar.startOfDay(for: eventStart)
        let duration = eventEnd.timeIntervalSince(eventStart)
            
        var occurrence: (start: Date, end: Date)?
            
        switch recurrenceType {
        case .daily:
            let daysDiff = calendar.dateComponents([.day], from: eventDayStart, to: dayStart).day ?? -1
            if daysDiff >= 0 && daysDiff % recurrenceInterval == 0,
                let start = calendar.date(byAdding: .day, value: daysDiff, to: eventStart) {
                occurrence = (start: start, end: start.addingTimeInterval(duration))
            }
                
        case .workingDays:
            // if it's a weekend, no working‑day occurrence
            guard !calendar.isDateInWeekend(dayStart),
                    dayStart >= eventDayStart
            else { break }
            let comps = calendar.dateComponents([.hour, .minute, .second], from: eventStart)
            if let start = calendar.date(
                bySettingHour: comps.hour!,
                minute: comps.minute!,
                second: comps.second!,
                of: dayStart
            ) {
                occurrence = (start: start, end: start.addingTimeInterval(duration))
            }
                
        case .weekly:
            let weekdayStart = calendar.component(.weekday, from: eventStart)
            let weekdayTarget = calendar.component(.weekday, from: dayStart)
            guard weekdayStart == weekdayTarget else { break }
            let weeksDiff = calendar.dateComponents([.weekOfYear], from: eventDayStart, to: dayStart).weekOfYear ?? -1
            if weeksDiff >= 0 && weeksDiff % recurrenceInterval == 0,
                let start = calendar.date(byAdding: .weekOfYear, value: weeksDiff, to: eventStart) {
                occurrence = (start: start, end: start.addingTimeInterval(duration))
            }
            
        case .monthly:
            let monthsDiff = calendar.dateComponents([.month], from: eventDayStart, to: dayStart).month ?? -1
            if monthsDiff >= 0 && monthsDiff % recurrenceInterval == 0,
                let start = calendar.date(byAdding: .month, value: monthsDiff, to: eventStart),
                calendar.isDate(start, inSameDayAs: dayStart) {
                occurrence = (start: start, end: start.addingTimeInterval(duration))
            }
                
        case .yearly:
            let yearsDiff = calendar.dateComponents([.year], from: eventDayStart, to: dayStart).year ?? -1
            if yearsDiff >= 0 && yearsDiff % recurrenceInterval == 0,
                let start = calendar.date(byAdding: .year, value: yearsDiff, to: eventStart),
                calendar.isDate(start, inSameDayAs: dayStart) {
                occurrence = (start: start, end: start.addingTimeInterval(duration))
            }
                
        case .none:
            // We handle non‑recurring above.
            break
        }
            
        // Respect an overall recurrence‑end cutoff
        if let occ = occurrence,
            let recurrenceEnd = recurrenceEndDate,
            occ.start >= recurrenceEnd {
            return nil
        }
            
        // Respect excluded dates
        if let excluded = recurrenceExcludedDates,
            let occ = occurrence,
            excluded.contains(where: { calendar.isDate($0, inSameDayAs: occ.start) }) {
            return nil
        }
            
        return occurrence
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
        
        var occurrence: (start: Date, end: Date)?
        
        switch event.recurrenceType {
        case .daily:
            let daysDiff = calendar.dateComponents([.day], from: eventDayStart, to: dayStart).day ?? -1
            if daysDiff >= 0 && daysDiff % event.recurrenceInterval == 0,
               let occurrenceStart = calendar.date(byAdding: .day, value: daysDiff, to: eventStart) {
                occurrence = (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
            }
            
        case .weekly:
            let weekdayStart = calendar.component(.weekday, from: eventStart)
            let weekdayTarget = calendar.component(.weekday, from: dayStart)
            if weekdayStart == weekdayTarget {
                let weeksDiff = calendar.dateComponents([.weekOfYear], from: eventDayStart, to: dayStart).weekOfYear ?? -1
                if weeksDiff >= 0 && weeksDiff % event.recurrenceInterval == 0,
                   let occurrenceStart = calendar.date(byAdding: .weekOfYear, value: weeksDiff, to: eventStart) {
                    occurrence = (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
                }
            }
            
        case .monthly:
            let monthsDiff = calendar.dateComponents([.month], from: eventDayStart, to: dayStart).month ?? -1
            if monthsDiff >= 0 && monthsDiff % event.recurrenceInterval == 0,
               let occurrenceStart = calendar.date(byAdding: .month, value: monthsDiff, to: eventStart),
               calendar.isDate(occurrenceStart, inSameDayAs: dayStart) {
                occurrence = (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
            }
            
        case .yearly:
            let yearsDiff = calendar.dateComponents([.year], from: eventDayStart, to: dayStart).year ?? -1
            if yearsDiff >= 0 && yearsDiff % event.recurrenceInterval == 0,
               let occurrenceStart = calendar.date(byAdding: .year, value: yearsDiff, to: eventStart),
               calendar.isDate(occurrenceStart, inSameDayAs: dayStart) {
                occurrence = (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
            }
            
        case .workingDays:
            if !calendar.isDateInWeekend(dayStart) && dayStart >= eventDayStart {
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: eventStart)
                if let occurrenceStart = calendar.date(bySettingHour: timeComponents.hour!,
                                                       minute: timeComponents.minute!,
                                                       second: timeComponents.second!,
                                                       of: dayStart) {
                    occurrence = (start: occurrenceStart, end: occurrenceStart.addingTimeInterval(duration))
                }
            }
            
        case .none:
            return nil
        }
        
        // Ensure the candidate occurrence does not fall on or after the recurrence end date.
        if let occurrence = occurrence,
           let recurrenceEnd = event.recurrenceEndDate,
           occurrence.start >= recurrenceEnd {
            return nil
        }
        
        return occurrence
    }

    
    /// Returns all occurrences (from non-recurring and recurring events) that overlap the given date.
    func occurrences(on date: Date) -> [EventOccurrence] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        // Only consider events that at least end at 00:01 of the given day.
        let minValidEnd = calendar.date(byAdding: .minute, value: 1, to: dayStart)!
        var results: [EventOccurrence] = []
        
        // Include non-recurring events that span this day.
        for event in events {
            if let start = event.startDate, let end = event.endDate,
               start < dayEnd && end >= minValidEnd {
                results.append(EventOccurrence(event: event, occurrenceStart: start, occurrenceEnd: end))
            }
        }
        
        // For recurring events, compute candidate occurrences for the given day...
        for event in recurringEvents {
            // Occurrence that “starts” on this day.
            if let occ = candidateOccurrence(for: event, on: date),
               occ.end >= minValidEnd {
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
               prevOcc.end >= minValidEnd {
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
    
    func nextOccurrence(for event: Event, after date: Date) -> (startDate: Date, endDate: Date)? {
        // Ensure required properties exist.
        guard let eventStart = event.startDate, let eventEnd = event.endDate else { return nil }
        let duration = eventEnd.timeIntervalSince(eventStart)
        
        let calendar = Calendar.current
        // Normalize and round up provided data to fulfill the siffecient logic of strict after for given date
        let targetDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        
        // If there is no recurrence, there is no "next" occurrence.
        if event.recurrenceType == .none {
            return nil
        }
        
        var candidate: Date

        // Compute a candidate occurrence that is strictly after the given date.
        switch event.recurrenceType {
        case .daily:
            let intervalSeconds = 86400.0 * Double(event.recurrenceInterval)
            // Use floor + 1 so that even if date exactly equals an occurrence we advance.
            let secondsSinceStart = targetDate.timeIntervalSince(eventStart)
            let intervalsPassed = floor(secondsSinceStart / intervalSeconds) + 1
            candidate = eventStart.addingTimeInterval(intervalsPassed * intervalSeconds)
            
        case .weekly:
            let intervalSeconds = 7 * 86400.0 * Double(event.recurrenceInterval)
            let secondsSinceStart = targetDate.timeIntervalSince(eventStart)
            let intervalsPassed = floor(secondsSinceStart / intervalSeconds) + 1
            candidate = eventStart.addingTimeInterval(intervalsPassed * intervalSeconds)
            
        case .monthly:
            // Calculate how many whole months have passed then add one recurrence interval.
            let monthsDiff = calendar.dateComponents([.month], from: eventStart, to: targetDate).month ?? 0
            let intervalsPassed = (monthsDiff / event.recurrenceInterval) + 1
            guard let candidateDate = calendar.date(byAdding: .month, value: intervalsPassed * event.recurrenceInterval, to: eventStart) else { return nil }
            candidate = candidateDate
            
        case .yearly:
            let yearsDiff = calendar.dateComponents([.year], from: eventStart, to: targetDate).year ?? 0
            let intervalsPassed = (yearsDiff / event.recurrenceInterval) + 1
            guard let candidateDate = calendar.date(byAdding: .year, value: intervalsPassed * event.recurrenceInterval, to: eventStart) else { return nil }
            candidate = candidateDate
            
        case .workingDays:
            // For working days, align with the eventStart's time and then move to the next working day if needed.
            candidate = targetDate < eventStart ? eventStart : targetDate
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: eventStart)
            candidate = calendar.date(bySettingHour: timeComponents.hour!, minute: timeComponents.minute!, second: timeComponents.second!, of: candidate)!
            if candidate <= targetDate {
                repeat {
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate)!
                } while calendar.isDateInWeekend(candidate)
            }
            
        case .none:
            return nil
        }
        
        // Extra check: If candidate is not strictly after date (should not happen with the above math), advance it.
        if candidate <= targetDate {
            candidate = advanceCandidate(from: candidate, for: event, using: calendar)
        }
        
        // Skip excluded dates.
        let maxIterations = 1000
        var iterations = 0
        while let excludedDates = event.recurrenceExcludedDates,
              excludedDates.contains(where: { calendar.isDate($0, inSameDayAs: candidate) }) {
            iterations += 1
            if iterations > maxIterations { return nil }
            candidate = advanceCandidate(from: candidate, for: event, using: calendar)
            if candidate <= date {
                candidate = advanceCandidate(from: candidate, for: event, using: calendar)
            }
        }
        
        // Ensure the candidate falls before the recurrenceEndDate (if one exists).
        if let recurrenceEnd = event.recurrenceEndDate, candidate >= recurrenceEnd {
            return nil
        }
        
        return (startDate: candidate, endDate: candidate.addingTimeInterval(duration))
    }


    // Helper function to advance the candidate by one recurrence interval.
    func advanceCandidate(from date: Date, for event: Event, using calendar: Calendar) -> Date {
        switch event.recurrenceType {
        case .daily:
            return calendar.date(byAdding: .day, value: event.recurrenceInterval, to: date)!
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: event.recurrenceInterval, to: date)!
        case .monthly:
            return calendar.date(byAdding: .month, value: event.recurrenceInterval, to: date)!
        case .yearly:
            return calendar.date(byAdding: .year, value: event.recurrenceInterval, to: date)!
        case .workingDays:
            var candidate = calendar.date(byAdding: .day, value: 1, to: date)!
            while calendar.isDateInWeekend(candidate) {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate)!
            }
            return candidate
        case .none:
            return date
        }
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
