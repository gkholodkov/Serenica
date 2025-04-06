import Foundation
import CoreData

protocol EventRepositoryProtocol {
    func fetchNonRecurringEvents() -> [EventEntity]
    func fetchRecurringEvents() -> [EventEntity]
    func fetchCompletedEvents() -> [EventEntity]
    func addEvent(_ event: Event) throws
    func updateEvent(_ event: Event) throws
    func deleteEvent(withId id: UUID) throws
    func updateAuthService(_ newAuthService: AuthService)
    func updateContext(_ newContext: NSManagedObjectContext)
}
