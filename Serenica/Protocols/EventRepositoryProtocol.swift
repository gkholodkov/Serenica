import Foundation
import CoreData

protocol EventRepositoryProtocol {
    func fetchNonRecurringEvents() -> [EventEntity]
    func fetchRecurringEvents() -> [EventEntity]
    func fetchCompletedEvents() -> [EventEntity]
    func addEvent(_ event: Event)
    func updateEvent(_ event: Event)
    func deleteEvent(withId id: UUID)
    func updateAuthService(_ newAuthService: AuthService)
    func updateContext(_ newContext: NSManagedObjectContext)
}
