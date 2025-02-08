//
//  Event.swift
//  Serenica
//
//  Created by Checkito12 on 18.01.25.
//


import Foundation
import CoreData

struct Event: Identifiable, Equatable {
    let id: UUID
    var title: String
    var startDate: Date?
    var endDate: Date?
    var notes: String
    var userId: UUID
    var isCompleted: Bool
    var notificationId: UUID?
    var notificationInterval: Double?
    
    init(id: UUID = UUID(), title: String, startDate: Date? = nil, endDate: Date? = nil, notes: String = "", userId: UUID, isCompleted: Bool = false, notificationId: UUID? = nil, notificationInterval: Double? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.userId = userId
        self.isCompleted = isCompleted
        self.notificationId = notificationId
        self.notificationInterval = notificationInterval
    }
} 
