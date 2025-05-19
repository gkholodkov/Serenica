import Foundation
import CoreData
import SwiftUI

@MainActor
class MessageService: ObservableObject {
    private let repository: MessageRepository
    private let aiAgent: AIAppAgent
    private(set) var context: NSManagedObjectContext
    
    @Published var messages: [Message] = []
    @Published var isAgentTyping: Bool = false
    
    // MARK: - Initializers
    
    /// Designated initializer.
    init(context: NSManagedObjectContext,
         authService: AuthService? = nil,
         repository: MessageRepository = MessageRepository(context: CoreDataManager.shared.viewContext),
         aiAgent: AIAppAgent) {
        self.context = context
        // Important: Pass the same context into the repository.
        self.repository = MessageRepository(context: context, authService: authService)
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
        aiAgent.updateAuthService(newAuthService)
        fetchMessages()
    }
    
    // MARK: - Business Operations
    
    /// Sends first message if needed. Starts converrsation, if appropriate
    /// It shouldn't be handled by the repository, or anyhow affect it
    func startConversation() async {
        if !messages.isEmpty && messages.last!.timestamp.isNotEarlierThanNHoursBeforeNow() { return }
        
        var firstMessageText: String = ""
        if messages.isEmpty {
            firstMessageText = "You're speaking to the user for the first time. Introduce yourself, a smoothly start a conversation."
        } else if messages.last?.timestamp.isNotEarlierThanNHoursBeforeNow() == false {
            firstMessageText = "You haven't been speaking to the user for couple hours. Send him gentle and subtle reminder that you're there for them."
        }
        
        isAgentTyping = true
        
        // Delegate to the agent for handling the message (including event tool calls).
        await aiAgent.handleUserMessage(firstMessageText) { [weak self] response in
            guard let self = self else { return }
            let agentMessage = Message(content: response, isFromUser: false)
            repository.addAgentMessage(agentMessage)
            // Refresh published messages on the main thread.
            Task { @MainActor in
                self.isAgentTyping = false
                self.fetchMessages()
            }
        }
    }
    
    /// Sends a message from the user and then gets an AI-generated response.
    /// The conversation is persisted via the repository.
    func sendMessage(_ text: String) async {
        // Save the user's message.
        let userMessage = Message(content: text, isFromUser: true)
        repository.addMessage(userMessage)
        fetchMessages()
        isAgentTyping = true
        
        // Delegate to the agent for handling the message (including event tool calls).
        await aiAgent.handleUserMessage(text) { [weak self] response in
            guard let self = self else { return }
            let agentMessage = Message(content: response, isFromUser: false)
            repository.addAgentMessage(agentMessage)
            // Refresh published messages on the main thread.
            Task { @MainActor in
                self.isAgentTyping = false
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
        aiAgent.reset()
        messages.removeAll()
    }
    
    /// Marks all messages, which were nor fact checked as checked
    func factCheckMessages() {
        repository.factCheckMessages()
        fetchMessages()
    }
    
    func onEndConversation() async {
        await aiAgent.endConversation(messages)
        factCheckMessages()
    }
    
    func refreshLastConversation() {
        aiAgent.refreshLastConversation(messages)
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
