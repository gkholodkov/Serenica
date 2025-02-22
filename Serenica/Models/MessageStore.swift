import CoreData
import SwiftUI

class MessageStore: ObservableObject {
    @Published private(set) var messages: [Message] = []
    private let context: NSManagedObjectContext
    private let deepSeekService = DeepSeekService()
    private var authService: AuthService
    
    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? CoreDataManager.shared.container.viewContext
        self.authService = AuthService(context: self.context)
        fetchMessages()
    }
    
    func updateAuthService(_ newAuthService: AuthService) {
        self.authService = newAuthService
        fetchMessages()
    }
    
    func sendMessage(_ text: String) async throws {
        // First, save the user's message
        let userMessage = Message(content: text, isFromUser: true)
        await MainActor.run {
            addMessage(userMessage)
        }
        
        // Get AI response using the existing conversation history
        let response = try await deepSeekService.sendMessage(
            text,
            previousMessages: messages.dropLast() // Drop the last message since we just added it
        )
        
        // Save the AI's response
        let aiMessage = Message(content: response, isFromUser: false)
        await MainActor.run {
            addMessage(aiMessage)
        }
    }
    
    private func addMessage(_ message: Message) {
        let entity = MessageEntity(context: context)
        entity.id = message.id
        entity.content = message.content
        entity.isFromUser = message.isFromUser
        entity.timestamp = message.timestamp
        
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
            fetchMessages()
        } catch {
            print("Error saving message: \(error.localizedDescription)")
        }
    }
    
    func fetchMessages() {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.timestamp, ascending: true)]
        
        // Add user filter using the injected authService
        if let userId = authService.currentUser?.id {
            request.predicate = NSPredicate(format: "user.id == %@", userId as CVarArg)
        }
        
        do {
            let entities = try context.fetch(request)
            messages = entities.map { entity in
                Message(
                    id: entity.id ?? UUID(),
                    content: entity.content ?? "",
                    isFromUser: entity.isFromUser,
                    timestamp: entity.timestamp ?? Date()
                )
            }
        } catch {
            print("Error fetching messages: \(error.localizedDescription)")
        }
    }
    
    func deleteMessage(withId id: UUID) {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                context.delete(entity)
                try context.save()
                fetchMessages()
            }
        } catch {
            print("Error deleting message: \(error.localizedDescription)")
        }
    }
    
    func clearAllMessages() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "MessageEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            messages.removeAll()
        } catch {
            print("Error clearing messages: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func sendMessageAndGetResponse(_ userMessage: Message) async {
        // Add user message
        addMessage(userMessage)
        
        do {
            // Get AI response
            let response = try await deepSeekService.sendMessage(
                userMessage.content,
                previousMessages: messages
            )
            
            // Add bot response
            let botMessage = Message(content: response, isFromUser: false)
            addMessage(botMessage)
        } catch {
            // Handle error with a friendly message
            let errorMessage = Message(
                content: "I apologize, but I'm having trouble responding right now. Please try again.",
                isFromUser: false
            )
            addMessage(errorMessage)
        }
    }
    
    #if DEBUG
    /// Preview helper method to add messages
    func previewAddMessage(_ message: Message) {
        addMessage(message)
    }
    #endif
} 
