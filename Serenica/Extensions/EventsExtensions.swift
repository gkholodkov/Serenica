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
