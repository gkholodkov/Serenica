import CoreData
import SwiftUI

class EventRepository : EventRepositoryProtocol {
    private var context: NSManagedObjectContext
    private var authService: AuthService

    init(context: NSManagedObjectContext? = nil, authService: AuthService? = nil) {
        self.context = context ?? CoreDataManager.shared.container.viewContext
        self.authService = authService ?? AuthService(context: self.context)
    }
    
    // MARK: - Fetch Methods
    
    func fetchNonRecurringEvents() -> [EventEntity] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.startDate, ascending: true)]
        request.predicate = NSPredicate(
            format: "user.id == %@ AND isCompleted == NO AND startDate != nil AND recurrenceType == %d",
            userId as CVarArg, RecurrenceType.none.rawValue
        )
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching non-recurring events: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchRecurringEvents() -> [EventEntity] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.startDate, ascending: true)]
        request.predicate = NSPredicate(
            format: "user.id == %@ AND isCompleted == NO AND recurrenceType != %d",
            userId as CVarArg, RecurrenceType.none.rawValue
        )
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching recurring events: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchCompletedEvents() -> [EventEntity] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.startDate, ascending: true)]
        request.predicate = NSPredicate(format: "user.id == %@ AND isCompleted == YES", userId as CVarArg)
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching completed events: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchUndatedEvents() -> [EventEntity] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EventEntity.title, ascending: true)]
        request.predicate = NSPredicate(
            format: "user.id == %@ AND isCompleted == NO AND startDate == nil",
            userId as CVarArg
        )
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching undated events: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - CRUD Methods
    
    func addEvent(_ event: Event) {
        guard let userId = authService.currentUser?.id else { return }
        
        let entity = EventEntity(context: self.context)
        entity.id = event.id
        entity.title = event.title
        entity.startDate = event.startDate
        entity.endDate = event.endDate
        entity.notes = event.notes
        entity.isCompleted = event.isCompleted
        entity.notificationId = event.notificationId
        entity.notificationInterval = event.notificationInterval ?? 0
        entity.isOverdue = event.isOverdue
            
        // Save recurrence fields.
        entity.recurrenceType = Int16(event.recurrenceType.rawValue)
        entity.recurrenceInterval = Int16(event.recurrenceInterval)
        entity.recurrenceEndDate = event.recurrenceEndDate
        entity.recurrenceExcludedDates = event.recurrenceExcludedDates as NSArray?
        
        // Link event to the current user.
        let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        if let userEntity = try? self.context.fetch(userRequest).first {
            entity.user = userEntity
        }
        
        do {
            try self.context.save()
        } catch {
            print("Error adding event: \(error.localizedDescription)")
        }
    }
    
    func updateEvent(_ event: Event) {
        do {
            let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
            request.predicate = NSPredicate(format: "id == %@", event.id as CVarArg)
            guard let entity = try self.context.fetch(request).first else { return }
            
            entity.title = event.title
            entity.startDate = event.startDate
            entity.endDate = event.endDate
            entity.notes = event.notes
            entity.isCompleted = event.isCompleted
            entity.notificationId = event.notificationId
            entity.notificationInterval = event.notificationInterval ?? 0
            entity.isOverdue = event.isOverdue
                
            // Update recurrence-related fields.
            entity.recurrenceType = Int16(event.recurrenceType.rawValue)
            entity.recurrenceInterval = Int16(event.recurrenceInterval)
            entity.recurrenceEndDate = event.recurrenceEndDate
            entity.recurrenceExcludedDates = event.recurrenceExcludedDates as NSArray?
            
            try self.context.save()
        } catch {
            print("Error updating event: \(error.localizedDescription)")
        }
    }
    
    func deleteEvent(withId id: UUID) {
        do {
            let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let entity = try self.context.fetch(request).first {
                self.context.delete(entity)
                try self.context.save()
            }
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
        }
    }
    
    func updateAuthService(_ newAuthService: AuthService) {
        self.authService = newAuthService
    }
    
    func updateContext(_ newContext: NSManagedObjectContext) {
        // Simply update the internal context.
        self.context = newContext
    }
}
