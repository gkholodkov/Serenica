//
//  EventNotificationService.swift
//  Serenica
//
//  Manages scheduling and removal of local notifications for events.
//  This service decouples notification logic from the business and data layers.
//

import Foundation
import SwiftUI

class EventNotificationService {
    // Schedule a notification for the given event.
    func scheduleNotification(for event: Event, on date: Date) {
        print ("Reached the event notification service; scheduling notification for \(event) on \(date)")
        NotificationCenter.default.post(
            name: .eventNeedsNotification,
            object: nil,
            userInfo: ["event": event, "date": date]
        )
    }
    
    // Remove an existing notification for the given event.
    func removeNotification(for notificationId: UUID) {
        NotificationCenter.default.post(
            name: .eventRemovedNotification,
            object: nil,
            userInfo: ["notificationId": notificationId]
        )
    }
}
