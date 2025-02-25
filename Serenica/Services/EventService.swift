//
//  EventStore.swift
//  Serenica
//
//  A high-level facade that orchestrates event-related operations.
//  It is built on top of EventRepository, EventRecurrenceManager,
//  OverdueManager, and EventNotificationService.
//  Note: This class is now named “EventStore” to match your UI’s expectations.
//

import Foundation
import CoreData
import SwiftUI

class EventService: ObservableObject {
    private let repository: EventRepository
    private let recurrenceManager: EventRecurrenceManager
    private let notificationService: EventNotificationService
    private let overdueManager: OverdueManager
    private(set) var context: NSManagedObjectContext
    
    // Published arrays that the UI uses
    @Published var events: [Event] = []
    @Published var recurringEvents: [Event] = []
    @Published var completedEvents: [Event] = []
    @Published var undatedEvents: [Event] = []
    
    private var overdueTimer: Timer?
    private var notificationRefreshTimer: Timer?
    
    // MARK: - Initializers
    
    /// Designated initializer.
    init(context: NSManagedObjectContext,
         repository: EventRepository = EventRepository(context: CoreDataManager.shared.viewContext),
         recurrenceManager: EventRecurrenceManager = EventRecurrenceManager(),
         notificationService: EventNotificationService = EventNotificationService(),
         overdueManager: OverdueManager = OverdueManager()) {
        self.context = context
        // Important: We pass the same context into the repository.
        self.repository = EventRepository(context: context)
        self.recurrenceManager = recurrenceManager
        self.notificationService = notificationService
        self.overdueManager = overdueManager
        fetchEvents()
        startOverdueTimer()
        startNotificationRefreshTimer()
    }
    
    /// Convenience initializer using the default shared context.
    convenience init() {
        self.init(context: CoreDataManager.shared.viewContext)
    }
    
    // MARK: - Dependency Updates
    
    /// Call this if the view’s context changes.
    func updateContext(_ newContext: NSManagedObjectContext) {
        self.context = newContext
        repository.updateContext(newContext)
        fetchEvents()
    }
    
    /// Call this to update the auth service (for example, when the user signs in or out).
    func updateAuthService(_ newAuthService: AuthService) {
        repository.updateAuthService(newAuthService)
        fetchEvents()
    }
    
    // MARK: - Overdue Updates
    
    /// Updates overdue events (both recurring and non-recurring) and refreshes published arrays.
    func updateOverdueAndRefreshDates() {
        do {
            try overdueManager.updateAllOverdueEvents(context: context, recurrenceManager: recurrenceManager)
            fetchEvents()
        } catch {
            print("Error updating overdue events: \(error.localizedDescription)")
        }
    }
    
