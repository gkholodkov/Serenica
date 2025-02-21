//
//  EventRecurrenceManager.swift
//  Serenica
//
//  Handles all logic related to recurring events and date calculations.
//  It calculates the next occurrence for recurring events and
//  is also used by the OverdueManager for recurring events updates.
//

import Foundation
import CoreData

class EventRecurrenceManager {
    private let calendar = Calendar.current
    
    /// Calculates the next occurrence for a recurring event.
    func nextOccurrence(for entity: EventEntity) -> (startDate: Date, endDate: Date)? {
        guard let currentStart = entity.startDate,
              let currentEnd = entity.endDate else { return nil }
        
        let duration = currentEnd.timeIntervalSince(currentStart)
        let interval = Int(entity.recurrenceInterval)
        let recurrenceType = RecurrenceType(rawValue: Int(entity.recurrenceType)) ?? .none
        let excludedDates = (entity.recurrenceExcludedDates as? [Date]) ?? []
        
        func isExcluded(_ candidate: Date) -> Bool {
            return excludedDates.contains { calendar.isDate(candidate, inSameDayAs: $0) }
        }
        
        var candidate: Date?
        switch recurrenceType {
        case .daily:
            candidate = calendar.date(byAdding: .day, value: interval, to: currentStart)
            while let cand = candidate, isExcluded(cand) {
                candidate = calendar.date(byAdding: .day, value: interval, to: cand)
            }
        case .workingDays:
            candidate = calendar.date(byAdding: .day, value: 1, to: currentStart)
            while let cand = candidate, (calendar.isDateInWeekend(cand) || isExcluded(cand)) {
                candidate = calendar.date(byAdding: .day, value: 1, to: cand)
            }
        case .weekly:
            candidate = calendar.date(byAdding: .weekOfYear, value: interval, to: currentStart)
            while let cand = candidate, isExcluded(cand) {
                candidate = calendar.date(byAdding: .weekOfYear, value: interval, to: cand)
            }
        case .monthly:
            candidate = calendar.date(byAdding: .month, value: interval, to: currentStart)
            while let cand = candidate, isExcluded(cand) {
                candidate = calendar.date(byAdding: .month, value: interval, to: cand)
            }
        case .yearly:
            candidate = calendar.date(byAdding: .year, value: interval, to: currentStart)
            while let cand = candidate, isExcluded(cand) {
                candidate = calendar.date(byAdding: .year, value: interval, to: cand)
            }
        case .none:
            return nil
        }
        
        if let candidate = candidate {
            if let recurrenceEndDate = entity.recurrenceEndDate, candidate > recurrenceEndDate {
                return nil
            }
            return (startDate: candidate, endDate: candidate.addingTimeInterval(duration))
        }
        return nil
    }
}
