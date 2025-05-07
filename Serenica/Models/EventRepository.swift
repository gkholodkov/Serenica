import CoreData
import SwiftUI

class EventRepository : EventRepositoryProtocol {
    private var context: NSManagedObjectContext
    private var authService: AuthService

    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? CoreDataManager.shared.container.viewContext
        self.authService = AuthService(context: self.context)
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
    
    func addEvent(_ event: Event) throws {

        let entity = EventEntity(context: context)
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
        if let userId = self.authService.currentUser?.id {
            let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            if let userEntity = try? context.fetch(userRequest).first {
                entity.user = userEntity
            }
        }
        try context.save()
    }
    
    func updateEvent(_ event: Event) throws {
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "id == %@", event.id as CVarArg)
        guard let entity = try context.fetch(request).first else { return }
        
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
        
        try context.save()
    }
    
    func deleteEvent(withId id: UUID) throws {
        let request = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let entity = try context.fetch(request).first {
            context.delete(entity)
            try context.save()
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