    private func startOverdueTimer() {
        overdueTimer?.invalidate()
        overdueTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateOverdueAndRefreshDates()
        }
    }
    
    // MARK: - Notification Refresh Logic
    
    /// Refreshes notifications for all events (non-recurring and recurring) scheduled for today.
    func refreshNotificationsForToday() {
        let today = Date()
        let calendar = Calendar.current
        
        // Remove notifications for events not scheduled for today
        for event in events + recurringEvents {
            if let notificationId = event.notificationId,
                let startDate = event.startDate,
                !calendar.isDate(startDate, inSameDayAs: today) {
                notificationService.removeNotification(for: notificationId)
            }
        }
        
        // Refresh notifications for non-recurring events
        let eventsForToday = events.filter { event in
            guard let startDate = event.startDate else { return false }
            return calendar.isDate(startDate, inSameDayAs: today)
        }
        
        // Refresh notifications for recurring events using your recurringEvents(on:) helper.
        let recurringForToday = recurringEvents.filter { event in
            // Exclude the target day if it is in the event's excluded dates.
            if event.recurrenceExcludedDates?.contains(where: { calendar.isDate($0, inSameDayAs: today) }) == true {
                return false
            }
            
            if let endDate = event.recurrenceEndDate, today >= endDate {
                return false
            }

            guard let eventStart = event.startDate else { return false }
            let startDay = calendar.startOfDay(for: eventStart)
            
            switch event.recurrenceType {
            case .daily:
                let daysDiff = calendar.dateComponents([.day], from: startDay, to: today).day ?? -1
                return daysDiff >= 0 && daysDiff % event.recurrenceInterval == 0
                
            case .workingDays:
                if calendar.isDateInWeekend(today) { return false }
                return today >= startDay
                
            case .weekly:
                let weekdayStart = calendar.component(.weekday, from: eventStart)
                let weekdayTarget = calendar.component(.weekday, from: today)
                if weekdayStart != weekdayTarget { return false }
                let weeksDiff = calendar.dateComponents([.weekOfYear], from: startDay, to: today).weekOfYear ?? -1
                return weeksDiff >= 0 && weeksDiff % event.recurrenceInterval == 0
                
            case .monthly:
                let monthsDiff = calendar.dateComponents([.month], from: startDay, to: today).month ?? -1
                if monthsDiff < 0 || monthsDiff % event.recurrenceInterval != 0 { return false }
                if let candidate = calendar.date(byAdding: .month, value: monthsDiff, to: eventStart) {
                    return calendar.isDate(candidate, inSameDayAs: today)
                }
                return false
                
            case .yearly:
                let yearsDiff = calendar.dateComponents([.year], from: startDay, to: today).year ?? -1
                if yearsDiff < 0 || yearsDiff % event.recurrenceInterval != 0 { return false }
                if let candidate = calendar.date(byAdding: .year, value: yearsDiff, to: eventStart) {
                    return calendar.isDate(candidate, inSameDayAs: today)
                }
                return false
                
            case .none:
                return false
            }
        }
        
        for event in eventsForToday {
            if let _ = event.notificationId {
                notificationService.scheduleNotification(for: event, on: today)
            }
        }
        
        for event in recurringForToday {
            if let _ = event.notificationId {
                notificationService.scheduleNotification(for: event, on: today)
            }
        }
    }
    
    /// Starts a timer that refreshes notifications every 12 hours.
    private func startNotificationRefreshTimer() {
        notificationRefreshTimer?.invalidate()
        // 12 hours = 43200 seconds
        notificationRefreshTimer = Timer.scheduledTimer(withTimeInterval: 43200, repeats: true) { [weak self] _ in
            self?.refreshNotificationsForToday()
        }
    }
    
    // MARK: - Business Operations
    
    func addEvent(_ event: Event) {
        do {
            try repository.addEvent(event)
            fetchEvents()
            refreshNotificationsForToday()
        } catch {
            print("Error adding event: \(error.localizedDescription)")
        }
    }
    
    func updateEvent(_ event: Event, initialNotificationId: UUID? = nil) {
        do {
            var updatedEvent = event
            updatedEvent.isOverdue = event.isOverdue && !event.isCompleted && event.endDate ?? Date() < Date()
            try repository.updateEvent(updatedEvent)
            fetchEvents()
            if let notificationId = initialNotificationId, event.notificationId == nil {
                notificationService.removeNotification(for: notificationId)
            }
            refreshNotificationsForToday()
        } catch {
            print("Error updating event: \(error.localizedDescription)")
        }
    }
    
    /// Updates a single occurrence of a recurring event.
    /// - Parameters:
    ///   - event: The recurring event to update.
    ///   - date: The date (start of day) representing the occurrence being edited.
    ///   - updatedOccurrence: An Event instance with the updated values from the occurrence editor.
    ///
    /// This method works by adding the target date to the recurring event’s excluded dates,
    /// updating that series in the store, and then creating a new standalone (non‑recurring)
    /// event for the edited occurrence.
    func updateSingleOccurrence(of event: Event, on date: Date, with updatedOccurrence: Event) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        
        // Prepare the updated standalone occurrence event.
        // This occurrence will not be recurring.
        var occurrenceEvent = updatedOccurrence
        occurrenceEvent.id = UUID() // assign a new unique id
        occurrenceEvent.notificationId = updatedOccurrence.notificationId != nil ? UUID() : nil
        occurrenceEvent.recurrenceType = .none
        occurrenceEvent.recurrenceInterval = 0
        occurrenceEvent.recurrenceEndDate = nil
        occurrenceEvent.recurrenceExcludedDates = []
        occurrenceEvent.isOverdue = updatedOccurrence.isOverdue && !updatedOccurrence.isCompleted && updatedOccurrence.endDate ?? Date() < Date()
        // CASE 1: The target date is the first occurrence.
        if let eventStart = event.startDate, calendar.isDate(eventStart, inSameDayAs: targetDay) {
            // Add the updated occurrence as a standalone event.
            addEvent(occurrenceEvent)
            // Advance the recurring event to the next occurrence.
            advanceRecurringEvent(event)
            return
        }
                
        // CASE 2: No further recurrences exist after targetDay (i.e. last occurrence).
        else if nextOccurrence(for: event, after: targetDay) == nil {
            // Add the updated occurrence as a standalone event.
            addEvent(occurrenceEvent)
            
            // Update the recurring event's recurrenceEndDate to the target day.
            var updatedRecurring = event
            updatedRecurring.recurrenceEndDate = targetDay
            
            // Remove any excluded dates that occur after the target day.
            if let excluded = updatedRecurring.recurrenceExcludedDates {
                updatedRecurring.recurrenceExcludedDates = excluded.filter {
                    calendar.compare($0, to: targetDay, toGranularity: .day) != .orderedDescending
                }
            }
            updateEvent(updatedRecurring)
            return
        }
        
        // CASE 3: Intermediate occurrence.
        else {
            // Add the updated occurrence as a standalone event.
            addEvent(occurrenceEvent)
            
            // Append the target date to the recurring event's excluded dates if not already present.
            var updatedRecurring = event
            var excludedDates = updatedRecurring.recurrenceExcludedDates ?? []
            if !excludedDates.contains(where: { calendar.isDate($0, inSameDayAs: targetDay) }) {
                excludedDates.append(targetDay)
            }
            updatedRecurring.recurrenceExcludedDates = excludedDates
            updateEvent(updatedRecurring)
            return
        }
    }
    
    func updateAllFutureOccurrences(of event: Event, on date: Date, with updatedOccurrence: Event) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        if let eventStart = event.startDate, calendar.isDate(eventStart, inSameDayAs: targetDay) {
            // Simply advance the recurring event to the next occurrence.
            updateEvent(updatedOccurrence, initialNotificationId: event.notificationId)
            return
        }
        var occurrenceEvent = updatedOccurrence
        occurrenceEvent.id = UUID() // assign a new unique id
        addEvent(occurrenceEvent)
        
        var updatedEvent = event
        updatedEvent.recurrenceEndDate = targetDay
        if let excluded = updatedEvent.recurrenceExcludedDates {
            updatedEvent.recurrenceExcludedDates = excluded.filter {
                calendar.compare($0, to: targetDay, toGranularity: .day) != .orderedDescending
            }
        }
        updateEvent(updatedEvent)
        return
    }

    
    func deleteEvent(withId id: UUID, initialNotificationId: UUID? = nil) {
        do {
            try repository.deleteEvent(withId: id)
            fetchEvents()
            if let notificationId = initialNotificationId {
                notificationService.removeNotification(for: notificationId)
            }
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
        }
    }

    /// Deletes a single occurrence of a recurring event on the provided date.
    /// This method only updates the recurring event’s schedule (without creating a completed copy).
    func deleteOccurrence(of event: Event, on date: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        // CASE 1: If the target date is the first occurrence.
        if let eventStart = event.startDate, calendar.isDate(eventStart, inSameDayAs: targetDay) {
            // Simply advance the recurring event to the next occurrence.
            print("Remove first occurrence.")
            advanceRecurringEvent(event)
            return
        }
        
        // CASE 2: If there are no further recurrences after the target date.
        else if nextOccurrence(for: event, after: targetDay) == nil {
            print("Remove last occurrence.")
            var updatedEvent = event
            updatedEvent.recurrenceEndDate = targetDay
            if let excluded = updatedEvent.recurrenceExcludedDates {
                updatedEvent.recurrenceExcludedDates = excluded.filter {
                    calendar.compare($0, to: targetDay, toGranularity: .day) != .orderedDescending
                }
            }
            updateEvent(updatedEvent)
            return
        }
        
        // CASE 3: Intermediate occurrence.
        print("Remove random occurrence.")
        var updatedEvent = event
        var excludedDates = updatedEvent.recurrenceExcludedDates ?? []
        if !excludedDates.contains(where: { calendar.isDate($0, inSameDayAs: targetDay) }) {
            excludedDates.append(targetDay)
        }
        updatedEvent.recurrenceExcludedDates = excludedDates
        updateEvent(updatedEvent)
    }
    
    func deleteAllFutureOccurences(of event: Event, on date: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        if let eventStart = event.startDate, calendar.isDate(eventStart, inSameDayAs: targetDay) {
            // Simply advance the recurring event to the next occurrence.
            deleteEvent(withId: event.id, initialNotificationId: event.notificationId)
            refreshNotificationsForToday()
            return
        }
        
        var updatedEvent = event
        updatedEvent.recurrenceEndDate = targetDay
        if let excluded = updatedEvent.recurrenceExcludedDates {
            updatedEvent.recurrenceExcludedDates = excluded.filter {
                calendar.compare($0, to: targetDay, toGranularity: .day) != .orderedDescending
            }
        }
        updateEvent(updatedEvent)
        return
    }
    
    private func complete(event: Event) {
        var updatedEvent = event
        updatedEvent.isCompleted = true
        updatedEvent.isOverdue = false
        updatedEvent.notificationId = nil
        updateEvent(updatedEvent, initialNotificationId: event.notificationId)
    }
    
    func toggleEventCompletion(_ event: Event, on date: Date) {
        if event.recurrenceType == .none {
            complete(event: event)
        } else {
            completeOccurrence(of: event, on: date)
        }
    }
    
    func completeOccurrence(of event: Event, on date: Date) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        // CASE 1: The target date is the same as the recurring event’s start date.
        if let eventStart = event.startDate, calendar.isDate(eventStart, inSameDayAs: targetDay) {
            createCompletedCopy(for: event, on: targetDay.merge(withTimeFrom: eventStart))
            // Advance the recurring event to its next occurrence.
            advanceRecurringEvent(event)
            return
        }
        
        // CASE 2: No recurrence exists after the target date.
        else if nextOccurrence(for: event, after: targetDay) == nil {
            createCompletedCopy(for: event, on: targetDay.merge(withTimeFrom: event.startDate != nil ? targetDay.merge(withTimeFrom: event.startDate!) : targetDay))
            var updatedEvent = event
            // Set the recurrence end date to the provided date.
            updatedEvent.recurrenceEndDate = targetDay
            // Remove any excluded dates that occur after the new recurrenceEndDate.
            if let excluded = updatedEvent.recurrenceExcludedDates {
                updatedEvent.recurrenceExcludedDates = excluded.filter {
                    calendar.compare($0, to: targetDay, toGranularity: .day) != .orderedDescending
                }
            }
            updateEvent(updatedEvent)
            return
        }
        
        // CASE 3: Intermediate occurrence.
        createCompletedCopy(for: event, on: event.startDate != nil ? targetDay.merge(withTimeFrom: event.startDate!) : targetDay)
        var updatedEvent = event
        // Append the target date to the excluded dates (if not already present).
        var excludedDates = updatedEvent.recurrenceExcludedDates ?? []
        if !excludedDates.contains(where: { calendar.isDate($0, inSameDayAs: targetDay) }) {
            excludedDates.append(targetDay)
        }
        updatedEvent.recurrenceExcludedDates = excludedDates
        updateEvent(updatedEvent)
    }
    
    // Helper: Create a completed non-recurring copy of the event for the given date.
    private func createCompletedCopy(for event: Event, on date: Date) {
        guard let eventStart = event.startDate, let eventEnd = event.endDate else { return }
        let duration = eventEnd.timeIntervalSince(eventStart)
        let completedEvent = Event(
            id: UUID(),  // new unique ID
            title: event.title,
            startDate: date,
            endDate: date.addingTimeInterval(duration),
            notes: event.notes,
            userId: event.userId,
            isCompleted: true,
            notificationId: nil,
            notificationInterval: 0,
            isOverdue: false,
            recurrenceType: .none,
            recurrenceInterval: 0,
            recurrenceEndDate: nil,
            recurrenceExcludedDates: []
        )
        self.addEvent(completedEvent)
    }
    
    private func advanceRecurringEvent(_ event: Event) {
        guard let nextOccurrence = nextOccurrence(for: event, after: event.startDate ?? Date()) else {
            // No next occurrence available; delete the event.
            deleteEvent(withId: event.id, initialNotificationId: event.notificationId)
            return
        }
        
        var updatedEvent = event
        // Filter out any excluded dates that occur before the new start date.
        if let excludedDates = updatedEvent.recurrenceExcludedDates {
            updatedEvent.recurrenceExcludedDates = excludedDates.filter { $0 >= nextOccurrence.startDate }
        }
        
        // Update the start and end dates to the new occurrence.
        updatedEvent.startDate = nextOccurrence.startDate
        updatedEvent.endDate = nextOccurrence.endDate
        
        // Call the standard update method that already handles the NSFetchRequest and persistence.
        updateEvent(updatedEvent)
    }

    
    // MARK: - Data Refresh
    
    func fetchEvents() {
        // Fetch non-recurring events.
        let nonRecurringEntities = repository.fetchNonRecurringEvents()
        events = nonRecurringEntities.map { entity in
            Event(
                id: entity.id ?? UUID(),
                title: entity.title ?? "",
                startDate: entity.startDate ?? Date(),
                endDate: entity.endDate ?? Date(),
                notes: entity.notes ?? "",
                userId: entity.user?.id ?? UUID(),
                isCompleted: entity.isCompleted,
                notificationId: entity.notificationId,
                notificationInterval: entity.notificationInterval,
                isOverdue: entity.isOverdue,
                recurrenceType: .none,
                recurrenceInterval: Int(entity.recurrenceInterval),
                recurrenceEndDate: entity.recurrenceEndDate,
                recurrenceExcludedDates: (entity.recurrenceExcludedDates as? [Date]) ?? []
            )
        }
        
        // Fetch recurring events.
        let recurringEntities = repository.fetchRecurringEvents()
        recurringEvents = recurringEntities.map { entity in
            Event(
                id: entity.id ?? UUID(),
                title: entity.title ?? "",
                startDate: entity.startDate ?? Date(),
                endDate: entity.endDate ?? Date(),
                notes: entity.notes ?? "",
                userId: entity.user?.id ?? UUID(),
                isCompleted: entity.isCompleted,
                notificationId: entity.notificationId,
                notificationInterval: entity.notificationInterval,
                isOverdue: entity.isOverdue,
                recurrenceType: RecurrenceType(rawValue: Int(entity.recurrenceType)) ?? .none,
                recurrenceInterval: Int(entity.recurrenceInterval),
                recurrenceEndDate: entity.recurrenceEndDate,
                recurrenceExcludedDates: (entity.recurrenceExcludedDates as? [Date]) ?? []
            )
        }
        
        // Fetch completed events.
        let completedEntities = repository.fetchCompletedEvents()
        completedEvents = completedEntities.map { entity in
            Event(
                id: entity.id ?? UUID(),
                title: entity.title ?? "",
                startDate: entity.startDate ?? Date(),
                endDate: entity.endDate ?? Date(),
                notes: entity.notes ?? "",
                userId: entity.user?.id ?? UUID(),
                isCompleted: entity.isCompleted,
                notificationId: entity.notificationId,
                notificationInterval: entity.notificationInterval,
                isOverdue: entity.isOverdue,
                recurrenceType: RecurrenceType(rawValue: Int(entity.recurrenceType)) ?? .none,
                recurrenceInterval: Int(entity.recurrenceInterval),
                recurrenceEndDate: entity.recurrenceEndDate,
                recurrenceExcludedDates: (entity.recurrenceExcludedDates as? [Date]) ?? []
            )
        }
        
        // Fetch undated events.
        let undatedEntities = repository.fetchUndatedEvents()
        undatedEvents = undatedEntities.map { entity in
            Event(
                id: entity.id ?? UUID(),
                title: entity.title ?? "",
                startDate: entity.startDate,
                endDate: entity.endDate,
                notes: entity.notes ?? "",
                userId: entity.user?.id ?? UUID(),
                isCompleted: entity.isCompleted,
                notificationId: entity.notificationId,
                notificationInterval: entity.notificationInterval,
                isOverdue: entity.isOverdue,
                recurrenceType: RecurrenceType(rawValue: Int(entity.recurrenceType)) ?? .none,
                recurrenceInterval: Int(entity.recurrenceInterval),
                recurrenceEndDate: entity.recurrenceEndDate,
                recurrenceExcludedDates: (entity.recurrenceExcludedDates as? [Date]) ?? []
            )
        }
    }
    
    
    // MARK: - Preview Helper
    #if DEBUG
    func previewAddEvent(_ event: Event) {
        do {
            try repository.addEvent(event)
            fetchEvents()
        } catch {
            print("Error in preview add event: \(error.localizedDescription)")
        }
    }
    #endif
}
