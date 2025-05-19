import Foundation
import CoreData

protocol MessageRepositoryProtocol {
    func fetchMessages() -> [Message]
    func addMessage(_ message: Message)
    func addAgentMessage(_ message: Message)
    func deleteMessage(withId id: UUID)
    func clearAllMessages()
    func factCheckMessages()
}
