//
//  EventHandler.swift
//  Serenica
//
//  Created by Checkito12 on 18.01.25.
//


//
//  EventEntity+Helper.swift
//  Serenica
//
//  Created by Checkito12 on 18.01.25.
//

import Foundation
import CoreData

extension EventEntity {
    var unwrappedId: UUID {
        id ?? UUID()
    }
    
    var unwrappedTitle: String {
        title ?? ""
    }
    
    var unwrappedStartDate: Date {
        startDate ?? Date()
    }
    
    var unwrappedEndDate: Date {
        endDate ?? Date()
    }
    
    var unwrappedNotes: String? {
        notes
    }
    
    func update(with event: Event) {
        self.id = event.id
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.notes = event.notes
    }
    
    func toEvent() -> Event {
        Event(
            id: unwrappedId,
            title: unwrappedTitle,
            startDate: unwrappedStartDate,
            endDate: unwrappedEndDate,
            notes: unwrappedNotes ?? "",
            userId: user?.id ?? UUID()
        )
    }
} 
