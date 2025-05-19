import Foundation
import CoreData

class MessageRepository: MessageRepositoryProtocol {
    private var context: NSManagedObjectContext
    private var authService: AuthService

    init(context: NSManagedObjectContext? = nil, authService: AuthService? = nil) {
        self.context = context ?? CoreDataManager.shared.container.viewContext
        self.authService = authService ?? AuthService(context: self.context)
    }
    
    func fetchMessages() -> [Message] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        var fetchedMessages: [Message] = []
        
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.timestamp, ascending: true)]
        request.predicate = NSPredicate(format: "user.id == %@", userId as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            fetchedMessages = entities.map { entity in
                Message(
                    id: entity.id ?? UUID(),
                    content: entity.content ?? "",
                    isFromUser: entity.isFromUser,
                    timestamp: entity.timestamp ?? Date(),
                    isFactChecked: entity.isFactChecked
                )
            }
        } catch {
            print("Error fetching messages: \(error.localizedDescription)")
            fetchedMessages = []
        }
        
        return fetchedMessages
    }
    
    func addMessage(_ message: Message) {
        guard let userId = authService.currentUser?.id else { return }
        
        let entity = MessageEntity(context: self.context)
        entity.id = message.id
        entity.content = message.content
        entity.isFromUser = message.isFromUser
        entity.timestamp = message.timestamp
        entity.isFactChecked = message.isFactChecked
        
        // Associate with UserEntity based on current user.
        let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        if let userEntity = (try? self.context.fetch(userRequest))?.first {
            entity.user = userEntity
        }
        
        do {
            try self.context.save()
        } catch {
            print("Error saving message: \(error.localizedDescription)")
        }
    }
    
    func addAgentMessage(_ message: Message) {
        guard let userId = authService.currentUser?.id else { return }
        
        context.perform {
            let entity = MessageEntity(context: self.context)
            entity.id = message.id
            entity.content = message.content
            entity.isFromUser = message.isFromUser
            entity.timestamp = message.timestamp
            entity.isFactChecked = message.isFactChecked
            
            // Associate with UserEntity based on current user.
            let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            if let userEntity = (try? self.context.fetch(userRequest))?.first {
                entity.user = userEntity
            }
            
            do {
                try self.context.save()
            } catch {
                print("Error saving message: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteMessage(withId id: UUID) {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
        do {
            if let entity = try self.context.fetch(request).first {
                self.context.delete(entity)
                try self.context.save()
            }
        } catch {
            print("Error deleting message: \(error.localizedDescription)")
        }
    }
    
    func clearAllMessages() {
        guard let userId = authService.currentUser?.id else { return }

        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.predicate = NSPredicate(format: "user.id == %@", userId as CVarArg)
        request.includesPropertyValues = false
        request.returnsObjectsAsFaults = true

        do {
            let messages = try self.context.fetch(request)
            for msg in messages {
                self.context.delete(msg)
            }

            try self.context.save()
        } catch {
            print("Error clearing messages:", error)
        }
    }
    
    func factCheckMessages() {
        guard let userId = authService.currentUser?.id else { return }

        context.perform {
            let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
            request.predicate = NSPredicate(format: "user.id == %@ AND isFactChecked == false", userId as CVarArg)
                
            do {
                let entities = try self.context.fetch(request)
                for entity in entities {
                    entity.isFactChecked = true
                }
                try self.context.save()
            } catch {
                print("Error fact-checking messages: \(error.localizedDescription)")
            }
        }
    }

    
    // Optionally update AuthService and context if needed:
    func updateAuthService(_ newAuthService: AuthService) {
        self.authService = newAuthService
    }
    
    func updateContext(_ newContext: NSManagedObjectContext) {
        self.context = newContext
    }
}
