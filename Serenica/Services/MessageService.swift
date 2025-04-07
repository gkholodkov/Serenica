import Foundation
import CoreData
import SwiftUI

@MainActor
class MessageService: ObservableObject {
    private let repository: MessageRepository
    private let aiAgent: AIEventAgent
    private(set) var context: NSManagedObjectContext
    
    @Published var messages: [Message] = []
    
    // MARK: - Initializers
    
    /// Designated initializer.
    init(context: NSManagedObjectContext,
         repository: MessageRepository = MessageRepository(context: CoreDataManager.shared.viewContext),
         aiAgent: AIEventAgent) {
        self.context = context
        // Important: Pass the same context into the repository.
        self.repository = MessageRepository(context: context)
        self.aiAgent = aiAgent
        fetchMessages()
    }
    
    // MARK: - Dependency Updates
    
    /// Call this if the view’s context changes.
    func updateContext(_ newContext: NSManagedObjectContext) {
        self.context = newContext
        repository.updateContext(newContext)
        fetchMessages()
    }
    
    /// Call this to update the auth service (for example, when the user signs in or out).
    func updateAuthService(_ newAuthService: AuthService) {
        repository.updateAuthService(newAuthService)
        fetchMessages()
    }
    
    // MARK: - Business Operations
    
    /// Sends a message from the user and then gets an AI-generated response.
    /// The conversation is persisted via the repository.
    func sendMessage(_ text: String) async {
        // Save the user's message.
        let userMessage = Message(content: text, isFromUser: true)
        repository.addMessage(userMessage)
        fetchMessages()
        
        // Delegate to the agent for handling the message (including event tool calls).
        await aiAgent.handleUserMessage(text) { [weak self] response in
            guard let self = self else { return }
            let agentMessage = Message(content: response, isFromUser: false)
            self.repository.addMessage(agentMessage)
            // Refresh published messages on the main thread.
            Task { @MainActor in
                self.fetchMessages()
            }
        }
    }
    
    /// Deletes a message with the given ID.
    func deleteMessage(withId id: UUID) {
        repository.deleteMessage(withId: id)
        fetchMessages()
    }
    
    /// Clears all messages.
    func clearMessages() {
        repository.clearAllMessages()
        messages.removeAll()
    }
    
    // MARK: - Data Refresh
    
    /// Retrieves messages from the repository and updates the published array.
    func fetchMessages() {
        messages = repository.fetchMessages()
    }
    
    // MARK: - Preview Helper
    #if DEBUG
    func previewAddMessage(_ message: Message) {
        repository.addMessage(message)
        fetchMessages()
    }
    #endif
}
