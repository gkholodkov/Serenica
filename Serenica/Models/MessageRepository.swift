//
//  MessageRepositoryProtocol.swift
//  Serenica
//
//  Created by Checkito12 on 01.03.25.
//


import Foundation
import CoreData

class MessageRepository: MessageRepositoryProtocol {
    private var context: NSManagedObjectContext
    private var authService: AuthService
    
    init(context: NSManagedObjectContext? = nil) {
        self.context = context ?? CoreDataManager.shared.container.viewContext
        self.authService = AuthService(context: self.context)
    }
    
    func fetchMessages(forUser userId: UUID) -> [Message] {
        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.timestamp, ascending: true)]
        request.predicate = NSPredicate(format: "user.id == %@", userId as CVarArg)
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                Message(
                    id: entity.id ?? UUID(),
                    content: entity.content ?? "",
                    isFromUser: entity.isFromUser,
                    timestamp: entity.timestamp ?? Date()
                )
            }
        } catch {
            print("Error fetching messages: \(error.localizedDescription)")
            return []
        }
    }
    
    func addMessage(_ message: Message, forUser userId: UUID) {
        let entity = MessageEntity(context: context)
        entity.id = message.id
        entity.content = message.content
        entity.isFromUser = message.isFromUser
        entity.timestamp = message.timestamp
        
        // Associate with UserEntity
        let userRequest = NSFetchRequest<UserEntity>(entityName: "UserEntity")
        userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
        
        if let userEntity = (try? context.fetch(userRequest))?.first {
            entity.user = userEntity
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving message: \(error.localizedDescription)")
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
            }
        } catch {
            print("Error deleting message: \(error.localizedDescription)")
        }
    }
    
    func clearAllMessages(forUser userId: UUID) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "MessageEntity")
        fetchRequest.predicate = NSPredicate(format: "user.id == %@", userId as CVarArg)
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Error clearing messages: \(error.localizedDescription)")
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
