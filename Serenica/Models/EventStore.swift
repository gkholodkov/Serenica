//
//  EventStore.swift
//  Serenica
//
//  Created by Checkito12 on 18.01.25.
//

import CoreData
import SwiftUI

class EventStore: ObservableObject {
    @Published private(set) var events: [Event] = []
    @Published private(set) var completedEvents: [Event] = []
    @Published private(set) var undatedEvents: [Event] = []
    private let context: NSManagedObjectContext
    private var authService: AuthService
    
    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? CoreDataManager.shared.container.viewContext
        self.authService = AuthService(context: self.context)
        fetchEvents()
    }
    
    func updateAuthService(_ newAuthService: AuthService) {
        self.authService = newAuthService
        fetchEvents()
    }
    
    func addEvent(_ event: Event) {
        let entity = EventEntity(context: context)
        entity.id = event.id
        entity.title = event.title
        entity.startDate = event.startDate
        entity.endDate = event.endDate
        entity.notes = event.notes
        entity.isCompleted = event.isCompleted
        entity.notificationId = event.notificationId  // persist notificationId if provided
        entity.notificationInterval = event.notificationInterval ?? 0
        
        // Add relationship to current user
        if let userId = authService.currentUser?.id {
            let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            if let userEntity = try? context.fetch(userRequest).first {
                entity.user = userEntity
            }
        }
        
        do {
            try context.save()
            fetchEvents()
            
            // Post a notification so that a local notification is scheduled if a valid notificationId is provided.
            if event.notificationId != nil {
                NotificationCenter.default.post(
                    name: .eventNeedsNotification,
                    object: nil,
                    userInfo: ["event": event]
                )
            }
        } catch {
            print("Error saving event: \(error.localizedDescription)")
        }
    }
    
    func toggleEventCompletion(_ event: Event) {
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "id == %@", event.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                entity.isCompleted = !event.isCompleted
                try context.save()
                fetchEvents()
                // If the event has an associated notification, post a deletion notification.
                if let notificationId = entity.notificationId {
                    NotificationCenter.default.post(
                        name: .eventRemovedNotification,
                        object: nil,
                        userInfo: ["notificationId": notificationId]
                    )
                }

            }
        } catch {
            print("Error toggling event completion: \(error.localizedDescription)")
        }
    }
    
    func updateEvent(_ event: Event) {
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "id == %@", event.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                let initialNotificationId = entity.notificationId
                
                entity.title = event.title
                entity.startDate = event.startDate
                entity.endDate = event.endDate
                entity.notes = event.notes
                entity.isCompleted = event.isCompleted
                entity.notificationId = event.notificationId
                entity.notificationInterval = event.notificationInterval ?? 0
                
                try context.save()
                fetchEvents()
                
                // If the event has a valid notificationId, post a notification to re-schedule it.
                if event.notificationId != nil {
                    NotificationCenter.default.post(
                        name: .eventNeedsNotification,
                        object: nil,
                        userInfo: ["event": event]
                    )
                } else if (initialNotificationId != nil) {
                    NotificationCenter.default.post(
                        name: .eventRemovedNotification,
                        object: nil,
                        userInfo: ["notificationId": initialNotificationId!]
                    )
                }
            }
        } catch {
            print("Error updating event: \(error.localizedDescription)")
        }
    }
    
    func deleteEvent(withId id: UUID) {
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                context.delete(entity)
                try context.save()
                fetchEvents()
                // If the event has an associated notification, post a deletion notification.
                if let notificationId = entity.notificationId {
                    NotificationCenter.default.post(
                        name: .eventRemovedNotification,
                        object: nil,
                        userInfo: ["notificationId": notificationId]
                    )
                }

            }
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
        }
    }
    
    func fetchEvents() {
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.startDate, ascending: true)]
        
        if let userId = authService.currentUser?.id {
            // Active events with dates
            request.predicate = NSPredicate(
                format: "user.id == %@ AND isCompleted == NO AND startDate != nil",
                userId as CVarArg
            )
        }
        
        do {
            let entities = try context.fetch(request)
            events = entities.map { entity in
                Event(
                    id: entity.id ?? UUID(),
                    title: entity.title ?? "",
                    startDate: entity.startDate ?? Date(),
                    endDate: entity.endDate ?? Date(),
                    notes: entity.notes ?? "",
                    userId: entity.user?.id ?? UUID(),
                    isCompleted: entity.isCompleted,
                    notificationId: entity.notificationId,
                    notificationInterval: entity.notificationInterval
                )
            }
            
            // Fetch undated events
            let undatedRequest = NSFetchRequest<EventEntity>(entityName: "EventEntity")
            if let userId = authService.currentUser?.id {
                undatedRequest.predicate = NSPredicate(
                    format: "user.id == %@ AND isCompleted == NO AND startDate == nil",
                    userId as CVarArg
                )
            }
            undatedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.title, ascending: true)]
            
            let undatedEntities = try context.fetch(undatedRequest)
            undatedEvents = undatedEntities.map { entity in
                Event(
                    id: entity.id ?? UUID(),
                    title: entity.title ?? "",
                    startDate: entity.startDate,
                    endDate: entity.endDate,
                    notes: entity.notes ?? "",
                    userId: entity.user?.id ?? UUID(),
                    isCompleted: entity.isCompleted,
                    notificationId: entity.notificationId,
                    notificationInterval: entity.notificationInterval
                )
            }
            
            // Fetch completed events separately
            let completedRequest = NSFetchRequest<EventEntity>(entityName: "EventEntity")
            completedRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.startDate, ascending: true)]
            if let userId = authService.currentUser?.id {
                completedRequest.predicate = NSPredicate(format: "user.id == %@ AND isCompleted == YES", userId as CVarArg)
            }
            
            let completedEntities = try context.fetch(completedRequest)
            completedEvents = completedEntities.map { entity in
                Event(
                    id: entity.id ?? UUID(),
                    title: entity.title ?? "",
                    startDate: entity.startDate ?? Date(),
                    endDate: entity.endDate ?? Date(),
                    notes: entity.notes ?? "",
                    userId: entity.user?.id ?? UUID(),
                    isCompleted: entity.isCompleted,
                    notificationId: entity.notificationId,
                    notificationInterval: entity.notificationInterval
                )
            }
        } catch {
            print("Error fetching events: \(error.localizedDescription)")
        }
    }
    
    func refreshEvents() {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        
        // Gather the IDs of all events that have assigned dates.
        let eventIDs = events.map { $0.id }
        
        // Fetch all EventEntity objects corresponding to these events.
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "id IN %@", eventIDs)
        
        do {
            let entities = try context.fetch(request)
            for entity in entities {
                // Only update if both startDate and endDate are available and the startDate is before today.
                guard let originalStart = entity.startDate,
                      let originalEnd = entity.endDate,
                      !entity.isCompleted && originalStart < startOfToday else {
                    continue
                }
                
                // Extract the time components (hour, minute, second, nanosecond) from the original start date.
                let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: originalStart)
                
                // Build new start date components using today's date (startOfToday) but preserving the original time.
                var newStartComponents = calendar.dateComponents([.year, .month, .day], from: today)
                newStartComponents.hour = timeComponents.hour
                newStartComponents.minute = timeComponents.minute
                newStartComponents.second = timeComponents.second
                newStartComponents.nanosecond = timeComponents.nanosecond
                
                // Create the new start date.
                guard let newStartDate = calendar.date(from: newStartComponents) else {
                    continue
                }
                
                // Calculate the original event's duration.
                let duration = originalEnd.timeIntervalSince(originalStart)
                
                // Set the new end date based on the new start date plus the original duration.
                let newEndDate = newStartDate.addingTimeInterval(duration)
                
                // Update the entity's dates.
                entity.startDate = newStartDate
                entity.endDate = newEndDate
            }
            
            // Save all changes in one go.
            try context.save()
            
            // Refresh the local arrays by re-fetching events from Core Data.
            fetchEvents()
        } catch {
            print("Error refreshing events: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    func previewAddEvent(_ event: Event) {
        addEvent(event)
    }
    #endif
}
