//
//  CalendarExtensions.swift
//  Serenica
//
//  Created by Checkito12 on 31.01.25.
//

import Foundation

extension Date {
    /// Returns the first moment of the month for this date.
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps)!
    }
    
    /// Returns the start of the week (Monday) for this date.
    func startOfWeek() -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Force Monday as the first day.
        let weekday = calendar.component(.weekday, from: self)
        // Calculate the number of days to subtract to get back to Monday.
        let daysToSubtract = (weekday + 7 - calendar.firstWeekday) % 7
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: self.startOfDay())!
    }
    
    /// Returns the number of days in the month for this date.
    func daysInMonth() -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: self)!
        return range.count
    }
    
    /// Returns the start of the day for this date.
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Returns an integer 1...7 (Sunday=1, Monday=2, etc.)
    func dayOfWeek() -> Int {
        Calendar.current.component(.weekday, from: self)
    }
    
    func previousMonth() -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: self) ?? self
    }
    
    func nextMonth() -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: self) ?? self
    }
    
    func nextWeek() -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: 1, to: self)!
    }
    
    func previousWeek() -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -1, to: self)!
    }
}
