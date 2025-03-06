//
//  MessageRepositoryProtocol.swift
//  Serenica
//
//  Created by Checkito12 on 01.03.25.
//
import Foundation
import CoreData

protocol MessageRepositoryProtocol {
    func fetchMessages(forUser userId: UUID) -> [Message]
    func addMessage(_ message: Message, forUser userId: UUID)
    func deleteMessage(withId id: UUID)
    func clearAllMessages(forUser userId: UUID)
}
