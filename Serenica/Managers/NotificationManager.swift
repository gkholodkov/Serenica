import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager() // Singleton instance
    
    private init() {
        // Start observing events that need scheduling/updating.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEventNotification(_:)),
            name: .eventNeedsNotification,
            object: nil
        )
        // Observe deletion notifications.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEventDeletion(_:)),
            name: .eventRemovedNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleEventNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let event = userInfo["event"] as? Event,
              let notificationId = event.notificationId else {
            return
        }
        
        // Cancel any existing notification with the same identifier.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId.uuidString])
        
        scheduleNotification(for: event, with: notificationId)
    }
    
    @objc private func handleEventDeletion(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notificationId = userInfo["notificationId"] as? UUID else {
            return
        }
        // Remove the pending notification associated with the event.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId.uuidString])
        print("Notification removed for id: \(notificationId.uuidString)")
    }
    
    private func scheduleNotification(for event: Event, with notificationId: UUID) {
        // Make sure there is a valid event date.
        let minutes = event.notificationInterval ?? 0
        guard let eventDate = event.startDate?.addingTimeInterval(-1 * minutes * 60) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "Your event is starting soon."
        content.sound = .default
        
        // Create a trigger to fire the notification at the event's start date.
        let triggerDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: eventDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: notificationId.uuidString,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification.
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for event: \(event.title)")
            }
        }
    }
}
